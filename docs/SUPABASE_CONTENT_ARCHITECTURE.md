# Supabase Content Architecture

This document describes the current Mishneh Torah content architecture and the planned path toward remote content storage in Supabase.

At this stage Supabase is not integrated into the app. The bundled `seed_books.json` remains the canonical offline bootstrap source, and the existing SwiftData loading flow must continue to work without network access.

## Current Local Architecture

The app currently stores library content and user data in SwiftData. The SwiftData container is created in `Sources/MishnehTorahApp/Persistence/PersistenceController.swift` using the persistent configuration name `MishnehTorahLocalStore`.

The current content models are defined in `Sources/MishnehTorahApp/Models/LibraryModels.swift`:

- `MTBook`
- `MTSection`
- `MTChapter`
- `MTHalakhah`

User-owned local data is stored separately:

- `MTBookmark`
- `MTReadingHistory`
- `MTTextHighlight`
- `MTReaderSettings`

### Current SwiftData Content Models

`MTBook`

| Field | Type | Required now | Meaning |
| --- | --- | --- | --- |
| `id` | `UUID` | yes | Local SwiftData unique id, generated during seed import. Not stable across reseeds. |
| `order` | `Int` | yes | Sort order from 1 to 14. |
| `titleHebrew` | `String` | yes | Hebrew book title. |
| `titleRussian` | `String` | yes | Russian book title. |
| `sections` | `[MTSection]` | yes | Child sections. |

`MTSection`

| Field | Type | Required now | Meaning |
| --- | --- | --- | --- |
| `id` | `UUID` | yes | Local SwiftData unique id, generated during seed import. Not stable across reseeds. |
| `order` | `Int` | yes | Sort order inside a book. |
| `titleHebrew` | `String` | yes | Hebrew section title. In the current seed this is empty for all sections. |
| `titleRussian` | `String` | yes | Russian section title. |
| `book` | `MTBook?` | yes in practice | Parent book. |
| `chapters` | `[MTChapter]` | yes | Child chapters. |

`MTChapter`

| Field | Type | Required now | Meaning |
| --- | --- | --- | --- |
| `id` | `UUID` | yes | Local SwiftData unique id, generated during seed import. Not stable across reseeds. |
| `number` | `Int` | yes | Chapter number inside the section. |
| `section` | `MTSection?` | yes in practice | Parent section. |
| `halakhot` | `[MTHalakhah]` | yes | Child halakhot/laws. |

`MTHalakhah`

| Field | Type | Required now | Meaning |
| --- | --- | --- | --- |
| `id` | `UUID` | yes | Local SwiftData unique id, generated during seed import. Not stable across reseeds. |
| `number` | `Int` | yes | Law number inside the chapter. |
| `hebrewText` | `String` | yes | Hebrew text. Some seed rows have an empty Hebrew text. |
| `russianText` | `String?` | yes | Russian text, currently present for every row. |
| `notesJSON` | `String?` | optional | JSON-encoded array of Russian notes. |
| `chapter` | `MTChapter?` | yes in practice | Parent chapter. |

## Current `seed_books.json` Structure

The bundled content file is `Sources/MishnehTorahApp/Resources/seed_books.json`.

Current measured size and counts:

| Entity | Count |
| --- | ---: |
| Books | 14 |
| Sections | 84 |
| Chapters | 1004 |
| Halakhot/laws | 15066 |
| JSON size | about 29.7 MB |

### JSON Shape

The top-level JSON value is an array of books:

```json
[
  {
    "order": 1,
    "titleHebrew": "ספר המדע",
    "titleRussian": "Книга Знания",
    "sourceTitle": "I. Знания",
    "sections": [
      {
        "order": 1,
        "titleHebrew": "",
        "titleRussian": "Фундаментальные законы Торы",
        "chapters": [
          {
            "number": 1,
            "m770Id": 13,
            "m770Url": "https://m770.org/rambam/13",
            "halakhot": [
              {
                "number": 1,
                "hebrewText": "...",
                "russianText": "..."
              }
            ]
          }
        ]
      }
    ]
  }
]
```

### Book Fields

| JSON field | Used by Swift now | Notes |
| --- | --- | --- |
| `order` | yes | Book order, 1 to 14. |
| `titleHebrew` | yes | Hebrew title. |
| `titleRussian` | yes | Russian title. |
| `sourceTitle` | no | Source/display title from importer. Should be preserved remotely as metadata. |
| `sections` | yes | Nested sections. |

