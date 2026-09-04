-- Verification queries for the Mishne Torah Supabase content import.
-- Run this file in Supabase SQL Editor after importing seed_books.json.

select
  'books count' as check_name,
  count(*) = 14 as ok,
  count(*) as actual,
  14 as expected
from public.books
where deleted_at is null;

select
  'sections count' as check_name,
  count(*) = 84 as ok,
  count(*) as actual,
  84 as expected
from public.sections
where deleted_at is null;

select
  'chapters count' as check_name,
  count(*) = 1004 as ok,
  count(*) as actual,
  1004 as expected
from public.chapters
where deleted_at is null;

select
  'halakhot count' as check_name,
  count(*) = 15066 as ok,
  count(*) as actual,
  15066 as expected
from public.halakhot
where deleted_at is null;

select
  'duplicate book content_id' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select content_id
  from public.books
  group by content_id
  having count(*) > 1
) duplicates;

select
  'books content_hash valid' as check_name,
  count(*) = 0 as ok,
  count(*) as invalid_count
from public.books
where content_hash is null or content_hash !~ '^[0-9a-f]{64}$';

select
  'duplicate section content_id' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select content_id
  from public.sections
  group by content_id
  having count(*) > 1
) duplicates;

select
  'sections content_hash valid' as check_name,
  count(*) = 0 as ok,
  count(*) as invalid_count
from public.sections
where content_hash is null or content_hash !~ '^[0-9a-f]{64}$';

select
  'duplicate chapter content_id' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select content_id
  from public.chapters
  group by content_id
  having count(*) > 1
) duplicates;

select
  'chapters content_hash valid' as check_name,
  count(*) = 0 as ok,
  count(*) as invalid_count
from public.chapters
where content_hash is null or content_hash !~ '^[0-9a-f]{64}$';

select
  'duplicate halakhah content_id' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select content_id
  from public.halakhot
  group by content_id
  having count(*) > 1
) duplicates;

select
  'halakhot content_hash valid' as check_name,
  count(*) = 0 as ok,
  count(*) as invalid_count
from public.halakhot
where content_hash is null or content_hash !~ '^[0-9a-f]{64}$';

select
  'orphan sections' as check_name,
  count(*) = 0 as ok,
  count(*) as orphan_count
from public.sections s
left join public.books b on b.id = s.book_id
where b.id is null;

select
  'orphan chapters' as check_name,
  count(*) = 0 as ok,
  count(*) as orphan_count
from public.chapters c
left join public.sections s on s.id = c.section_id
where s.id is null;

select
  'orphan halakhot' as check_name,
  count(*) = 0 as ok,
  count(*) as orphan_count
from public.halakhot h
left join public.chapters c on c.id = h.chapter_id
where c.id is null;

select
  'duplicate m770_id' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select m770_id
  from public.chapters
  where m770_id is not null
  group by m770_id
  having count(*) > 1
) duplicates;

select
  'chapters missing m770_id' as check_name,
  count(*) = 0 as ok,
  count(*) as missing_count
from public.chapters
where m770_id is null or m770_id = '';

select
  'duplicate law_number/part_index per chapter' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select chapter_id, law_number, part_index
  from public.halakhot
  group by chapter_id, law_number, part_index
  having count(*) > 1
) duplicates;

select
  'duplicate sort_order per chapter' as check_name,
  count(*) = 0 as ok,
  count(*) as duplicate_groups
from (
  select chapter_id, sort_order
  from public.halakhot
  group by chapter_id, sort_order
  having count(*) > 1
) duplicates;

select
  'part_index starts at zero for every law group' as check_name,
  count(*) = 0 as ok,
  count(*) as broken_groups
from (
  select chapter_id, law_number, min(part_index) as min_part_index
  from public.halakhot
  group by chapter_id, law_number
  having min(part_index) <> 0
) broken;

select
  'part_index has no gaps' as check_name,
  count(*) = 0 as ok,
  count(*) as broken_groups
from (
  select
    chapter_id,
    law_number,
    count(*) as row_count,
    max(part_index) as max_part_index
  from public.halakhot
  group by chapter_id, law_number
  having max(part_index) <> count(*) - 1
) broken;

select
  'content_meta singleton exists' as check_name,
  count(*) = 1 as ok,
  count(*) as actual,
  1 as expected
from public.content_meta
where id = 1;
