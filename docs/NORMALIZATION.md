# Normalization

Scope: [data dictionary](DATA_DICTIONARY.md) and
[SQL schema](../database/migrations/00_create_schema.sql).

## Candidate keys and functional dependencies

A → B means one value of A determines one value of B. “Other attributes” means
all remaining columns of that table. Username, email and tag-name keys use the
case-insensitive lower() comparison enforced by unique indexes.

| Relation | Candidate keys | Nontrivial functional dependencies |
| --- | --- | --- |
| users | user_id; username; email | Each candidate key → all other attributes. |
| samples | sample_id; storage_key | Each candidate key → all other attributes. Names are not keys. |
| tags | tag_id; name | Each candidate key → all other attributes. |
| sample_tags | (sample_id, tag_id) | No non-key attributes; neither component determines the other. |
| collections | collection_id | collection_id → owner_id, name. Neither name nor (owner_id, name) is unique. |
| collection_samples | (collection_id, sample_id) | No non-key attributes; neither component determines the other. |
| ratings | rating_id; (user_id, sample_id) | Each candidate key → all other attributes. Neither user_id nor sample_id alone determines rating. |
| downloads | download_id | download_id → user_id, sample_id, downloaded_at. Repeated downloads, even at equal timestamps, are allowed. |
| login_events | login_event_id | login_event_id → user_id, logged_in_at. A timestamp is not an event identifier. |

Nullable downloads.sample_id is not part of a candidate key. It records loss
of the sample reference after deletion without changing event identity.

## Normal forms

- **1NF:** every column holds a single value; tags and collection contents
  are separate rows in join tables rather than lists inside samples.
- **2NF:** both join tables contain only their composite keys. In ratings,
  rating depends on the whole alternate key (user_id, sample_id). The other
  relations have single-column candidate keys, so there are no partial dependencies.
- **3NF:** sample rows do not repeat owner usernames/emails, tag names or
  collection names. Ratings and events reference users/samples by FK instead
  of copying their descriptive attributes. No non-key attribute determines
  another non-key attribute under the defined business rules.
- **BCNF:** every determinant in the dependency table is a candidate key.
  Join tables have no nontrivial dependencies with a non-key determinant.

The current relations satisfy 3NF and BCNF under these rules; no further
decomposition is needed. The N:M decompositions are sample_tags and
collection_samples, with FKs preventing orphaned memberships.

## Denormalization

None is used. Download counts, last-login dates and rating averages are computed
from source rows. Repeated download/login events are separate occurrences,
not duplicated descriptive data. No deleted sample names are copied into history.
