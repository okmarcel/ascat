-- R2. Current uploads/ratings and retained activity, including inactive accounts.
-- Uploads include soft-deleted samples; downloads include NULL sample references.
-- Nina: every count=0, last_login_at=NULL, login_history={}.
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
    SELECT user_id, COUNT(*) AS login_count, MAX(logged_in_at) AS last_login_at,
           ARRAY_AGG(logged_in_at ORDER BY logged_in_at DESC, login_event_id DESC) AS login_history
    FROM login_events GROUP BY user_id
)
SELECT u.user_id, u.username, u.is_active,
       COALESCE(s.upload_count, 0) AS upload_count,
       COALESCE(d.download_count, 0) AS download_count,
       COALESCE(r.rating_count, 0) AS rating_count,
       COALESCE(l.login_count, 0) AS login_count,
       l.last_login_at,
       COALESCE(l.login_history, ARRAY[]::timestamptz[]) AS login_history
FROM users u
LEFT JOIN upload_totals s ON s.user_id = u.user_id
LEFT JOIN download_totals d ON d.user_id = u.user_id
LEFT JOIN rating_totals r ON r.user_id = u.user_id
LEFT JOIN login_totals l ON l.user_id = u.user_id
ORDER BY u.username, u.user_id;
