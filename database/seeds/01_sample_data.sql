-- Database-only demo fixtures; audio files are not included.
-- Requires the schema from 00_create_schema.sql and empty application tables.
BEGIN;
SET LOCAL TIME ZONE 'UTC';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM users)
       OR EXISTS (SELECT 1 FROM samples)
       OR EXISTS (SELECT 1 FROM tags)
       OR EXISTS (SELECT 1 FROM sample_tags)
       OR EXISTS (SELECT 1 FROM collections)
       OR EXISTS (SELECT 1 FROM collection_samples)
       OR EXISTS (SELECT 1 FROM ratings)
       OR EXISTS (SELECT 1 FROM downloads)
       OR EXISTS (SELECT 1 FROM login_events) THEN
        RAISE EXCEPTION 'Sample data requires empty ASCat tables; existing data will not be overwritten.';
    END IF;
END;
$$;

-- Hashes use random, discarded passwords; these are not demo login credentials.
-- All users start active so events precede the final account deactivation.
INSERT INTO users (username, email, password_hash, role)
VALUES
    ('admin_demo', 'admin@example.test', '$argon2id$v=19$m=65536,t=3,p=1$NGEyNDJmYzgyOGY5OTkzYjA2NzEwNDZjY2NjMmNhZDg$JWRsRo6dwoBp3rSGcIDNy4tBNRSl6mUuOB0Keu3EZI4', 'admin'),
    ('mira', 'mira@example.test', '$argon2id$v=19$m=65536,t=3,p=1$YjMxOTllOWIwMmE1ZTZkYjVhZjQ3OGM5M2JmYThkNjQ$GF75ITXiXhFd5viRysPIUgxVCvfHm7WWDgpXabX1HOg', 'user'),
    ('leon', 'leon@example.test', '$argon2id$v=19$m=65536,t=3,p=1$MDBkYWI2ZGYxYThlYjhlNDkyMmUxODYxOGExZTVlNGE$ckNhEGPjHCAeEpIyHhbLwL7zUW7k9jeWalRqBtrxNog', 'user'),
    ('nina', 'nina@example.test', '$argon2id$v=19$m=65536,t=3,p=1$NGM1OTgzNDgyYjM2NjNhNDY4YzFlZmJmOTI1NmU3Yjg$anWPSogWFWfkNV174pxzKk+3F1PDtcvzEyjfHZAxcy4', 'user'),
    ('archived_user', 'archived@example.test', '$argon2id$v=19$m=65536,t=3,p=1$NDM3MzZjODk1OTA5MmJkMmMxZjY2NjAwYzg4ZWY4MGY$BL0Wa0nJ3C8BOPjHsR74LNHqygTG7ZA42vTWTUYNAxw', 'user');

-- Repeated display names, every supported format, BPM limits and unknown BPM.
-- The last sample is removed below to demonstrate retained download history.
INSERT INTO samples (owner_id, name, length_seconds, bpm, file_format, upload_date, storage_key)
SELECT u.user_id, v.name, v.length_seconds, v.bpm, v.file_format,
       v.upload_date::timestamptz, v.storage_key
FROM (VALUES
    ('mira', 'Deep Kick',       0.412345, NULL::integer, 'wav',  '2026-11-01T09:00:00Z', 'fixtures/deep-kick-mira.wav'),
    ('leon', 'Deep Kick',       0.500000, NULL,          'flac', '2026-11-02T10:00:00Z', 'fixtures/deep-kick-leon.flac'),
    ('mira', 'Warehouse Loop',  7.680000, 125,           'wav',  '2026-11-03T11:00:00Z', 'fixtures/warehouse-loop.wav'),
    ('leon', 'Slow Texture',   19.200000, 50,            'mp3',  '2026-11-04T12:00:00Z', 'fixtures/slow-texture.mp3'),
    ('mira', 'Fast Percussion', 0.800000, 300,           'ogg',  '2026-11-05T13:00:00Z', 'fixtures/fast-percussion.ogg'),
    ('leon', 'Room Ambience',  12.500000, NULL,          'flac', '2026-11-06T14:00:00Z', 'fixtures/room-ambience.flac'),
    ('archived_user', 'Archived Bass', 4.000000, 120,    'wav',  '2026-11-03T15:00:00Z', 'fixtures/archived-bass.wav'),
    ('mira', 'Quiet Pad',       8.000000, 90,            'mp3',  '2026-11-10T08:00:00Z', 'fixtures/quiet-pad.mp3'),
    ('archived_user', 'Removed Demo', 2.000000, 100,     'wav',  '2026-11-04T08:00:00Z', 'fixtures/removed-demo.wav')
) AS v(username, name, length_seconds, bpm, file_format, upload_date, storage_key)
JOIN users u ON u.username = v.username;

INSERT INTO tags (name)
VALUES ('drums'), ('kick'), ('loop'), ('techno'), ('ambient'), ('bass'),
       ('archived-only'), ('unused');

