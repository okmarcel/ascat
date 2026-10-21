# ASCat - Audio Sample Cataloging System

Audio sample cataloging system with web service.

## Setting up

Run docker compose in detached mode to start PostgreSQL container:
```
docker compose up -d
```

Testing migration script:
```
docker compose exec -T postgres \
  psql -U ascas -d ascas \
  < database/migrations/000_test_environment.sql
```
