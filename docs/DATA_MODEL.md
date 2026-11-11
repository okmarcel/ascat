# Data Model

Scope: [PLANNING.md](PLANNING.md). Diagrams: [ERD](diagrams/ERD.md),
[DFD](diagrams/DFD.md). Schema details: [data dictionary](DATA_DICTIONARY.md)
and [normalization](NORMALIZATION.md).

## Entities

All attributes are required unless marked nullable. PK = primary key,
FK = foreign key, UK = unique key. Join tables use composite primary keys.

| Entity | Attributes |
| --- | --- |
| users | user_id PK, username UK, email UK, password_hash, role, is_active |
| samples | sample_id PK, owner_id FK → users, name, length_seconds, bpm (nullable), file_format, upload_date, storage_key UK, is_deleted |
| tags | tag_id PK, name UK |
| sample_tags | sample_id PK/FK → samples, tag_id PK/FK → tags |
| collections | collection_id PK, owner_id FK → users, name |
| collection_samples | collection_id PK/FK → collections, sample_id PK/FK → samples |
| ratings (Should) | rating_id PK, user_id FK → users, sample_id FK → samples, rating; UNIQUE (user_id, sample_id) |
| downloads | download_id PK, user_id FK → users, sample_id FK → samples (nullable after permanent deletion), downloaded_at |
| login_events | login_event_id PK, user_id FK → users, logged_in_at |

Each sample and collection has one owner (1:N). Samples–tags and
samples–collections are N:M. Users, samples, tags and collections may have
no related records. Ratings store one current value per user and sample.

## Domains

BPM is an optional integer from 50 to 300. Ratings are whole stars from 1 to 5.
Formats are wav, mp3, flac and ogg (lowercase, without a dot). Sample names
may repeat. Usernames, emails and tag names are unique without regard to case.
Durations use numeric(12,6) seconds; event dates use timestamptz with defaults
of CURRENT_TIMESTAMP. Use UTC sessions and localize display times in the UI.

## Access and storage

- Authenticated users browse and download all active samples, edit and
  soft-delete their own samples, and manage their own private collections.
  Collections may contain samples uploaded by any user.
- Users create tags and assign/remove them on their own active samples.
  Administrators also rename and delete tags from the shared dictionary.
- Administrators browse deleted samples, restore or permanently delete them,
  manage account roles/status, and access all reports. Users access their own
  history and statistics. Ratings are managed by their author.
- Each account has one role: user or admin. Registration assigns user.
  Accounts are deactivated rather than deleted; the last active administrator
  cannot be deactivated or demoted.
- Authentication uses password_hash; plaintext passwords are not stored.
  The API checks account status, role, ownership and sample state on each request.
  A role column alone does not enforce authorization.
- Each sample references one audio file outside PostgreSQL through a unique,
  server-generated storage_key relative to the configured storage directory.
  File access goes through the API. Replacing existing audio is outside scope.

## Deletion and history

| Operation | Effect |
| --- | --- |
| Soft delete | Set is_deleted = true; retain the file, metadata, tags, collection memberships, ratings and download history. Exclude the sample from normal browsing, downloads, editing, rating and new memberships. |
| Restore | Administrator sets is_deleted = false after checking file availability. Retained relationships become visible again. |
| Permanent delete | Administrator deletes a soft-deleted sample and its file. Cascade sample_tags, collection_samples and ratings; set downloads.sample_id to NULL. Keep download user/date, tags and collections. |
| Delete collection/tag | Cascade its join records; retain samples. |
| Deactivate account | Block access; retain its samples, collections, ratings and history. Foreign keys to users use RESTRICT. |

Each accepted download request creates an event after authorization and file
availability checks; it does not confirm completion on the client. New events
require an active sample. Each successful login creates a login_events record;
failed attempts and registration are not login events.

## Transactions

Use transactions for sample creation/editing with tags or collection memberships,
collection/tag deletion, sample deletion/restoration, download/login registration,
and account role/status changes. Check permissions and state in the same
transaction as the write. Coordinate sample mutations with row locks and
serialize administrator changes to preserve the last active administrator.

File operations are outside database transactions: prepare the file before
committing an upload; delete it after committing permanent deletion. Failed
operations require cleanup of unreferenced files, excluding uploads in progress.

## Requirement coverage

Verification below describes planned checks.

| Requirement from PLANNING.md | Entities / columns | Operations | Verification |
| --- | --- | --- | --- |
| Reproducible PostgreSQL schema and data | All tables | Create schema, seed | Load into an empty database. |
| Users and authentication | users: username, email, password_hash, is_active | Register, log in | Reject duplicates, incorrect credentials and inactive accounts. |
| User/admin permissions | users.role; owner_id | Authorize requests | Reject another user's edits and user access to admin operations. |
| Upload, browse, edit, download | samples; downloads | File and metadata CRUD | Upload → find → edit → download; failed upload rolls back. |
| Required sample metadata | samples: name, length_seconds, bpm, file_format, upload_date, owner_id | Insert, update | Read metadata; validate boundaries and nullable BPM. |
| Name search | samples.name, is_deleted | Search | Match names; exclude deleted samples. |
| BPM, tag, owner and date filters | samples: bpm, owner_id, upload_date; sample_tags, tags | Filter | Combine criteria without duplicate samples. |
| Tags and collections | tags, collections, both join tables | Create, assign, remove | Verify empty objects, N:M links and collection ownership. |
| Soft deletion | samples.is_deleted, owner_id | Mark deleted | Preserve file and relationships; hide from active catalog. |
| Admin restoration/permanent deletion | samples; join tables; ratings; downloads.sample_id | Restore, delete | Restore retained links; verify cascades and retained download events. |
| Download history | downloads | Register, list | Repeated downloads create separate events; rejected requests create none. |
| Login history | login_events | Register, list | Record successful logins only. |
| User activity statistics | samples, downloads, ratings, login_events | Aggregate | Include users without activity; verify report definitions below. |
| Database integrity | PK, FK, UNIQUE, CHECK | Validate writes | Reject invalid references, duplicates and invalid values directly in SQL. |
| Meaningful 1:N and N:M relations | Ownership, events, join tables | Join | Verify multiple children and memberships in both directions. |
| Browsing/editing forms or views | samples, tags, collections | API/GUI CRUD | Demonstrate catalog and ownership-controlled editing. |
| Three reports | Report sources below | Aggregate | Include zero counts and avoid multiplied counts across joins. |
| Ratings and rating aggregates (Should) | ratings | Rate, update, aggregate | Enforce one rating per user/sample; verify averages. |
| Database views, functions and triggers | Existing entities | Reusable reports and business rules | Verify aggregates, valid operations and rejected invalid writes. |
| Admin panel/API (Should) | Existing entities | Administrative interface | Verify permissions and consistency with source data. |

## Reports

| Report | Sources and output |
| --- | --- |
| Sample popularity | Active samples: name, download count, average rating and rating count (Should). |
| User activity | users: username; existing upload count including soft-deleted samples; all download events including deleted samples; current rating count (Should); login history and MAX(logged_in_at). |
| Tag usage | tags: name; count of assigned active samples, including tags with zero usage. |

Aggregate each child table separately before joining. Missing counts are zero;
missing averages and last-login dates are NULL. Permanent deletion reduces
existing upload/rating counts, but preserves download/login history. Deleted
sample names are not retained. Rating fields are omitted if Should is deferred.
