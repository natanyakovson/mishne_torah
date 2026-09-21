-- Run on an isolated database with migrations applied. All fixture changes roll back.
begin;
insert into public.content_meta(id, content_version, schema_version) values (1, 1, 2)
on conflict (id) do update set content_version = 1, schema_version = 2;
insert into public.books(content_id,title_ru,sort_order) values ('test:book','Test',999);
insert into public.sections(content_id,book_id,title_ru,sort_order)
select 'test:section',id,'Test',999 from public.books where content_id='test:book';
insert into public.chapters(content_id,section_id,chapter_number,sort_order)
select 'test:chapter',id,999,999 from public.sections where content_id='test:section';
insert into public.halakhot(content_id,chapter_id,law_number,text_ru,text_he,sort_order)
select 'test:law',id,1,'OLD RU','OLD HE',1 from public.chapters where content_id='test:chapter';

update public.halakhot set text_ru='UPDATED RU',text_he='UPDATED HE' where content_id='test:law';
do $$ begin
  if (select content_version from public.content_meta where id=1) <> 2 then
    raise exception 'Dashboard edit did not publish version';
  end if;
  if (select count(*) from public.halakhot where content_version > 1 and text_ru='UPDATED RU' and text_he='UPDATED HE') <> 1 then
    raise exception 'One-law delta failed';
  end if;
  if has_table_privilege('anon','public.halakhot','UPDATE') or has_table_privilege('anon','public.halakhot','INSERT')
     or has_table_privilege('anon','public.halakhot','DELETE') then
    raise exception 'Public writes must be denied';
  end if;
end $$;

update public.halakhot set text_ru='UPDATED RU' where content_id='test:law';
do $$ begin
  if (select content_version from public.content_meta where id=1) <> 2 then
    raise exception 'No-op edit changed version';
  end if;
end $$;

update public.halakhot set is_published=false where content_id='test:law';
set local role anon;
do $$ begin
  if exists(select 1 from public.halakhot where content_id='test:law') then
    raise exception 'Hidden text exposed';
  end if;
  if not exists(select 1 from public.content_tombstones() where content_id='test:law' and content_version=3) then
    raise exception 'Soft-delete marker not exposed';
  end if;
end $$;
reset role;

-- An explicit importer version is staged, including hash-only repairs.
update public.halakhot set content_hash='repaired',content_version=4 where content_id='test:law';
do $$ begin
  if (select content_version from public.content_meta where id=1) <> 3
     or (select content_version from public.halakhot where content_id='test:law') <> 4 then
    raise exception 'Importer staging changed';
  end if;
  begin
    update public.halakhot set text_ru='DURING IMPORT' where content_id='test:law';
    raise exception 'Dashboard edit allowed during incomplete import';
  exception when raise_exception then
    if sqlerrm <> 'Finish the pending content import before editing in Dashboard' then raise; end if;
  end;
end $$;
rollback;