### Section Fields

| JSON field | Used by Swift now | Notes |
| --- | --- | --- |
| `order` | yes | Section order inside book. |
| `titleHebrew` | yes | Present but currently empty for all 84 sections. |
| `titleRussian` | yes | Russian section name. |
| `chapters` | yes | Nested chapters. |

### Chapter Fields

| JSON field | Used by Swift now | Notes |
| --- | --- | --- |
| `number` | yes | Chapter number inside section. |
| `m770Id` | no | Present for all 1004 chapters and unique. Good external source id candidate. |
| `m770Url` | no | Present for all 1004 chapters. Good source URL metadata. |
| `halakhot` | yes | Nested laws. |

### Halakhah/Law Fields

| JSON field | Used by Swift now | Notes |
| --- | --- | --- |
| `number` | yes | Law number inside chapter. Not always unique within a chapter in the current seed. |
| `hebrewText` | yes | Hebrew text. Empty in 5 rows. |
| `russianText` | yes | Russian text. Present in all rows. |
| `notes` | yes | Optional array of notes. Present with content in 4 rows. Stored locally as `notesJSON`. |

### Current ID Situation

The JSON does not contain stable app-level ids for books, sections, chapters, or laws. SwiftData `UUID` values are generated locally each time content is inserted.

This is acceptable for a bundled prototype, but it is not safe for remote delta sync because bookmarks, reading history, and text highlights need a durable way to point to the same content after an update.

Important findings:

- Book path `book.order` is unique.
- Section path `(book.order, section.order)` is unique.
- Chapter path `(book.order, section.order, chapter.number)` is unique.
- `m770Id` is present and unique for all chapters.
- Law path `(book.order, section.order, chapter.number, law.number)` is not fully unique: 15066 law rows produce 15057 unique path ids.
- There are 9 duplicate law-number paths in the current seed:
  - `b2.s7.c2.h9` - Книга Любовь / Порядок молитвы
  - `b3.s4.c7.h3` - Книга Времена / Законы праздников
  - `b4.s2.c12.h9` - Книга Женщины / Законы развода
  - `b6.s1.c9.h1` - Книга Изречения / Законы о клятвах
  - `b8.s1.c2.h8` - Книга Служение / Законы о Храме
  - `b8.s8.c1.h1` - Книга Служение / Законы храмовой службы в День Искупления
  - `b10.s4.c13.h8` - Книга Чистота / Законы осквернения лож и сидений
  - `b13.s4.c16.h10` - Книга Законы / Законы исков (об истце и ответчике)
  - `b13.s5.c9.h11` - Книга Законы / Законы о наследовании

For Supabase, every law row must therefore receive a stable `content_id` that includes a disambiguator when duplicate law numbers exist. Recommended format:

```text
mt.b{book_order}.s{section_order}.c{chapter_number}.h{law_number}
mt.b{book_order}.s{section_order}.c{chapter_number}.h{law_number}.p{part_index}
```

For normal rows `part_index` is omitted or stored as `1`. For duplicate law-number rows, store `part_index` as `1`, `2`, etc. This keeps the canonical order stable and allows every minimal text block to be downloaded independently.

## Current Data Flow

The current startup content path is:

```text
seed_books.json
  -> SeedBook / SeedSection / SeedChapter / SeedHalakhah decoding
  -> MTBook / MTSection / MTChapter / MTHalakhah SwiftData models
  -> ModelContainer("MishnehTorahLocalStore")
  -> SwiftUI views using @Query and relationships
```

Detailed flow:

1. `RootView` creates the SwiftData environment through `PersistenceController.shared.container`.
2. On first task execution, `SeedDataLoader.seedIfNeeded(context:)` runs.
3. `SeedDataLoader` counts existing `MTBook` and `MTHalakhah` rows.
4. If there are exactly 14 books and 15066 laws, it keeps the existing local database and only ensures settings exist.
5. Otherwise, `replaceLibraryData(context:)` deletes bookmarks, reading history, and books. Book deletion cascades into sections, chapters, and laws.
6. `SeedBook.all` reads `seed_books.json` from the app bundle and decodes it with `JSONDecoder`.
7. The loader creates SwiftData objects:
   - `SeedBook` -> `MTBook`
   - `SeedSection` -> `MTSection`
   - `SeedChapter` -> `MTChapter`
   - `SeedHalakhah` -> `MTHalakhah`
