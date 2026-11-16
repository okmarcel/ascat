-- Run after 00_create_schema.sql and 01_sample_data.sql, using psql ON_ERROR_STOP.
-- SQL-only examples: literal usernames are fixture selectors, not authentication.
-- ROLLBACK preserves table contents, but identity sequences still advance.
BEGIN;
SET LOCAL TIME ZONE 'UTC';

-- B01. Active catalog with owners: 7 rows, newest first.
SELECT s.sample_id, s.name, s.length_seconds, s.bpm, s.file_format,
       s.upload_date, u.username AS owner
FROM samples s
JOIN users u ON u.user_id = s.owner_id
WHERE NOT s.is_deleted
ORDER BY s.upload_date DESC, s.sample_id;

-- B02. Case-insensitive substring search: both Deep Kick samples (2 rows).
SELECT s.sample_id, s.name, u.username AS owner
FROM samples s
JOIN users u ON u.user_id = s.owner_id
WHERE NOT s.is_deleted AND lower(s.name) LIKE '%deep%'
ORDER BY u.username, s.sample_id;

-- B03. BPM range: Warehouse Loop only. NULL BPM does not match a range.
SELECT sample_id, name, bpm
FROM samples
WHERE NOT is_deleted AND bpm BETWEEN 100 AND 150
ORDER BY sample_id;

-- B04. ANY selected tag: 4 samples, without duplicates.
SELECT s.sample_id, s.name
FROM samples s
WHERE NOT s.is_deleted AND EXISTS (
    SELECT 1 FROM sample_tags st
    JOIN tags t ON t.tag_id = st.tag_id
    WHERE st.sample_id = s.sample_id AND lower(t.name) IN ('drums', 'techno')
)
ORDER BY s.sample_id;

-- B05. ALL selected tags: Warehouse Loop and Fast Percussion.
SELECT s.sample_id, s.name
FROM samples s
WHERE NOT s.is_deleted AND s.sample_id IN (
    SELECT st.sample_id
    FROM sample_tags st JOIN tags t ON t.tag_id = st.tag_id
    WHERE lower(t.name) IN ('drums', 'techno')
    GROUP BY st.sample_id
    HAVING COUNT(DISTINCT lower(t.name)) = 2
)
ORDER BY s.sample_id;

-- B06. Owner filter: Mira's 4 active samples.
SELECT s.sample_id, s.name
FROM samples s JOIN users u ON u.user_id = s.owner_id
WHERE NOT s.is_deleted AND lower(u.username) = 'mira'
ORDER BY s.sample_id;

-- B07. Date filter, half-open UTC interval: 3 samples (Nov 5 through Nov 10).
SELECT sample_id, name, upload_date
FROM samples
WHERE NOT is_deleted
  AND upload_date >= TIMESTAMPTZ '2026-11-05T00:00:00Z'
  AND upload_date < TIMESTAMPTZ '2026-11-11T00:00:00Z'
ORDER BY upload_date, sample_id;

-- B08. Combined name/BPM/tag/owner/date filters: Warehouse Loop only.
SELECT s.sample_id, s.name, s.bpm
FROM samples s JOIN users u ON u.user_id = s.owner_id
WHERE NOT s.is_deleted
  AND lower(s.name) LIKE '%loop%'
  AND s.bpm BETWEEN 100 AND 150
  AND lower(u.username) = 'mira'
  AND s.upload_date >= TIMESTAMPTZ '2026-11-01T00:00:00Z'
  AND s.upload_date < TIMESTAMPTZ '2026-11-11T00:00:00Z'
  AND EXISTS (
      SELECT 1 FROM sample_tags st JOIN tags t ON t.tag_id = st.tag_id
      WHERE st.sample_id = s.sample_id AND lower(t.name) = 'techno'
  );

-- B09. Mira's Live Set: 2 visible samples; Archived Bass remains linked but hidden.
-- Collection names are fixture selectors here; application operations use IDs.
SELECT c.collection_id, c.name AS collection_name, s.sample_id, s.name AS sample_name
FROM collections c
JOIN users u ON u.user_id = c.owner_id
JOIN collection_samples cs ON cs.collection_id = c.collection_id
JOIN samples s ON s.sample_id = cs.sample_id AND NOT s.is_deleted
WHERE lower(u.username) = 'mira' AND u.is_active AND c.name = 'Live Set'
ORDER BY s.sample_id;

