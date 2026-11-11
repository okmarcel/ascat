# Entity Relationship Diagram

[Data model](../DATA_MODEL.md). [DBML version](ERD.dbml) for dbdiagram.io.

```mermaid
erDiagram
    users ||--o{ samples : owns
    users ||--o{ collections : owns
    users ||--o{ ratings : has
    users ||--o{ downloads : has
    users ||--o{ login_events : has
    samples ||--o{ sample_tags : has
    tags ||--o{ sample_tags : has
    collections ||--o{ collection_samples : has
    samples ||--o{ collection_samples : has
    samples ||--o{ ratings : has
    samples |o--o{ downloads : has

    users {
        integer user_id PK
        varchar username UK
        varchar email UK
        text password_hash
        varchar role
        boolean is_active
    }

    samples {
        integer sample_id PK
        integer owner_id FK
        varchar name
        decimal length_seconds
        integer bpm "nullable"
        varchar file_format
        timestamptz upload_date
        text storage_key UK
        boolean is_deleted
    }

    tags {
        integer tag_id PK
        varchar name UK
    }

    sample_tags {
        integer sample_id PK,FK
        integer tag_id PK,FK
    }

    collections {
        integer collection_id PK
        integer owner_id FK
        varchar name
    }

    collection_samples {
        integer collection_id PK,FK
        integer sample_id PK,FK
    }

    ratings {
        integer rating_id PK
        integer user_id FK
        integer sample_id FK
        integer rating
    }

    downloads {
        integer download_id PK
        integer user_id FK
        integer sample_id FK "nullable"
        timestamptz downloaded_at
    }

    login_events {
        integer login_event_id PK
        integer user_id FK
        timestamptz logged_in_at
    }
```

Join tables have composite primary keys. Ratings has UNIQUE (user_id, sample_id).
Only samples.bpm and downloads.sample_id are nullable; downloads.sample_id
becomes NULL after permanent sample deletion.
