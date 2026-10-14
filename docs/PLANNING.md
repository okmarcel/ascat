# Planning

Draft doc for planning.

## Description

ASCaS (Audio Sample Cataloging System) stores audio samples
in a structured database that lets users upload samples and
search through the catalog efficiently.

## MVP Feature Scope

Database:
- Structured audio sample database
- Sample metadata:
  - name
  - length
  - tempo (BPM)
  - file format
- Sample tags
- SQL schema, entities and relations

Service:
- Backend API, CRUD
- Uploading/Downloading samples
- Searching and filtering samples
- Accounts and permissions (user/admin)

## Extended MVP

- Searching similar samples
- Sample reccomendation system
- Sample ratings
- Download history for each user
- Full Text Search

QOL audio algorithms:
- automatic tempo detection
- automatic key detection
- loudness/RMS analysis

## Requirements - cases

User can:
- register/login to service
- upload/download samples
- filter samples by name, tempo, tags
