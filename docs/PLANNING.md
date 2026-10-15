# Planning

Draft doc for planning.

## Description

ASCat (Audio Sample Cataloging) System stores audio samples in a
structured PostgreSQL database and provides a service for uploading,
organizing, searching, filtering and downloading audio samples.

## MVP Feature Scope

Database:
- Structured relational audio sample database
- PostgreSQL as primary DB system
- Sample metadata:
  - name
  - length
  - tempo (BPM)
  - file format
  - upload date
  - owner
- Sample tags
- Sample ratings
- Sample collections
- Users
- SQL schema with entities and relations
  (1:N and N:M relations)
- Primary keys
- Database constrains
- Indexes for commonly queried fields

Service:
- Backend API, CRUD operations
- Uploading/Downloading samples
- Searching samples
- Filtering samples by:
  - name
  - tempo
  - tags
  - owner
  - recently uploaded
- User registration and login
- User/Admin permissions
- User statistics:
  - amount of uploaded/downloaded samples
  - login history
- Soft deletion of samples
- Administration panel or admin-only API operations

User Interface:
- Web-based GUI
- Forms for inserting/editing DB data
- Views for browsing stored data

## Database Implementation

### Relational Model

Database should contain meaningful 1:N and N:M relations.

Planned relations:
- user -> samples (1:N)
- user -> downloads (1:N)
- user -> ratings (1:N)
- sample -> ratings (1:N)
- sample -> downloads (1:N)
- samples <-> tags (N:M)
- users <-> collections (N:M)
- samples <-> collections (N:M)

### Data Integrity and Validation

Data validation should be enforced in PostgreSQL independently of
backend validation.

Planned constrains include:
- sample name cannot be empty
- sample length must be greater than zero
- tempo (BPM) must be within valid range
- file format must belong to a supported set
- rating must be within valid range
- one user may rate a given sample only once

### Database Views

Database should expose reusable views for browsing and reporting

- active samples with owner and metadata
- number of uploaded samples per user
- sample count grouped by tempo range
- tag popularity
- most downloaded samples
- average rating per user
- user activity statistics

Views should use aggregation with different GROUP BY and HAVING
conditions.

Project should make use of aggregate functions such as:
- COUNT
- AVG
- MIN
- MAX

### Database Functions and Triggers

Database should contain custom functions and triggers handling
selected business rules.

Planned uses:
- handling sample soft deletion
- restoring soft-deleted samples
- registering sample downloads
- handling rating-related rules
- preventing invalid state transitions

### Reports

Application should provide at least following reports

1. Sample popularity report

Fields:
- sample name
- number of downloads
- average rating
- number of ratings

2. User activity report

Fields:
- user
- number of uploaded samples
- number of downloads
- number of ratings submitted
- login history/last login date

3. Tag usage report

Fields:
- tag
- number of assigned samples

Reports should be backed by tables or database views and should
make use of aggregate queries.

## Extended MVP

Extended MVP version of the project may include additional entities,
relations, database-side logic and service features. It is meant to be
planned after completing the whole MVP.

Possible additional features include:
- Searching similar samples
- Sample recommendation system
- Full Text Search
- QOL audio algorithms:
  - automatic tempo detection
  - automatic key detection
  - loudness/RMS analysis

## Use Cases

Registered user can:
- register and log in
- upload and download samples
- browse samples
- search samples by name
- filter samples by tempo, tags and recently uploaded
- edit metadata of their own samples
- remove samples from their own catalog
- rate samples
- create collections
- add and remove samples from their own collection

Removing a sample as regular user performs a soft delete.

Administrator can:
- browse all samples
- browse soft-deleted samples
- restore soft-deleted samples
- permanently delete samples
- manage user accounts
- access administrative reports

Only an administrator can permanently remove a sample from the database.
