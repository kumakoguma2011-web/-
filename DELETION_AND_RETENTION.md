# Account deletion and retention policy (implementation baseline)

## Application data deleted by `DELETE /account/data`
- user account row
- profile row
- anonymization rules
- conversations
- messages
- chat idempotency records, including cached AI answers and profile suggestions

The schema uses `ON DELETE CASCADE` for child tables, including conversation-linked chat idempotency records, while the endpoint also explicitly deletes children in a transaction. The explicit deletes make the intended deletion order clear; the database cascade is a second line of defense against accidental or future parent-only deletes.

## What this endpoint does NOT prove
Deleting rows from the live PostgreSQL database does not by itself prove that copies are gone from:
- automated database backups / snapshots
- point-in-time recovery archives
- infrastructure logs
- observability systems
- third-party analytics or crash-reporting services
- email systems

Production deployment must define retention periods and deletion procedures for each of these systems. Do not claim "all data is instantly erased everywhere" unless those systems are technically covered.

## Recommended production retention policy
1. Keep application logs free of prompts, profiles, passwords, JWTs, and raw personal data.
2. Define a documented backup retention window.
3. For account deletion, mark the user as deleted before physical deletion if asynchronous backup cleanup is required.
4. Ensure deleted users are excluded from future backups where the platform supports it, and document when old immutable backups expire.
5. Provide a support procedure for regulated deletion requests that includes all downstream systems.
