# App Supabase Sync

This document describes the first safe app-side Supabase integration for Mishne Torah.

## Goals

- Keep the app offline-first.
- Keep `seed_books.json` bundled in the app.
- Keep SwiftData as the UI data source.
- Use Supabase only as a read-only remote update source.
- Never ship the Supabase `service_role` key in the iOS/iPadOS/macOS app.

## Configuration

The app reads:

- `MTSupabaseProjectURL`
- `MTSupabasePublishableKey`

The Xcode project sets:

- `MTSupabaseProjectURL = https://inlmifnzboisiazbeuqk.supabase.co`
- `MTSupabasePublishableKey = $(SUPABASE_PUBLISHABLE_KEY)`

Recommended local setup:

1. Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig`.
2. Put the Supabase publishable key in `Config/Local.xcconfig`.
3. In Xcode, set the target configuration file to `Config/Local.xcconfig`, or define `SUPABASE_PUBLISHABLE_KEY` as a build setting.

`Config/Local.xcconfig` is ignored by git. Do not commit real keys.

If the publishable key is missing, the app simply skips remote sync and continues using local content.

## Data Flow

Startup remains local-first:

```text
seed_books.json -> SeedDataLoader -> SwiftData -> UI
                                      ^
                                      |
Supabase read-only sync -> ContentSyncService
```

The UI continues reading from SwiftData. Supabase is checked in the background after local seed/backfill work has finished.

## Components

- `SupabaseConfig`: central place for Project URL and publishable key.
- `SupabaseClientProvider`: creates the official Supabase Swift client.
- `RemoteContentService`: read-only PostgREST fetcher with pagination.
- `RemoteContentDTO`: DTOs matching Supabase content tables.
- `SyncStateStore`: stores `lastContentVersion`, `lastSuccessfulSyncAt`, and `schemaVersion` in `UserDefaults`.
- `LocalContentBackfill`: fills stable `contentID` values for old local rows without reseeding.
- `ContentSyncService`: compares versions, downloads changes, applies local upserts, and advances sync state after success.

## Stable Content IDs

The app uses the same deterministic IDs as the importer:

- `book:<book-order>`
- `section:<book-order>:<section-order>`
- `chapter:<m770Id>`
- `halakha:<m770Id>:<law-number>:<part-index>`

Internal UUIDs remain in SwiftData and are not used as remote sync keys.

## Initial Backfill

Older local rows may not have `contentID`. Before sync, `LocalContentBackfill` reads the bundled seed and fills IDs deterministically:

- books by `order`;
- sections by book order and section order;
- chapters by `m770Id`;
- halakhot by chapter `m770Id`, law number, source order, and `part_index`.

Backfill does not delete rows and does not recreate the database. If a row cannot be matched safely, the issue is logged and the row is left untouched.

## Delta Sync

`ContentSyncService.syncNow(context:)`:

1. Loads local sync state.
2. Reads remote `content_meta`.
3. If `remote content_version <= local content_version`, downloads nothing.
4. If the remote version is newer, fetches changed rows in order:
   - books;
   - sections;
   - chapters;
   - halakhot.
5. Applies local upserts by stable `contentID`.
6. Saves SwiftData.
7. Only then advances local `lastContentVersion`, `lastSuccessfulSyncAt`, and `schemaVersion`.

The importer is hash-aware, so unchanged remote rows keep their old `updated_at`. That makes `updated_at` a useful future delta cursor.

## Pagination

`RemoteContentService` uses PostgREST `Range` headers and keeps fetching pages until a page contains fewer rows than `pageSize`. This matters especially for `halakhot`, because the corpus currently has 15066 rows.

## Error Recovery

On any network, decoding, parent mapping, or persistence error:

- the error is logged in DEBUG;
- local sync state is not advanced;
- the app keeps showing the existing local SwiftData content;
- no critical user-facing error is shown for background sync.

The current app-side implementation is intentionally conservative. It avoids destructive migrations and does not physically delete content rows when a remote soft delete appears; it marks `deletedAt` locally so user-linked data such as bookmarks/history can remain intact.

## RLS And Keys

The client uses only:

- Project URL;
- publishable key.

The app does not use insert, update, delete, admin keys, or `service_role`.

Supabase RLS must continue to allow public SELECT only for published content and must deny client-side writes.

## Manual Xcode Step

After pulling this commit, set the publishable key in Xcode:

```text
SUPABASE_PUBLISHABLE_KEY = your_publishable_key
```

Use `Config/Local.xcconfig` or a user-local build setting. Do not put the real key into a committed Swift file.
