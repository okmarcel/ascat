-- Views, functions, triggers and role grants.
-- Run after 00_create_schema.sql
BEGIN;

------------------------------------------------------------------------
-- VIEWS
------------------------------------------------------------------------

-- V1. Active catalog with owner info.
CREATE OR REPLACE VIEW v_active_catalog AS
SELECT s.sample_id, s.name, s.length_seconds, s.bpm, s.file_format,
       s.upload_date, s.storage_key, u.user_id AS owner_id, u.username AS owner
FROM samples s
JOIN users u ON u.user_id = s.owner_id
WHERE NOT s.is_deleted;

-- V2. Sample popularity report (R1).
CREATE OR REPLACE VIEW v_sample_popularity AS
WITH download_totals AS (
    SELECT sample_id, COUNT(*) AS download_count
    FROM downloads
    WHERE sample_id IS NOT NULL
    GROUP BY sample_id
), rating_totals AS (
    SELECT sample_id, COUNT(*) AS rating_count, AVG(rating) AS average_rating
    FROM ratings
    GROUP BY sample_id
)
SELECT s.sample_id, s.name AS sample_name, u.username AS owner,
       COALESCE(d.download_count, 0) AS download_count,
       ROUND(r.average_rating, 2) AS average_rating,
       COALESCE(r.rating_count, 0) AS rating_count
FROM samples s
JOIN users u ON u.user_id = s.owner_id
LEFT JOIN download_totals d ON d.sample_id = s.sample_id
LEFT JOIN rating_totals r ON r.sample_id = s.sample_id
WHERE NOT s.is_deleted
ORDER BY download_count DESC, average_rating DESC NULLS LAST,
         s.name, u.username, s.sample_id;

-- V3. User activity report (R2).
CREATE OR REPLACE VIEW v_user_activity AS
WITH upload_totals AS (
    SELECT owner_id AS user_id, COUNT(*) AS upload_count
    FROM samples GROUP BY owner_id
), download_totals AS (
    SELECT user_id, COUNT(*) AS download_count
    FROM downloads GROUP BY user_id
), rating_totals AS (
    SELECT user_id, COUNT(*) AS rating_count
    FROM ratings GROUP BY user_id
), login_totals AS (
    SELECT user_id, COUNT(*) AS login_count, MAX(logged_in_at) AS last_login_at
    FROM login_events GROUP BY user_id
)
SELECT u.user_id, u.username, u.is_active,
       COALESCE(s.upload_count, 0) AS upload_count,
       COALESCE(d.download_count, 0) AS download_count,
       COALESCE(r.rating_count, 0) AS rating_count,
       COALESCE(l.login_count, 0) AS login_count,
       l.last_login_at
FROM users u
LEFT JOIN upload_totals s ON s.user_id = u.user_id
LEFT JOIN download_totals d ON d.user_id = u.user_id
LEFT JOIN rating_totals r ON r.user_id = u.user_id
LEFT JOIN login_totals l ON l.user_id = u.user_id
ORDER BY u.username, u.user_id;

-- V4. Tag usage report (R3).
CREATE OR REPLACE VIEW v_tag_usage AS
SELECT t.tag_id, t.name AS tag_name, COUNT(s.sample_id) AS active_sample_count
FROM tags t
LEFT JOIN sample_tags st ON st.tag_id = t.tag_id
LEFT JOIN samples s ON s.sample_id = st.sample_id AND NOT s.is_deleted
GROUP BY t.tag_id, t.name
ORDER BY active_sample_count DESC, t.name, t.tag_id;

-- V5. Admin-only: soft-deleted samples with audit info (R4 - Admin View).
CREATE OR REPLACE VIEW v_admin_deleted_samples AS
SELECT s.sample_id,
       s.name,
       s.length_seconds,
       s.bpm,
       s.file_format,
       s.upload_date,
       s.storage_key,
       u.user_id AS owner_id,
       u.username AS owner,
       (SELECT COUNT(*) FROM downloads d WHERE d.sample_id = s.sample_id) AS download_count,
       (SELECT COUNT(*) FROM ratings r WHERE r.sample_id = s.sample_id) AS rating_count
FROM samples s
JOIN users u ON u.user_id = s.owner_id
WHERE s.is_deleted;

-- V6. Admin-only: detailed user account audit.
CREATE OR REPLACE VIEW v_admin_users_overview AS
SELECT u.user_id,
       u.username,
       u.email,
       u.role,
       u.is_active,
       COUNT(DISTINCT s.sample_id) AS total_samples_count,
       COUNT(DISTINCT CASE WHEN s.is_deleted THEN s.sample_id END) AS deleted_samples_count,
       MAX(le.logged_in_at) AS last_login_at