-- B10. Leon's download history: 4 events, including one permanently deleted sample.
SELECT d.download_id, s.sample_id,
       COALESCE(s.name, '[permanently deleted]') AS sample_name,
       d.downloaded_at
FROM downloads d
JOIN users u ON u.user_id = d.user_id
LEFT JOIN samples s ON s.sample_id = d.sample_id
WHERE lower(u.username) = 'leon' AND u.is_active
ORDER BY d.downloaded_at DESC, d.download_id DESC;

-- B11. Mira's successful login history: 3 events.
SELECT e.login_event_id, e.logged_in_at
FROM login_events e JOIN users u ON u.user_id = e.user_id
WHERE lower(u.username) = 'mira' AND u.is_active
ORDER BY e.logged_in_at DESC, e.login_event_id DESC;

-- B12. Aggregation with HAVING: Mira (4 active samples) and Leon (3).
SELECT u.username, COUNT(*) AS active_sample_count,
       MIN(s.length_seconds) AS shortest_seconds,
       MAX(s.length_seconds) AS longest_seconds
FROM users u JOIN samples s ON s.owner_id = u.user_id
WHERE NOT s.is_deleted
GROUP BY u.user_id, u.username
HAVING COUNT(*) >= 2
ORDER BY u.username;

-- M01. Create a sample owned by an active account: 1 row.
INSERT INTO samples (owner_id, name, length_seconds, bpm, file_format, upload_date, storage_key)
SELECT user_id, 'SQL Demo', 1.250000, 130, 'wav',
       TIMESTAMPTZ '2026-11-11T09:00:00Z', 'examples/sql-demo.wav'
FROM users WHERE lower(username) = 'mira' AND is_active
RETURNING sample_id, name;

-- M02. Edit the owner's active sample: 1 row.
UPDATE samples s SET name = 'SQL Demo Updated', bpm = 128
FROM users u
WHERE s.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING s.sample_id, s.name, s.bpm;

-- M03. Create a tag, then assign it and an existing tag: 1 tag, 2 assignments.
INSERT INTO tags (name) VALUES ('sql-demo') RETURNING tag_id, name;
INSERT INTO sample_tags (sample_id, tag_id)
SELECT s.sample_id, t.tag_id
FROM samples s JOIN users u ON u.user_id = s.owner_id
CROSS JOIN tags t
WHERE s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
  AND lower(u.username) = 'mira' AND u.is_active
  AND lower(t.name) IN ('sql-demo', 'drums')
RETURNING sample_id, tag_id;

-- M04. Remove one tag assignment: 1 row. The sql-demo assignment remains.
DELETE FROM sample_tags st
USING samples s, tags t, users u
WHERE st.sample_id = s.sample_id AND st.tag_id = t.tag_id
  AND s.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
  AND lower(t.name) = 'drums'
RETURNING st.sample_id, st.tag_id;

-- M05. Create the owner's collection: 1 row.
INSERT INTO collections (owner_id, name)
SELECT user_id, 'SQL Demo Collection'
FROM users WHERE lower(username) = 'mira' AND is_active
RETURNING collection_id, name;

-- M06. Add an active sample to the owner's collection: 1 row.
INSERT INTO collection_samples (collection_id, sample_id)
SELECT c.collection_id, s.sample_id
FROM collections c JOIN users u ON u.user_id = c.owner_id
CROSS JOIN samples s
WHERE lower(u.username) = 'mira' AND u.is_active AND c.name = 'SQL Demo Collection'
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING collection_id, sample_id;

-- M07. Remove membership, then add it again for the lifecycle example: 1 row each.
DELETE FROM collection_samples cs
USING collections c, users u, samples s
WHERE cs.collection_id = c.collection_id AND cs.sample_id = s.sample_id
  AND c.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND c.name = 'SQL Demo Collection' AND s.storage_key = 'examples/sql-demo.wav'
RETURNING cs.collection_id, cs.sample_id;
INSERT INTO collection_samples (collection_id, sample_id)
SELECT c.collection_id, s.sample_id
FROM collections c JOIN users u ON u.user_id = c.owner_id
CROSS JOIN samples s
WHERE lower(u.username) = 'mira' AND u.is_active AND c.name = 'SQL Demo Collection'
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING collection_id, sample_id;

