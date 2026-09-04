# Supabase Import Guide

This guide explains how to create the Supabase content tables and import the bundled Mishne Torah `seed_books.json` into them.

This step does not connect Supabase to the iOS/macOS app. The app continues to use its bundled seed and local SwiftData store.

## Files

- Migration: `supabase/migrations/001_content_schema.sql`
- Import tool: `Tools/import_seed_to_supabase.py`
- Verification SQL: `supabase/verification.sql`
- Seed data: `Sources/MishnehTorahApp/Resources/seed_books.json`

## Stable Content IDs

The import tool generates deterministic ids:

| Entity | Format | Example |
| --- | --- | --- |
| Book | `book:<book-order>` | `book:1` |
| Section | `section:<book-order>:<section-order>` | `section:1:1` |
| Chapter | `chapter:<m770Id>` | `chapter:13` |
| Halakhah/law | `halakha:<m770Id>:<law-number>:<part-index>` | `halakha:13:1:0` |

`part_index` starts at `0`. Most laws have `part_index = 0`. If the same `law_number` appears more than once in the same chapter, the second row becomes `part_index = 1`, and so on.

This makes every minimal text block stable and unique without relying on random UUIDs.

## Apply The Migration

Option A: Supabase Dashboard

1. Open your Supabase project.
2. Go to SQL Editor.
3. Open `supabase/migrations/001_content_schema.sql`.
4. Copy the SQL into the editor.
5. Run it.

Option B: Supabase CLI

If the Supabase CLI is installed and linked to your project:

```bash
supabase db push
```

or run the migration file manually according to your CLI setup.

## Get Supabase URL And Service Role Key

In Supabase Dashboard:

1. Open Project Settings.
2. Open API.
3. Copy the Project URL. This becomes `SUPABASE_URL`.
4. Copy the `service_role` key. This becomes `SUPABASE_SERVICE_ROLE_KEY`.

Important:

- Never put the `service_role` key into the iOS/macOS app.
- Never commit the key to GitHub.
- Use it only in your local terminal, CI secret storage, or a secure admin backend.

## Set Environment Variables Safely

In Terminal:

```bash
export SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
```

These variables exist only in the current terminal session.

## Run Dry Run

Dry run does not contact Supabase and does not need credentials:

```bash
cd /Users/natanyakovson/Documents/Codex/2026-08-20/referenced-chatgpt-conversation-this-is-an/outputs/MishnehTorahPrototype
python3 Tools/import_seed_to_supabase.py --dry-run
```

Expected result:

- 14 books
- 84 sections
- 1004 chapters
- 15066 halakhot
- 9 duplicate law-number cases
- 16168 unique content ids across all content tables
- 0 content id collisions

## Run Real Import

Only run real import after the migration has been applied and environment variables are set:

```bash
cd /Users/natanyakovson/Documents/Codex/2026-08-20/referenced-chatgpt-conversation-this-is-an/outputs/MishnehTorahPrototype
python3 Tools/import_seed_to_supabase.py --content-version 1
```

The import is idempotent. It uses upsert by `content_id`, so running it again should update existing rows instead of creating duplicates.

The importer updates `content_meta.content_version` only after all books, sections, chapters, and halakhot have been upserted successfully. If an error occurs before that point, the script exits without falsely advancing the content version.

## Verify Import

After import, run `supabase/verification.sql` in Supabase SQL Editor.

The checks confirm:

- exactly 14 active books;
- exactly 84 active sections;
- exactly 1004 active chapters;
- exactly 15066 active halakhot;
- no duplicate `content_id`;
- no orphan foreign keys;
- unique `m770_id`;
- `part_index` starts at 0 and has no gaps inside each chapter/law group;
- `content_meta` singleton exists.

## RLS Summary

The migration enables RLS for:

- `content_meta`
- `books`
- `sections`
- `chapters`
- `halakhot`

Public clients can only `SELECT` published rows where `deleted_at is null`.

No public `INSERT`, `UPDATE`, or `DELETE` policies are created. Editing must be done with the Supabase service role from Dashboard, local import scripts, secure CI, or a future admin backend.

## If Something Fails

If dry run fails, fix the seed/import logic before touching Supabase.

If real import fails:

1. Read the terminal error.
2. Do not manually bump `content_meta.content_version`.
3. Fix the issue.
4. Re-run the importer. Existing rows will be upserted by stable `content_id`.

If verification fails, do not connect the app to Supabase yet. The remote content store should be considered unpublished until verification is clean.
