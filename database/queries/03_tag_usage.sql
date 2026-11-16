-- R3. Count active samples per tag, preserving tags with zero visible samples.
-- drums=4, ambient=2, kick=2, loop=2, techno=2; archived-only=bass=unused=0.
SELECT t.tag_id, t.name AS tag_name, COUNT(s.sample_id) AS active_sample_count
FROM tags t
LEFT JOIN sample_tags st ON st.tag_id = t.tag_id
LEFT JOIN samples s ON s.sample_id = st.sample_id AND NOT s.is_deleted
GROUP BY t.tag_id, t.name
ORDER BY active_sample_count DESC, t.name, t.tag_id;