-- M08. Add a rating and change the same rating: 1 row per statement.
INSERT INTO ratings (user_id, sample_id, rating)
SELECT u.user_id, s.sample_id, 5
FROM users u CROSS JOIN samples s
WHERE lower(u.username) = 'leon' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING rating_id, rating;
UPDATE ratings r SET rating = 4
FROM samples s, users u
WHERE r.sample_id = s.sample_id AND r.user_id = u.user_id
  AND lower(u.username) = 'leon' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING r.rating_id, r.rating;

-- M09. Register an accepted download after locking/checking the active sample.
-- The future API also checks file availability before registering the event.
INSERT INTO downloads (user_id, sample_id, downloaded_at)
SELECT u.user_id, s.sample_id, TIMESTAMPTZ '2026-11-11T10:00:00Z'
FROM users u CROSS JOIN samples s
WHERE lower(u.username) = 'leon' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
FOR UPDATE OF s
RETURNING download_id, sample_id;

-- M10. Soft-delete the owner's sample: 1 row; active lookup then returns 0 rows.
UPDATE samples s SET is_deleted = true
FROM users u
WHERE s.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING s.sample_id, s.is_deleted;
SELECT sample_id, name FROM samples
WHERE storage_key = 'examples/sql-demo.wav' AND NOT is_deleted;

-- M11. Administrator lookup: the deleted sample still has all remaining relations.
SELECT s.sample_id, s.is_deleted,
       (SELECT COUNT(*) FROM sample_tags st WHERE st.sample_id = s.sample_id) AS tags,
       (SELECT COUNT(*) FROM collection_samples cs WHERE cs.sample_id = s.sample_id) AS collections,
       (SELECT COUNT(*) FROM ratings r WHERE r.sample_id = s.sample_id) AS ratings,
       (SELECT COUNT(*) FROM downloads d WHERE d.sample_id = s.sample_id) AS downloads
FROM samples s
WHERE s.storage_key = 'examples/sql-demo.wav'
  AND EXISTS (SELECT 1 FROM users WHERE lower(username) = 'admin_demo' AND role = 'admin' AND is_active);
-- Expected: is_deleted=true; tags=1, collections=1, ratings=1, downloads=1.

-- M12. Administrator restore: 1 row. Future API also verifies file availability.
UPDATE samples SET is_deleted = false
WHERE storage_key = 'examples/sql-demo.wav' AND is_deleted
  AND EXISTS (SELECT 1 FROM users WHERE lower(username) = 'admin_demo' AND role = 'admin' AND is_active)
RETURNING sample_id, is_deleted;

-- M13. Delete again, then permanently remove as administrator: 1 row each.
UPDATE samples s SET is_deleted = true
FROM users u
WHERE s.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND s.storage_key = 'examples/sql-demo.wav' AND NOT s.is_deleted
RETURNING s.sample_id, s.is_deleted;
DELETE FROM samples
WHERE storage_key = 'examples/sql-demo.wav' AND is_deleted
  AND EXISTS (SELECT 1 FROM users WHERE lower(username) = 'admin_demo' AND role = 'admin' AND is_active)
RETURNING sample_id, name;

-- M14. The event remains with a NULL sample reference: 1 row.
SELECT d.download_id, d.sample_id, d.downloaded_at
FROM downloads d JOIN users u ON u.user_id = d.user_id
WHERE lower(u.username) = 'leon'
  AND d.downloaded_at = TIMESTAMPTZ '2026-11-11T10:00:00Z';

-- M15. Delete the temporary collection and tag: 1 row each.
DELETE FROM collections c USING users u
WHERE c.owner_id = u.user_id AND lower(u.username) = 'mira' AND u.is_active
  AND c.name = 'SQL Demo Collection'
RETURNING c.collection_id;
DELETE FROM tags
WHERE lower(name) = 'sql-demo'
  AND EXISTS (SELECT 1 FROM users WHERE lower(username) = 'admin_demo' AND role = 'admin' AND is_active)
RETURNING tag_id;

-- Undo every table change above, including the retained download event.
ROLLBACK;
