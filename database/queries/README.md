# SQL examples and reports

Prerequisite: the current schema and [sample data](../seeds/README.md).
Run from the repository root with the default Compose database/user:

```sh
docker compose exec -T postgres \
  psql -X -v ON_ERROR_STOP=1 -U ascat -d ascat \
  < database/queries/basic_operations.sql

docker compose exec -T postgres \
  psql -X -v ON_ERROR_STOP=1 -U ascat -d ascat \
  < database/queries/01_sample_popularity.sql

docker compose exec -T postgres \
  psql -X -v ON_ERROR_STOP=1 -U ascat -d ascat \
  < database/queries/02_user_activity.sql

docker compose exec -T postgres \
  psql -X -v ON_ERROR_STOP=1 -U ascat -d ascat \
  < database/queries/03_tag_usage.sql
```

Adjust database/user names for a custom setup. Add psql's `-a` option to show
SQL comments and statements alongside their results. Reports are read-only;
dates are displayed in the session time zone (UTC in the Compose configuration).

## Basic operations

`basic_operations.sql` contains read examples B01–B12, followed by write
examples M01–M15. All table changes are rolled back at the end. Identity
sequences still advance: gaps are expected and do not change fixture contents.
Run the complete file with ON_ERROR_STOP; an error aborts the transaction.

The examples use known usernames, collection names and storage keys to locate
fixtures rather than hardcoded IDs. Collection names are not unique: application
requests must use collection IDs. Literal usernames and admin checks in this
script do not authenticate the caller or prevent a direct SQL user from bypassing
these checks. API authorization and business-rule functions/triggers are pending.
File operations are not performed; registration/restoration assumes the future
service has checked file availability. This script is a SQL demonstration,
not the automated constraint test suite.

| Example | Expected result on the seed |
| --- | --- |
| B01 Active catalog | 7 rows; Quiet Pad is newest; Archived Bass is excluded. |
| B02 Name contains deep | 2 Deep Kick rows with different IDs/owners. |
| B03 BPM 100–150 | Warehouse Loop only; unknown BPM is excluded. |
| B04 Any of drums/techno | 4 distinct samples. |
| B05 Both drums and techno | Warehouse Loop and Fast Percussion. |
| B06 Owner mira | 4 active samples. |
| B07 Upload date interval | Fast Percussion, Room Ambience and Quiet Pad. |
| B08 Combined filters | Warehouse Loop only. |
| B09 Mira's Live Set | Deep Kick and Warehouse Loop; deleted membership is hidden. |
| B10 Leon's downloads | 4 events, including 1 with a permanently deleted sample. |
| B11 Mira's logins | 3 events, newest first. |
| B12 GROUP BY / HAVING | Leon: 3 active samples; Mira: 4; shortest/longest durations included. |

The write sequence creates and edits a sample, creates/assigns/removes tags,
creates a collection and changes membership, adds/updates a rating and records
a download. Soft deletion hides the sample while retaining one tag, collection,
rating and download. Restoration makes it active again; a second soft delete
followed by permanent deletion cascades current relationships and preserves
the download with a NULL sample reference. Temporary tag/collection cleanup
and the final ROLLBACK complete the demonstration.

## Reports

### R1 — Sample popularity

`01_sample_popularity.sql` returns 7 active samples. Downloads and ratings are
aggregated separately, then joined, preventing multiplied counts.

- Warehouse Loop: 2 downloads, 3 ratings, average 3.67.
- Deep Kick owned by Mira: 1 download, 1 rating, average 5.00.
- Deep Kick owned by Leon: 1 download, 1 rating, average 1.00.
- Quiet Pad and Room Ambience: 0 downloads, 0 ratings, NULL average.
- Archived Bass is excluded. Repeated names are separate samples, not one group.

### R2 — User activity

`02_user_activity.sql` includes every account, even inactive accounts and those
without activity. Upload counts include soft-deleted samples, download counts
include permanently deleted samples, and rating counts describe current ratings.

| User | Uploads | Downloads | Ratings submitted | Logins | Last login (UTC) |
| --- | ---: | ---: | ---: | ---: | --- |
| admin_demo | 0 | 1 | 3 | 1 | 2026-11-06 09:00 |
| archived_user | 1 | 1 | 1 | 1 | 2026-11-03 14:00 |
| leon | 3 | 4 | 2 | 2 | 2026-11-07 08:00 |
| mira | 4 | 3 | 2 | 3 | 2026-11-10 07:00 |
| nina | 0 | 0 | 0 | 0 | NULL |

The report also returns the ordered login timestamp array; Nina's array is empty.

### R3 — Tag usage

`03_tag_usage.sql` counts active samples while keeping tags with zero usage.
The active-state condition belongs in the sample JOIN so zero-count tags remain.

| Tag | Active samples |
| --- | ---: |
| drums | 4 |
| ambient | 2 |
| kick | 2 |
| loop | 2 |
| techno | 2 |
| archived-only | 0 |
| bass | 0 |
| unused | 0 |

These queries provide the report definitions; reusable views and GRANT scripts
will be added in the next database stage.
