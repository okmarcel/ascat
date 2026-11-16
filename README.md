# ASCat - Audio Sample Cataloging System

ASCat is an audio sample cataloging system backed by PostgreSQL.

## Prerequisites

- Docker with Docker Compose
- A PostgreSQL client such as `psql` or DBeaver (optional)

## Configuration

Create the local environment file from the provided example:

```sh
cp .env.example .env
```

The default configuration creates the `ascat` database and `ascat` user and
exposes PostgreSQL on `localhost:5432`. Change the values in `.env` if that port
or the development credentials conflict with your local setup.

## Starting the database

Start PostgreSQL in the background:

```sh
docker compose up -d
```

Check that the service is healthy:

```sh
docker compose ps
```

On the first start with an empty Docker volume, PostgreSQL automatically runs
`database/migrations/00_create_schema.sql` and creates the ASCat schema. Scripts
in `/docker-entrypoint-initdb.d` are not rerun when an existing database volume
is reused. The initial script defines tables, constraints and indexes.

## Sample data

Load the optional database fixtures after creating the schema:
[seed instructions](database/seeds/README.md).

## SQL examples and reports

[Basic operations, filters and three reports](database/queries/README.md)
include execution commands and expected results for the sample data.

## Recreating the development database

To recreate the database from the initialization scripts, stop the service and
remove its development volume, then start it again:

```sh
docker compose down -v
docker compose up -d
```

This deletes the local database stored in the Compose volume. Back up any data
you want to retain before running it.

## Backup and restore

Create a PostgreSQL custom-format backup in the current directory:

```sh
docker compose exec -T postgres \
  pg_dump -U ascat -d ascat -Fc \
  > ascat.dump
```

Restore that backup into an existing empty `ascat` database:

```sh
docker compose exec -T postgres \
  pg_restore -U ascat -d ascat --clean --if-exists \
  < ascat.dump
```

## Stopping the environment

Stop the containers while keeping the database volume:

```sh
docker compose down
```
