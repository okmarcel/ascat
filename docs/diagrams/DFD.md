# Data Flow Diagrams

[Data model](../DATA_MODEL.md). Administrators also have regular user access.

## Context

```mermaid
flowchart LR
    UI[User] -->|Credentials, audio, metadata<br/>Search and collection requests| P((ASCat))
    AI[Administrator] -->|Credentials, report criteria<br/>Management requests| P
    P -->|Catalog, files, results<br/>Own history and statistics| UO[User]
    P -->|Reports, accounts<br/>Deleted samples and results| AO[Administrator]
```

## Processes and data stores

Each process is shown separately. Repeated actor and store nodes refer to the
same user, administrator, PostgreSQL database (D1) or audio storage (D2).
Processes validate account status, permissions and ownership before accessing data.

### 1. Accounts and access

```mermaid
flowchart LR
    UI[User / Administrator] -->|Credentials| P((1. Accounts<br/>and access))
    DBR[(D1. PostgreSQL)] -->|Password hash<br/>Role and account status| P
    P -->|Authentication result<br/>Session| UO[User / Administrator]
    P -->|Account and password hash<br/>Login event| DBW[(D1. PostgreSQL)]
```

### 2. Catalog and files

```mermaid
flowchart LR
    UI[User] -->|Session, audio, metadata<br/>Search, download, soft delete| P((2. Catalog<br/>and files))
    DBR[(D1. PostgreSQL)] -->|Account, metadata<br/>Tags and storage key| P
    FSR[(D2. Audio files)] -->|Audio<br/>File availability| P
    P -->|Catalog, audio<br/>Operation result| UO[User]
    P -->|Metadata and links<br/>Deletion state, download event| DBW[(D1. PostgreSQL)]
    P -->|Uploaded audio| FSW[(D2. Audio files)]
```

### 3. Tags, collections and ratings

```mermaid
flowchart LR
    UI[User] -->|Session, tags<br/>Collection changes, rating| P((3. Tags, collections<br/>and ratings))
    DBR[(D1. PostgreSQL)] -->|Account, sample state<br/>Tags, collections, ratings| P
    P -->|Collections<br/>Operation result| UO[User]
    P -->|Tags, collections<br/>Memberships and ratings| DBW[(D1. PostgreSQL)]
```

### 4. History and reports

```mermaid
flowchart LR
    UI[User] -->|Session<br/>Own history or statistics request| P((4. History<br/>and reports))
    AI[Administrator] -->|Session<br/>Report criteria| P
    DBR[(D1. PostgreSQL)] -->|Account, samples, links<br/>Ratings and events| P
    P -->|Own history<br/>Statistics| UO[User]
    P -->|Sample popularity<br/>User activity, tag usage| AO[Administrator]
```

### 5. Administration

```mermaid
flowchart LR
    AI[Administrator] -->|Session, account or tag changes<br/>Restore or permanent delete| P((5. Administration))
    DBR[(D1. PostgreSQL)] -->|Account, role<br/>Object state and storage key| P
    FSR[(D2. Audio files)] -->|File availability<br/>Deletion result| P
    P -->|Accounts, deleted samples<br/>Operation result| AO[Administrator]
    P -->|Account and tag changes<br/>Sample state, deleted records| DBW[(D1. PostgreSQL)]
    P -->|File deletion request| FSW[(D2. Audio files)]
```

D1 contains the ERD tables, D2 stores files referenced by samples.storage_key.
