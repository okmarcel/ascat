-- R1. Popularity of active samples. Aggregate children before joining.
-- Warehouse Loop: download_count=2, average_rating=3.67, rating_count=3.
-- Include samples without downloads/ratings; do not merge repeated sample names.
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
