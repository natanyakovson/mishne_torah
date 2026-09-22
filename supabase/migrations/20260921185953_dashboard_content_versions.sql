-- Dashboard edits publish a new version in the SAME transaction as the text.
-- Explicit version changes remain reserved for the existing batch importer.
begin;

create or replace function public.publish_dashboard_content_edit()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  published_version bigint;
begin
  if new.id <> old.id or new.content_id <> old.content_id then
    raise exception 'Content identities are immutable';
  end if;
  if new.content_version = old.content_version and
     (to_jsonb(new) - array['updated_at','created_at','content_hash','content_version'])
     = (to_jsonb(old) - array['updated_at','created_at','content_hash','content_version']) then
    return old;
  end if;
  if new.content_version = old.content_version then
    select content_version into strict published_version
    from public.content_meta where id = 1 for update;
    if exists(select 1 from public.books where content_version > published_version)
       or exists(select 1 from public.sections where content_version > published_version)
       or exists(select 1 from public.chapters where content_version > published_version)
       or exists(select 1 from public.halakhot where content_version > published_version) then
      raise exception 'Finish the pending content import before editing in Dashboard';
    end if;
    update public.content_meta set content_version = published_version + 1 where id = 1
      returning content_version into new.content_version;
    -- Invalidate the import hash: it no longer describes the edited text.
    new.content_hash = '';
  end if;
  return new;
end;
$$;
revoke all on function public.publish_dashboard_content_edit() from public, anon, authenticated;

-- Publish Dashboard edits made before this trigger existed. The timestamp is
-- compared with the last successfully published corpus timestamp; text itself
-- is never rewritten here.
do $$
declare
  published_version bigint;
  published_at timestamptz;
  changed_rows bigint;
begin
  select content_version, updated_at into published_version, published_at
  from public.content_meta where id = 1 for update;

  select count(*) into changed_rows from (
    select 1 from public.books where updated_at > published_at and content_version <= published_version
    union all select 1 from public.sections where updated_at > published_at and content_version <= published_version
    union all select 1 from public.chapters where updated_at > published_at and content_version <= published_version
    union all select 1 from public.halakhot where updated_at > published_at and content_version <= published_version
  ) pending;

  if changed_rows > 0 then
    update public.books set content_version = published_version + 1, content_hash = ''
      where updated_at > published_at and content_version <= published_version;
    update public.sections set content_version = published_version + 1, content_hash = ''
      where updated_at > published_at and content_version <= published_version;
    update public.chapters set content_version = published_version + 1, content_hash = ''
      where updated_at > published_at and content_version <= published_version;
    update public.halakhot set content_version = published_version + 1, content_hash = ''
      where updated_at > published_at and content_version <= published_version;
    update public.content_meta set content_version = published_version + 1 where id = 1;
  end if;
end;
$$;

create trigger zz_publish_dashboard_edit before update on public.books
for each row execute function public.publish_dashboard_content_edit();
create trigger zz_publish_dashboard_edit before update on public.sections
for each row execute function public.publish_dashboard_content_edit();
create trigger zz_publish_dashboard_edit before update on public.chapters
for each row execute function public.publish_dashboard_content_edit();
create trigger zz_publish_dashboard_edit before update on public.halakhot
for each row execute function public.publish_dashboard_content_edit();

-- Hidden text remains private. Expose only tombstone identity/version metadata
-- to support the existing local deletedAt mechanism without relaxing table RLS.
create or replace function public.content_tombstones()
returns table (table_name text, content_id text, content_version bigint, deleted_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select 'books', content_id, content_version, coalesce(deleted_at, updated_at)
  from public.books where not is_published or deleted_at is not null
  union all
  select 'sections', content_id, content_version, coalesce(deleted_at, updated_at)
  from public.sections where not is_published or deleted_at is not null
  union all
  select 'chapters', content_id, content_version, coalesce(deleted_at, updated_at)
  from public.chapters where not is_published or deleted_at is not null
  union all
  select 'halakhot', content_id, content_version, coalesce(deleted_at, updated_at)
  from public.halakhot where not is_published or deleted_at is not null;
$$;
revoke all on function public.content_tombstones() from public;
grant execute on function public.content_tombstones() to anon, authenticated, service_role;

revoke all on public.books, public.sections, public.chapters, public.halakhot, public.content_meta from public, anon, authenticated;
grant select on public.books, public.sections, public.chapters, public.halakhot, public.content_meta to anon, authenticated;
grant all on public.books, public.sections, public.chapters, public.halakhot, public.content_meta to service_role;
commit;
