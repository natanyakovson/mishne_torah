-- Mishne Torah content schema for Supabase.
-- This migration creates read-only public content tables. The iOS/macOS app
-- must never contain the service_role key.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.content_meta (
  id smallint primary key default 1,
  content_version bigint not null,
  schema_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_meta_singleton check (id = 1)
);

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  content_id text unique not null,
  title_ru text not null,
  title_he text not null default '',
  source_title text,
  sort_order integer not null,
  content_version bigint not null default 1,
  is_published boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  content_id text unique not null,
  book_id uuid not null references public.books(id) on delete restrict,
  title_ru text not null,
  title_he text not null default '',
  sort_order integer not null,
  content_version bigint not null default 1,
  is_published boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sections_book_sort_unique unique (book_id, sort_order)
);

create table if not exists public.chapters (
  id uuid primary key default gen_random_uuid(),
  content_id text unique not null,
  section_id uuid not null references public.sections(id) on delete restrict,
  chapter_number integer not null,
  title_ru text,
  m770_id text unique,
  m770_url text,
  sort_order integer not null,
  content_version bigint not null default 1,
  is_published boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chapters_section_number_unique unique (section_id, chapter_number)
);

create table if not exists public.halakhot (
  id uuid primary key default gen_random_uuid(),
  content_id text unique not null,
  chapter_id uuid not null references public.chapters(id) on delete restrict,
  law_number integer not null,
  part_index integer not null default 0,
  text_ru text not null,
  text_he text not null default '',
  notes jsonb not null default '[]'::jsonb,
  sort_order integer not null,
  content_version bigint not null default 1,
  is_published boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint halakhot_chapter_sort_unique unique (chapter_id, sort_order),
  constraint halakhot_chapter_law_part_unique unique (chapter_id, law_number, part_index),
  constraint halakhot_notes_array check (jsonb_typeof(notes) = 'array')
);

create index if not exists books_sort_order_idx
on public.books(sort_order);

create index if not exists books_delta_idx
on public.books(updated_at, content_version);

create index if not exists sections_book_sort_idx
on public.sections(book_id, sort_order);

create index if not exists sections_delta_idx
on public.sections(updated_at, content_version);

create index if not exists chapters_section_sort_idx
on public.chapters(section_id, sort_order);

create index if not exists chapters_m770_id_idx
on public.chapters(m770_id);

create index if not exists chapters_delta_idx
on public.chapters(updated_at, content_version);

create index if not exists halakhot_chapter_sort_idx
on public.halakhot(chapter_id, sort_order);

create index if not exists halakhot_delta_idx
on public.halakhot(updated_at, content_version);

create index if not exists halakhot_published_delta_idx
on public.halakhot(updated_at)
where is_published = true and deleted_at is null;

drop trigger if exists set_content_meta_updated_at on public.content_meta;
create trigger set_content_meta_updated_at
before update on public.content_meta
for each row execute function public.set_updated_at();

drop trigger if exists set_books_updated_at on public.books;
create trigger set_books_updated_at
before update on public.books
for each row execute function public.set_updated_at();

drop trigger if exists set_sections_updated_at on public.sections;
create trigger set_sections_updated_at
before update on public.sections
for each row execute function public.set_updated_at();

drop trigger if exists set_chapters_updated_at on public.chapters;
create trigger set_chapters_updated_at
before update on public.chapters
for each row execute function public.set_updated_at();

drop trigger if exists set_halakhot_updated_at on public.halakhot;
create trigger set_halakhot_updated_at
before update on public.halakhot
for each row execute function public.set_updated_at();

alter table public.content_meta enable row level security;
alter table public.books enable row level security;
alter table public.sections enable row level security;
alter table public.chapters enable row level security;
alter table public.halakhot enable row level security;

drop policy if exists "Public can read content meta" on public.content_meta;
create policy "Public can read content meta"
on public.content_meta
for select
to anon, authenticated
using (true);

drop policy if exists "Public can read published books" on public.books;
create policy "Public can read published books"
on public.books
for select
to anon, authenticated
using (is_published = true and deleted_at is null);

drop policy if exists "Public can read published sections" on public.sections;
create policy "Public can read published sections"
on public.sections
for select
to anon, authenticated
using (is_published = true and deleted_at is null);

drop policy if exists "Public can read published chapters" on public.chapters;
create policy "Public can read published chapters"
on public.chapters
for select
to anon, authenticated
using (is_published = true and deleted_at is null);

drop policy if exists "Public can read published halakhot" on public.halakhot;
create policy "Public can read published halakhot"
on public.halakhot
for select
to anon, authenticated
using (is_published = true and deleted_at is null);

-- No INSERT/UPDATE/DELETE policies are created for anon/authenticated users.
-- Supabase service_role bypasses RLS and should be used only from secure admin
-- environments or import scripts, never from the client app.