FROM users u
LEFT JOIN samples s ON s.owner_id = u.user_id
LEFT JOIN login_events le ON le.user_id = u.user_id
GROUP BY u.user_id, u.username, u.email, u.role, u.is_active
ORDER BY u.user_id;

------------------------------------------------------------------------
-- FUNCTIONS
------------------------------------------------------------------------

-- F1. Restore a soft-deleted sample. Only callable by an admin user.
CREATE OR REPLACE FUNCTION restore_sample(p_sample_id integer, p_admin_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verify calling user is an active admin.
    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE user_id = p_admin_id AND role = 'admin' AND is_active
    ) THEN
        RAISE EXCEPTION 'User % is not an active administrator', p_admin_id;
    END IF;

    -- Verify sample exists and is soft-deleted.
    IF NOT EXISTS (
        SELECT 1 FROM samples
        WHERE sample_id = p_sample_id AND is_deleted
    ) THEN
        RAISE EXCEPTION 'Sample % is not deleted or does not exist', p_sample_id;
    END IF;

    UPDATE samples SET is_deleted = false
    WHERE sample_id = p_sample_id AND is_deleted;
END;
$$;

-- F2. Soft-delete a sample. Checks ownership or admin role.
CREATE OR REPLACE FUNCTION soft_delete_sample(p_sample_id integer, p_user_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id integer;
    v_role     varchar;
BEGIN
    SELECT owner_id INTO v_owner_id
    FROM samples WHERE sample_id = p_sample_id AND NOT is_deleted;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Sample % not found or already deleted', p_sample_id;
    END IF;

    SELECT role INTO v_role FROM users
    WHERE user_id = p_user_id AND is_active;

    IF v_role IS NULL THEN
        RAISE EXCEPTION 'User % is not active', p_user_id;
    END IF;

    IF v_owner_id <> p_user_id AND v_role <> 'admin' THEN
        RAISE EXCEPTION 'User % is not the owner and not an admin', p_user_id;
    END IF;

    UPDATE samples SET is_deleted = true WHERE sample_id = p_sample_id;
END;
$$;

------------------------------------------------------------------------
-- TRIGGERS
------------------------------------------------------------------------

-- T1. Block ratings on soft-deleted samples.
CREATE OR REPLACE FUNCTION trg_block_deleted_sample_rating()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM samples
        WHERE sample_id = NEW.sample_id AND is_deleted
    ) THEN
        RAISE EXCEPTION 'Cannot rate sample %: sample is deleted', NEW.sample_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS block_deleted_sample_rating ON ratings;
CREATE TRIGGER block_deleted_sample_rating
    BEFORE INSERT OR UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION trg_block_deleted_sample_rating();

-- T2. Block downloads of soft-deleted samples.
CREATE OR REPLACE FUNCTION trg_block_deleted_sample_download()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.sample_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM samples
        WHERE sample_id = NEW.sample_id AND is_deleted
    ) THEN
        RAISE EXCEPTION 'Cannot download sample %: sample is deleted', NEW.sample_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS block_deleted_sample_download ON downloads;
CREATE TRIGGER block_deleted_sample_download
    BEFORE INSERT ON downloads
    FOR EACH ROW EXECUTE FUNCTION trg_block_deleted_sample_download();

------------------------------------------------------------------------
-- ROLES AND GRANTS
------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ascat_admin') THEN
        CREATE ROLE ascat_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ascat_user') THEN
        CREATE ROLE ascat_user NOLOGIN;
    END IF;
END;
$$;

-- Grant roles to the development database owner from .env
GRANT ascat_admin, ascat_user TO ascat;

-- Administrator role privileges: full audit, soft-deleted catalog, administrative routines
GRANT SELECT ON
    v_active_catalog, v_sample_popularity, v_tag_usage,
    v_user_activity, v_admin_deleted_samples, v_admin_users_overview
TO ascat_admin;

GRANT EXECUTE ON FUNCTION restore_sample(integer, integer) TO ascat_admin;
GRANT EXECUTE ON FUNCTION soft_delete_sample(integer, integer) TO ascat_admin;

-- Standard user role privileges: limited to public catalog and anonymous statistics
-- No access to: v_user_activity, v_admin_deleted_samples, v_admin_users_overview or underlying tables
GRANT SELECT ON
    v_active_catalog, v_sample_popularity, v_tag_usage
TO ascat_user;

COMMIT;
