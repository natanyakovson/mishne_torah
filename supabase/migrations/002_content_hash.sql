-- Add deterministic content hashes for hash-aware imports and delta sync.
-- The importer updates rows only when content_hash changes, preventing
-- unchanged rows from receiving new updated_at/content_version values.

alter table public.books
add column if not exists content_hash text not null default '';

alter table public.sections
add column if not exists content_hash text not null default '';

alter table public.chapters
add column if not exists content_hash text not null default '';

alter table public.halakhot
add column if not exists content_hash text not null default '';

create index if not exists books_content_hash_idx
on public.books(content_hash);

create index if not exists sections_content_hash_idx
on public.sections(content_hash);

create index if not exists chapters_content_hash_idx
on public.chapters(content_hash);

create index if not exists halakhot_content_hash_idx
on public.halakhot(content_hash);