8. Relationships are manually connected by assigning parent references and appending children.
9. Data is saved periodically every 500 inserted laws and finally at the end.
10. UI reads local SwiftData only:
   - library screens query `MTBook`
   - chapter reader uses `chapter.sortedHalakhot`
   - search fetches `MTHalakhah`
   - bookmarks/history/highlights refer to local `MTHalakhah`

`TextImportService.importBooks(from:context:)` uses the same seed decoding structs and insertion pattern, but currently it only inserts new content from a JSON payload and does not replace existing content or preserve stable ids.

## Recommended Supabase/PostgreSQL Schema

Design goals:

- Keep the app offline-first.
- Give every content row a stable `content_id`.
- Allow delta sync by `updated_at` or by content version.
- Support future soft deletion without damaging the user's last good local copy.
- Keep user data local unless a future account sync feature is explicitly designed.

### Extensions

```sql
create extension if not exists pgcrypto;
```

### Table: `content_versions`

Stores published corpus versions. The app can check this table first before fetching changed rows.

| Field | PostgreSQL type | Key | Notes |
| --- | --- | --- | --- |
| `id` | `bigint generated always as identity` | primary key | Internal version row id. |
| `version` | `integer` | unique not null | Monotonic global content version. |
| `status` | `text` | not null | `draft`, `published`, `archived`. |
| `label` | `text` | nullable | Human label, for example `2026-09 initial import`. |
| `source_name` | `text` | nullable | Example: `m770.org`. |
| `source_url` | `text` | nullable | Source root URL. |
| `notes` | `text` | nullable | Admin notes about this content release. |
| `published_at` | `timestamptz` | nullable | Set when status becomes `published`. |
| `created_at` | `timestamptz` | not null default `now()` | Row creation time. |
| `updated_at` | `timestamptz` | not null default `now()` | Row update time. |

Recommended constraints:

```sql
alter table content_versions
add constraint content_versions_status_check
check (status in ('draft', 'published', 'archived'));
```

### Table: `books`

| Field | PostgreSQL type | Key | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | primary key default `gen_random_uuid()` | Database id. |
| `content_id` | `text` | unique not null | Stable external id, e.g. `mt.b1`. |
| `order_index` | `integer` | not null | Book order. |
| `title_hebrew` | `text` | not null | Hebrew title. |
| `title_russian` | `text` | not null | Russian title. |
| `source_title` | `text` | nullable | Current JSON `sourceTitle`. |
| `content_version` | `integer` | not null references `content_versions(version)` | Version when this row was last published. |
| `is_published` | `boolean` | not null default `true` | Public read filter. |
| `is_deleted` | `boolean` | not null default `false` | Soft delete marker. |
| `deleted_at` | `timestamptz` | nullable | Soft deletion time. |
| `created_at` | `timestamptz` | not null default `now()` | Creation time. |
| `updated_at` | `timestamptz` | not null default `now()` | Update time/cursor. |

Recommended indexes:

```sql
create unique index books_order_unique_active
on books(order_index)
where is_deleted = false;

create index books_delta_idx
on books(updated_at, content_version);
```

### Table: `sections`

| Field | PostgreSQL type | Key | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | primary key default `gen_random_uuid()` | Database id. |
| `book_id` | `uuid` | foreign key references `books(id)` | Parent book. |
| `content_id` | `text` | unique not null | Stable external id, e.g. `mt.b1.s1`. |
| `book_content_id` | `text` | not null | Denormalized stable parent id for client sync/import mapping. |
| `order_index` | `integer` | not null | Section order inside book. |
| `title_hebrew` | `text` | not null default `''` | Current seed has empty values; future admin import can fill them. |
| `title_russian` | `text` | not null | Russian section title. |
| `content_version` | `integer` | not null references `content_versions(version)` | Version when this row was last published. |
| `is_published` | `boolean` | not null default `true` | Public read filter. |
| `is_deleted` | `boolean` | not null default `false` | Soft delete marker. |
| `deleted_at` | `timestamptz` | nullable | Soft deletion time. |
| `created_at` | `timestamptz` | not null default `now()` | Creation time. |
| `updated_at` | `timestamptz` | not null default `now()` | Update time/cursor. |

Recommended constraints and indexes:

```sql
alter table sections
add constraint sections_book_order_unique
unique (book_id, order_index);

create index sections_book_order_idx
on sections(book_id, order_index);

create index sections_delta_idx
on sections(updated_at, content_version);
```

### Table: `chapters`

| Field | PostgreSQL type | Key | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | primary key default `gen_random_uuid()` | Database id. |
| `section_id` | `uuid` | foreign key references `sections(id)` | Parent section. |
| `content_id` | `text` | unique not null | Stable external id, e.g. `mt.b1.s1.c1`. |
| `section_content_id` | `text` | not null | Denormalized stable parent id for client sync/import mapping. |
| `number` | `integer` | not null | Chapter number inside section. |
| `m770_id` | `integer` | unique nullable | Current JSON `m770Id`; currently present and unique for all chapters. |
| `m770_url` | `text` | nullable | Current JSON `m770Url`. |
| `content_version` | `integer` | not null references `content_versions(version)` | Version when this row was last published. |
| `is_published` | `boolean` | not null default `true` | Public read filter. |
| `is_deleted` | `boolean` | not null default `false` | Soft delete marker. |
| `deleted_at` | `timestamptz` | nullable | Soft deletion time. |
| `created_at` | `timestamptz` | not null default `now()` | Creation time. |
| `updated_at` | `timestamptz` | not null default `now()` | Update time/cursor. |

Recommended constraints and indexes:

```sql
alter table chapters
add constraint chapters_section_number_unique
unique (section_id, number);

create index chapters_section_number_idx
on chapters(section_id, number);

create index chapters_delta_idx
on chapters(updated_at, content_version);
```

### Table: `halakhot`

This is the minimal downloadable text block table. Every row must have a stable unique `content_id`.

| Field | PostgreSQL type | Key | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | primary key default `gen_random_uuid()` | Database id. |
| `chapter_id` | `uuid` | foreign key references `chapters(id)` | Parent chapter. |
| `content_id` | `text` | unique not null | Stable id, e.g. `mt.b1.s1.c1.h1` or `mt.b8.s1.c2.h8.p2`. |
| `chapter_content_id` | `text` | not null | Denormalized stable parent id for client sync/import mapping. |
| `number` | `integer` | not null | Display law number. May duplicate inside a chapter due current source data. |
| `part_index` | `integer` | not null default `1` | Disambiguates duplicate law numbers inside the same chapter. |
| `sort_index` | `integer` | not null | Stable order inside chapter. Do not rely only on `number`. |
| `hebrew_text` | `text` | not null default `''` | Hebrew text. Empty allowed for current 5 rows. |
| `russian_text` | `text` | not null default `''` | Russian text. |
| `notes` | `jsonb` | not null default `'[]'::jsonb` | Array of note strings or future note objects. |
| `source_hash` | `text` | nullable | Optional SHA-256 hash of normalized text for import verification. |
| `content_version` | `integer` | not null references `content_versions(version)` | Version when this row was last published. |
| `is_published` | `boolean` | not null default `true` | Public read filter. |
| `is_deleted` | `boolean` | not null default `false` | Soft delete marker. |
| `deleted_at` | `timestamptz` | nullable | Soft deletion time. |
| `created_at` | `timestamptz` | not null default `now()` | Creation time. |
| `updated_at` | `timestamptz` | not null default `now()` | Update time/cursor. |

Recommended constraints and indexes:

```sql
alter table halakhot
add constraint halakhot_chapter_sort_unique
unique (chapter_id, sort_index);

alter table halakhot
add constraint halakhot_chapter_number_part_unique
unique (chapter_id, number, part_index);

create index halakhot_chapter_sort_idx
on halakhot(chapter_id, sort_index);

create index halakhot_delta_idx
on halakhot(updated_at, content_version);

create index halakhot_published_delta_idx
on halakhot(updated_at)
where is_published = true;
```

Optional full-text indexes can be added later. For Russian/Hebrew search quality, client-side local search may remain primary until server search is intentionally designed.

## Mapping: JSON to Supabase

### Books

| JSON path | Supabase field |
| --- | --- |
| `book.order` | `books.order_index` |
| generated `mt.b{order}` | `books.content_id` |
| `book.titleHebrew` | `books.title_hebrew` |
| `book.titleRussian` | `books.title_russian` |
| `book.sourceTitle` | `books.source_title` |

### Sections