INSERT INTO sample_tags (sample_id, tag_id)
SELECT s.sample_id, t.tag_id
FROM (VALUES
    ('fixtures/deep-kick-mira.wav', 'drums'),
    ('fixtures/deep-kick-mira.wav', 'kick'),
    ('fixtures/deep-kick-leon.flac', 'drums'),
    ('fixtures/deep-kick-leon.flac', 'kick'),
    ('fixtures/warehouse-loop.wav', 'drums'),
    ('fixtures/warehouse-loop.wav', 'loop'),
    ('fixtures/warehouse-loop.wav', 'techno'),
    ('fixtures/slow-texture.mp3', 'ambient'),
    ('fixtures/slow-texture.mp3', 'loop'),
    ('fixtures/fast-percussion.ogg', 'drums'),
    ('fixtures/fast-percussion.ogg', 'techno'),
    ('fixtures/archived-bass.wav', 'bass'),
    ('fixtures/archived-bass.wav', 'archived-only'),
    ('fixtures/quiet-pad.mp3', 'ambient')
) AS v(storage_key, tag_name)
JOIN samples s ON s.storage_key = v.storage_key
JOIN tags t ON t.name = v.tag_name;

INSERT INTO collections (owner_id, name)
SELECT u.user_id, v.name
FROM (VALUES
    ('mira', 'Live Set'), ('leon', 'Live Set'), ('mira', 'Sketches'),
    ('leon', 'Empty Collection'), ('archived_user', 'Old Project')
) AS v(username, name)
JOIN users u ON u.username = v.username;

-- Collections include samples from other owners; Warehouse Loop is in three.
INSERT INTO collection_samples (collection_id, sample_id)
SELECT c.collection_id, s.sample_id
FROM (VALUES
    ('mira', 'Live Set', 'fixtures/deep-kick-mira.wav'),
    ('mira', 'Live Set', 'fixtures/warehouse-loop.wav'),
    ('mira', 'Live Set', 'fixtures/archived-bass.wav'),
    ('leon', 'Live Set', 'fixtures/deep-kick-leon.flac'),
    ('leon', 'Live Set', 'fixtures/warehouse-loop.wav'),
    ('leon', 'Live Set', 'fixtures/slow-texture.mp3'),
    ('mira', 'Sketches', 'fixtures/warehouse-loop.wav'),
    ('mira', 'Sketches', 'fixtures/quiet-pad.mp3'),
    ('archived_user', 'Old Project', 'fixtures/archived-bass.wav')
) AS v(username, collection_name, storage_key)
JOIN users u ON u.username = v.username
JOIN collections c ON c.owner_id = u.user_id AND c.name = v.collection_name
JOIN samples s ON s.storage_key = v.storage_key;

-- Warehouse Loop has three ratings and two downloads: useful for report joins.
INSERT INTO ratings (user_id, sample_id, rating)
SELECT u.user_id, s.sample_id, v.rating
FROM (VALUES
    ('admin_demo', 'fixtures/warehouse-loop.wav', 5),
    ('leon', 'fixtures/warehouse-loop.wav', 4),
    ('archived_user', 'fixtures/warehouse-loop.wav', 2),
    ('mira', 'fixtures/deep-kick-leon.flac', 1),
    ('leon', 'fixtures/deep-kick-mira.wav', 5),
    ('admin_demo', 'fixtures/fast-percussion.ogg', 3),
    ('mira', 'fixtures/slow-texture.mp3', 2),
    ('admin_demo', 'fixtures/archived-bass.wav', 4)
) AS v(username, storage_key, rating)
JOIN users u ON u.username = v.username
JOIN samples s ON s.storage_key = v.storage_key;

INSERT INTO downloads (user_id, sample_id, downloaded_at)
SELECT u.user_id, s.sample_id, v.downloaded_at::timestamptz
FROM (VALUES
    ('leon', 'fixtures/warehouse-loop.wav', '2026-11-05T09:00:00Z'),
    ('leon', 'fixtures/warehouse-loop.wav', '2026-11-07T09:00:00Z'),
    ('admin_demo', 'fixtures/deep-kick-mira.wav', '2026-11-06T10:00:00Z'),
    ('mira', 'fixtures/deep-kick-leon.flac', '2026-11-06T11:00:00Z'),
    ('leon', 'fixtures/slow-texture.mp3', '2026-11-08T12:00:00Z'),
    ('archived_user', 'fixtures/archived-bass.wav', '2026-11-06T13:00:00Z'),
    ('mira', 'fixtures/archived-bass.wav', '2026-11-07T14:00:00Z'),
    ('mira', 'fixtures/removed-demo.wav', '2026-11-08T15:00:00Z'),
    ('leon', 'fixtures/removed-demo.wav', '2026-11-09T16:00:00Z')
) AS v(username, storage_key, downloaded_at)
JOIN users u ON u.username = v.username
JOIN samples s ON s.storage_key = v.storage_key;

INSERT INTO login_events (user_id, logged_in_at)
SELECT u.user_id, v.logged_in_at::timestamptz
FROM (VALUES
    ('admin_demo', '2026-11-06T09:00:00Z'),
    ('mira', '2026-11-01T08:00:00Z'),
    ('mira', '2026-11-06T10:30:00Z'),
    ('mira', '2026-11-10T07:00:00Z'),
    ('leon', '2026-11-02T09:00:00Z'),
    ('leon', '2026-11-07T08:00:00Z'),
    ('archived_user', '2026-11-03T14:00:00Z')
) AS v(username, logged_in_at)
JOIN users u ON u.username = v.username;

-- Apply lifecycle changes after memberships, ratings and activity were recorded.
UPDATE samples SET is_deleted = true
WHERE storage_key IN ('fixtures/archived-bass.wav', 'fixtures/removed-demo.wav');
DELETE FROM samples WHERE storage_key = 'fixtures/removed-demo.wav';
UPDATE users SET is_active = false WHERE username = 'archived_user';

COMMIT;