| JSON path | Supabase field |
| --- | --- |
| `book.order` + `section.order` | stable ids and parent mapping |
| generated `mt.b{book_order}.s{section_order}` | `sections.content_id` |
| generated `mt.b{book_order}` | `sections.book_content_id` |
| `section.order` | `sections.order_index` |
| `section.titleHebrew` | `sections.title_hebrew` |
| `section.titleRussian` | `sections.title_russian` |

### Chapters

| JSON path | Supabase field |
| --- | --- |
| generated `mt.b{book_order}.s{section_order}.c{chapter_number}` | `chapters.content_id` |
| generated `mt.b{book_order}.s{section_order}` | `chapters.section_content_id` |
| `chapter.number` | `chapters.number` |
| `chapter.m770Id` | `chapters.m770_id` |
| `chapter.m770Url` | `chapters.m770_url` |

### Halakhot

| JSON path | Supabase field |
| --- | --- |
| generated `mt.b{book_order}.s{section_order}.c{chapter_number}.h{law_number}` | `halakhot.content_id` for unique law-number paths |
| generated `...h{law_number}.p{part_index}` | `halakhot.content_id` for duplicate law-number paths |
| generated chapter id | `halakhot.chapter_content_id` |
| `halakhah.number` | `halakhot.number` |
| duplicate counter | `halakhot.part_index` |
| array position inside chapter | `halakhot.sort_index` |
| `halakhah.hebrewText` | `halakhot.hebrew_text` |
| `halakhah.russianText` | `halakhot.russian_text` |
| `halakhah.notes` | `halakhot.notes` |

## Import Strategy for `seed_books.json`

Recommended first import:

1. Create a `content_versions` row with `status = 'draft'`, e.g. `version = 1`.
2. Parse `seed_books.json` with a script that validates:
   - total counts;
   - required fields;
   - unique book, section, and chapter paths;
   - duplicate law-number paths and generated `part_index`;
   - unique final `content_id` for every law row.
3. Upsert books by `content_id`.
4. Upsert sections by `content_id`, linking to books.
5. Upsert chapters by `content_id`, linking to sections and preserving `m770_id` and `m770_url`.
6. Upsert halakhot by `content_id`, linking to chapters.
7. Verify counts in PostgreSQL:
   - 14 books;
   - 84 sections;
   - 1004 chapters;
   - 15066 laws.
8. Mark the version as `published` and set `published_at`.

For future imports, never delete rows physically as the first operation. Use `is_deleted = true` and `deleted_at` so clients can safely apply deletions only after they have received a valid tombstone.

## Offline-First Sync Strategy

The app should continue to work in three layers:

1. Bundled seed layer: `seed_books.json` remains inside the app bundle as the emergency initial copy.
2. Local database layer: SwiftData remains the source read by the UI.
3. Remote update layer: Supabase is checked later only for published changes.

Rules:

- The UI should read from local SwiftData only.
- Network sync should never block app startup.
- If Supabase is unavailable, the app should silently continue with the last local content copy.
- A failed sync must not erase or partially overwrite the last valid local corpus.
- User data should remain local and must point to stable content ids, not random seeded UUIDs, before remote sync becomes active.
- Remote content updates should be staged and validated before being applied to the visible local store.

Recommended future local metadata:

- `lastSuccessfulContentVersion`
- `lastSuccessfulSyncAt`
- `lastRemoteUpdatedAtCursor`
- `lastSyncError`
- `contentSchemaVersion`

This metadata can live in a future SwiftData model such as `MTContentSyncState`.

## Versioning and Delta Sync

Two compatible approaches are possible.

### Preferred: Global Version + Updated Cursor

Use `content_versions.version` as a coarse global version and each table's `updated_at` as a fine-grained cursor.

Client flow:

1. Read local `lastSuccessfulContentVersion` and `lastRemoteUpdatedAtCursor`.
2. Request latest published content version.
3. If remote version is equal to local version, do nothing.
4. If remote version is greater, request changed rows from all content tables:
   - rows where `content_version > localVersion`, or
   - rows where `updated_at > lastRemoteUpdatedAtCursor`.
5. Download rows in parent-first order:
   - books;
   - sections;
   - chapters;
   - halakhot.
6. Stage all changes locally.
7. Validate relationships and counts/checksums if the version expects them.
8. Apply changes in one safe transaction if possible.
9. Update local sync metadata only after all changes succeed.

### Delta Endpoint Query Pattern

Example query logic:

```sql
select *
from halakhot
where is_published = true
  and updated_at > :last_remote_updated_at
order by updated_at asc, content_id asc
limit 1000;
```

For deleted rows:

```sql
select content_id, updated_at, deleted_at, is_deleted
from halakhot
where updated_at > :last_remote_updated_at
  and is_deleted = true
order by updated_at asc, content_id asc;
```

### Safe Application Rules

- Upsert by stable `content_id`.
- Do not match remote content to local rows by generated UUID.
- Do not apply a child row if its parent is missing unless the parent is in the same staged batch.
- Do not advance the local cursor until all pages of all tables for the version are applied.
- Keep previous local data if validation fails.
- Treat soft deletes as tombstones; hide them from UI only after successful application.

## Supabase RLS Policies

Enable RLS on every content table:

```sql
alter table content_versions enable row level security;
alter table books enable row level security;
alter table sections enable row level security;
alter table chapters enable row level security;
alter table halakhot enable row level security;
```

Public client can only read published, non-deleted content.

Example policies:

```sql
create policy "Public can read published content versions"
on content_versions
for select
to anon, authenticated
using (status = 'published');

create policy "Public can read published books"
on books
for select
to anon, authenticated
using (is_published = true and is_deleted = false);

create policy "Public can read published sections"
on sections
for select
to anon, authenticated
using (is_published = true and is_deleted = false);

create policy "Public can read published chapters"
on chapters
for select
to anon, authenticated
using (is_published = true and is_deleted = false);

create policy "Public can read published halakhot"
on halakhot
for select
to anon, authenticated
using (is_published = true and is_deleted = false);
```

Do not create public insert/update/delete policies.

Admin editing options:

- Use Supabase Dashboard with service role credentials.
- Use a future admin web app through a secure backend using the service role key.
- Never ship service role keys in the iOS/macOS app.

If authenticated admin users are later needed directly in Supabase, use a dedicated admin table and restrictive policies, but this should be a separate design step.

## App Migration Plan

### Phase 0: Current State

- Keep `seed_books.json`.
- Keep SwiftData as the only runtime data source.
- Do not add Supabase SDK.
- Add this architecture document.

### Phase 1: Add Stable Local Content IDs

Add stable content id fields to SwiftData content models:

- `MTBook.contentID`
- `MTSection.contentID`
- `MTChapter.contentID`
- `MTHalakhah.contentID`
- optionally `MTHalakhah.partIndex` and `MTHalakhah.sortIndex`

Then update `SeedDataLoader` to generate the same ids planned for Supabase. Bookmarks, history, and highlights should eventually reference content ids or be recoverable from content ids.

### Phase 2: Build Import/Validation Tooling

Create a local import script that reads `seed_books.json`, generates stable ids, validates duplicates, and can emit SQL/CSV for Supabase import.

### Phase 3: Create Supabase Tables and RLS

Apply SQL schema in Supabase. Import version 1 as draft, validate counts, then publish.

### Phase 4: Add Read-Only Sync Service

Add a content sync service in the app, but keep UI reading from SwiftData.

The service should:

- check latest published version;
- download deltas only;
- stage and validate changes;
- apply changes safely;
- preserve offline behavior if network fails.

### Phase 5: Improve Admin Workflow

Create scripts or an admin UI for correcting text, adding section Hebrew titles, managing versions, and publishing updates.

## Migration Risks

1. Current UUIDs are not stable. Reseeding creates new content objects and breaks durable references unless stable `content_id` is added.
2. `replaceLibraryData` currently deletes bookmarks and reading history before reseeding. This is risky for future updates and should be replaced by upsert-based content migration.
3. Law number alone is not unique inside all chapters. Remote ids need `part_index` or another stable disambiguator.
4. Section Hebrew titles are empty in the current seed. Supabase should preserve the field but allow later enrichment.
5. Some Hebrew text fields are empty. The database must allow empty Hebrew text unless the source is cleaned first.
6. Notes are currently an array of strings, but future note features may need structured note objects. `jsonb` keeps that path open.
7. A large all-at-once update could be slow on first sync. Delta sync and paginated queries are required.
8. Deletions must be soft deletes, otherwise clients can miss deletion events and keep stale rows forever.

## Summary Recommendation

Use Supabase as a read-only published content source and keep SwiftData as the offline runtime store. The next technical step should be adding stable `content_id` fields locally while keeping `seed_books.json` untouched, then building a validated import script that produces the same ids for Supabase.
