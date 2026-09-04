#!/usr/bin/env python3
"""Import bundled Mishne Torah seed content into Supabase.

The script is intentionally independent of the iOS app. It reads
Sources/MishnehTorahApp/Resources/seed_books.json, generates deterministic
content_id values, validates uniqueness, and can upsert rows through the
Supabase REST API.

Required for real import:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY

Never put the service_role key into the iOS/macOS project.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SEED_PATH = ROOT / "Sources/MishnehTorahApp/Resources/seed_books.json"
EXPECTED_COUNTS = {
    "books": 14,
    "sections": 84,
    "chapters": 1004,
    "halakhot": 15066,
}


@dataclass(frozen=True)
class ImportBundle:
    books: list[dict[str, Any]]
    sections: list[dict[str, Any]]
    chapters: list[dict[str, Any]]
    halakhot: list[dict[str, Any]]
    duplicate_law_paths: list[str]
    empty_hebrew_halakhot: int
    note_rows: int


@dataclass(frozen=True)
class ImportStats:
    inserted: int
    updated: int
    unchanged: int


class ValidationError(Exception):
    pass


def load_seed(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)

    if not isinstance(data, list):
        raise ValidationError("seed root must be a JSON array")
    return data


def require(value: Any, path: str) -> Any:
    if value is None:
        raise ValidationError(f"missing required value: {path}")
    return value


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def content_hash(fields: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json(fields).encode("utf-8")).hexdigest()


def with_hash(row: dict[str, Any], hash_fields: dict[str, Any]) -> dict[str, Any]:
    copy = dict(row)
    copy["content_hash"] = content_hash(hash_fields)
    return copy


def build_import_bundle(seed: list[dict[str, Any]], content_version: int) -> ImportBundle:
    books: list[dict[str, Any]] = []
    sections: list[dict[str, Any]] = []
    chapters: list[dict[str, Any]] = []
    halakhot: list[dict[str, Any]] = []

    raw_law_paths: Counter[str] = Counter()
    law_path_occurrences: defaultdict[str, int] = defaultdict(int)
    m770_ids: list[str] = []
    empty_hebrew_halakhot = 0
    note_rows = 0

    for book in seed:
        book_order = int(require(book.get("order"), "book.order"))
        book_content_id = f"book:{book_order}"
        book_row = {
            "content_id": book_content_id,
            "title_ru": require(book.get("titleRussian"), f"{book_content_id}.titleRussian"),
            "title_he": book.get("titleHebrew") or "",
            "source_title": book.get("sourceTitle"),
            "sort_order": book_order,
            "content_version": content_version,
            "is_published": True,
            "deleted_at": None,
        }
        books.append(
            with_hash(
                book_row,
                {
                    "content_id": book_row["content_id"],
                    "title_ru": book_row["title_ru"],
                    "title_he": book_row["title_he"],
                    "source_title": book_row["source_title"],
                    "sort_order": book_row["sort_order"],
                    "is_published": book_row["is_published"],
                    "deleted_at": book_row["deleted_at"],
                },
            )
        )

        for section in require(book.get("sections"), f"{book_content_id}.sections"):
            section_order = int(require(section.get("order"), f"{book_content_id}.section.order"))
            section_content_id = f"section:{book_order}:{section_order}"
            section_row = {
                "content_id": section_content_id,
                "book_content_id": book_content_id,
                "title_ru": require(section.get("titleRussian"), f"{section_content_id}.titleRussian"),
                "title_he": section.get("titleHebrew") or "",
                "sort_order": section_order,
                "content_version": content_version,
                "is_published": True,
                "deleted_at": None,
            }
            sections.append(
                with_hash(
                    section_row,
                    {
                        "content_id": section_row["content_id"],
                        "book_content_id": section_row["book_content_id"],
                        "title_ru": section_row["title_ru"],
                        "title_he": section_row["title_he"],
                        "sort_order": section_row["sort_order"],
                        "is_published": section_row["is_published"],
                        "deleted_at": section_row["deleted_at"],
                    },
                )
            )

            for chapter in require(section.get("chapters"), f"{section_content_id}.chapters"):
                chapter_number = int(require(chapter.get("number"), f"{section_content_id}.chapter.number"))
                m770_id = str(require(chapter.get("m770Id"), f"{section_content_id}.chapter.m770Id"))
                chapter_content_id = f"chapter:{m770_id}"
                m770_ids.append(m770_id)
                chapter_row = {
                    "content_id": chapter_content_id,
                    "section_content_id": section_content_id,
                    "chapter_number": chapter_number,
                    "title_ru": None,
                    "m770_id": m770_id,
                    "m770_url": chapter.get("m770Url"),
                    "sort_order": chapter_number,
                    "content_version": content_version,
                    "is_published": True,
                    "deleted_at": None,
                }
                chapters.append(
                    with_hash(
                        chapter_row,
                        {
                            "content_id": chapter_row["content_id"],
                            "section_content_id": chapter_row["section_content_id"],
                            "chapter_number": chapter_row["chapter_number"],
                            "title_ru": chapter_row["title_ru"],
                            "m770_id": chapter_row["m770_id"],
                            "m770_url": chapter_row["m770_url"],
                            "sort_order": chapter_row["sort_order"],
                            "is_published": chapter_row["is_published"],
                            "deleted_at": chapter_row["deleted_at"],
                        },
                    )
                )

                for sort_index, law in enumerate(require(chapter.get("halakhot"), f"{chapter_content_id}.halakhot"), start=1):
                    law_number = int(require(law.get("number"), f"{chapter_content_id}.halakhah.number"))
                    raw_law_path = f"halakha:{m770_id}:{law_number}"
                    raw_law_paths[raw_law_path] += 1
                    part_index = law_path_occurrences[raw_law_path]
                    law_path_occurrences[raw_law_path] += 1
                    text_he = law.get("hebrewText") or ""
                    text_ru = law.get("russianText") or ""
                    notes = law.get("notes") or []

                    if not text_he:
                        empty_hebrew_halakhot += 1
                    if notes:
                        note_rows += 1
                    if not text_ru:
                        raise ValidationError(f"empty russianText: {raw_law_path}:{part_index}")
                    if not isinstance(notes, list):
                        raise ValidationError(f"notes must be an array: {raw_law_path}:{part_index}")

                    halakhah_row = {
                        "content_id": f"{raw_law_path}:{part_index}",
                        "chapter_content_id": chapter_content_id,
                        "law_number": law_number,
                        "part_index": part_index,
                        "text_ru": text_ru,
                        "text_he": text_he,
                        "notes": notes,
                        "sort_order": sort_index,
                        "content_version": content_version,
                        "is_published": True,
                        "deleted_at": None,
                    }
                    halakhot.append(
                        with_hash(
                            halakhah_row,
                            {
                                "content_id": halakhah_row["content_id"],
                                "chapter_content_id": halakhah_row["chapter_content_id"],
                                "law_number": halakhah_row["law_number"],
                                "part_index": halakhah_row["part_index"],
                                "text_ru": halakhah_row["text_ru"],
                                "text_he": halakhah_row["text_he"],
                                "notes": halakhah_row["notes"],
                                "sort_order": halakhah_row["sort_order"],
                                "is_published": halakhah_row["is_published"],
                                "deleted_at": halakhah_row["deleted_at"],
                            },
                        )
                    )

    duplicate_law_paths = sorted(path for path, count in raw_law_paths.items() if count > 1)
    validate_bundle(books, sections, chapters, halakhot, m770_ids)

    return ImportBundle(
        books=books,
        sections=sections,
        chapters=chapters,
        halakhot=halakhot,
        duplicate_law_paths=duplicate_law_paths,
        empty_hebrew_halakhot=empty_hebrew_halakhot,
        note_rows=note_rows,
    )


def validate_bundle(
    books: list[dict[str, Any]],
    sections: list[dict[str, Any]],
    chapters: list[dict[str, Any]],
    halakhot: list[dict[str, Any]],
    m770_ids: list[str],
) -> None:
    errors: list[str] = []

    for name, rows in [
        ("books", books),
        ("sections", sections),
        ("chapters", chapters),
        ("halakhot", halakhot),
    ]:
        expected = EXPECTED_COUNTS[name]
        if len(rows) != expected:
            errors.append(f"{name}: expected {expected}, got {len(rows)}")

        ids = [row["content_id"] for row in rows]
        duplicate_ids = [content_id for content_id, count in Counter(ids).items() if count > 1]
        if duplicate_ids:
            errors.append(f"{name}: duplicate content_id values: {duplicate_ids[:10]}")

    duplicate_m770_ids = [m770_id for m770_id, count in Counter(m770_ids).items() if count > 1]
    if duplicate_m770_ids:
        errors.append(f"chapters: duplicate m770_id values: {duplicate_m770_ids[:10]}")

    section_parent_ids = {row["book_content_id"] for row in sections}
    book_ids = {row["content_id"] for row in books}
    missing_book_ids = sorted(section_parent_ids - book_ids)
    if missing_book_ids:
        errors.append(f"sections: missing parent books: {missing_book_ids[:10]}")

    chapter_parent_ids = {row["section_content_id"] for row in chapters}
    section_ids = {row["content_id"] for row in sections}
    missing_section_ids = sorted(chapter_parent_ids - section_ids)
    if missing_section_ids:
        errors.append(f"chapters: missing parent sections: {missing_section_ids[:10]}")

    halakhah_parent_ids = {row["chapter_content_id"] for row in halakhot}
    chapter_ids = {row["content_id"] for row in chapters}
    missing_chapter_ids = sorted(halakhah_parent_ids - chapter_ids)
    if missing_chapter_ids:
        errors.append(f"halakhot: missing parent chapters: {missing_chapter_ids[:10]}")

    for chapter_id, rows in group_by(halakhot, "chapter_content_id").items():
        sort_orders = [row["sort_order"] for row in rows]
        if len(sort_orders) != len(set(sort_orders)):
            errors.append(f"halakhot: duplicate sort_order in {chapter_id}")

        law_parts = [(row["law_number"], row["part_index"]) for row in rows]
        if len(law_parts) != len(set(law_parts)):
            errors.append(f"halakhot: duplicate law_number/part_index in {chapter_id}")

    if errors:
        raise ValidationError("\n".join(errors))


def group_by(rows: list[dict[str, Any]], key: str) -> dict[str, list[dict[str, Any]]]:
    result: defaultdict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        result[str(row[key])].append(row)
    return dict(result)


def print_dry_run(bundle: ImportBundle) -> None:
    all_content_ids = (
        [row["content_id"] for row in bundle.books]
        + [row["content_id"] for row in bundle.sections]
        + [row["content_id"] for row in bundle.chapters]
        + [row["content_id"] for row in bundle.halakhot]
    )
    duplicate_content_ids = [content_id for content_id, count in Counter(all_content_ids).items() if count > 1]

    print("Dry run complete")
    print(f"books: {len(bundle.books)}")
    print(f"sections: {len(bundle.sections)}")
    print(f"chapters: {len(bundle.chapters)}")
    print(f"halakhot: {len(bundle.halakhot)}")
    print(f"duplicate law_number cases: {len(bundle.duplicate_law_paths)}")
    print(f"unique content_id values: {len(set(all_content_ids))}")
    print(f"content_id collisions: {len(duplicate_content_ids)}")
    print(f"halakhot with empty Hebrew text: {bundle.empty_hebrew_halakhot}")
    print(f"halakhot with notes: {bundle.note_rows}")
    if bundle.duplicate_law_paths:
        print("duplicate law_number paths:")
        for path in bundle.duplicate_law_paths:
            print(f"  - {path}")


def classify_rows(rows: list[dict[str, Any]], existing: dict[str, dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], ImportStats]:
    inserted: list[dict[str, Any]] = []
    updated: list[dict[str, Any]] = []
    unchanged = 0

    for row in rows:
        current = existing.get(row["content_id"])
        if current is None:
            inserted.append(row)
        elif current.get("content_hash") == row["content_hash"]:
            unchanged += 1
        else:
            updated.append(row)

    return inserted, updated, ImportStats(
        inserted=len(inserted),
        updated=len(updated),
        unchanged=unchanged,
    )


def print_import_stats(table: str, stats: ImportStats) -> None:
    print(f"{table}: inserted {stats.inserted}, updated {stats.updated}, unchanged {stats.unchanged}")


def supabase_headers(service_role_key: str, prefer: str = "return=representation", extra: dict[str, str] | None = None) -> dict[str, str]:
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": f"resolution=merge-duplicates,{prefer}",
    }
    if extra:
        headers.update(extra)
    return headers


def request_json(
    method: str,
    url: str,
    service_role_key: str,
    payload: Any | None = None,
    prefer: str = "return=representation",
    extra_headers: dict[str, str] | None = None,
) -> Any:
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers=supabase_headers(service_role_key, prefer=prefer, extra=extra_headers),
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase HTTP {error.code}: {detail}") from error

    if not body:
        return None
    return json.loads(body.decode("utf-8"))


def table_url(base_url: str, table: str, *, on_conflict: str | None = None, select: str | None = None) -> str:
    query: dict[str, str] = {}
    if on_conflict:
        query["on_conflict"] = on_conflict
    if select:
        query["select"] = select
    encoded = urllib.parse.urlencode(query)
    suffix = f"?{encoded}" if encoded else ""
    return f"{base_url.rstrip('/')}/rest/v1/{table}{suffix}"


def fetch_existing_rows(base_url: str, service_role_key: str, table: str, *, page_size: int = 1000) -> dict[str, dict[str, Any]]:
    existing: dict[str, dict[str, Any]] = {}
    start = 0

    while True:
        end = start + page_size - 1
        url = table_url(base_url, table, select="id,content_id,content_hash")
        result = request_json(
            "GET",
            url,
            service_role_key,
            prefer="return=representation",
            extra_headers={"Range-Unit": "items", "Range": f"{start}-{end}"},
        )
        if not isinstance(result, list):
            raise RuntimeError(f"{table}: unexpected response while fetching existing rows")
        for row in result:
            existing[row["content_id"]] = row
        if len(result) < page_size:
            break
        start += page_size

    return existing


def upsert_rows(
    base_url: str,
    service_role_key: str,
    table: str,
    rows: list[dict[str, Any]],
    *,
    batch_size: int,
) -> list[dict[str, Any]]:
    returned: list[dict[str, Any]] = []
    if not rows:
        return returned
    url = table_url(base_url, table, on_conflict="content_id")

    for start in range(0, len(rows), batch_size):
        batch = rows[start : start + batch_size]
        result = request_json("POST", url, service_role_key, batch)
        if isinstance(result, list):
            returned.extend(result)
        print(f"upserted {table}: {min(start + batch_size, len(rows))}/{len(rows)}")
    return returned


def build_section_payload(bundle: ImportBundle, book_ids: dict[str, str]) -> list[dict[str, Any]]:
    sections: list[dict[str, Any]] = []
    for row in bundle.sections:
        copy = dict(row)
        book_content_id = copy.pop("book_content_id")
        copy["book_id"] = book_ids[book_content_id]
        sections.append(copy)
    return sections


def build_chapter_payload(bundle: ImportBundle, section_ids: dict[str, str]) -> list[dict[str, Any]]:
    chapters: list[dict[str, Any]] = []
    for row in bundle.chapters:
        copy = dict(row)
        section_content_id = copy.pop("section_content_id")
        copy["section_id"] = section_ids[section_content_id]
        chapters.append(copy)
    return chapters


def build_halakhah_payload(bundle: ImportBundle, chapter_ids: dict[str, str]) -> list[dict[str, Any]]:
    halakhot: list[dict[str, Any]] = []
    for row in bundle.halakhot:
        copy = dict(row)
        chapter_content_id = copy.pop("chapter_content_id")
        copy["chapter_id"] = chapter_ids[chapter_content_id]
        halakhot.append(copy)
    return halakhot


def map_returned_ids(table: str, rows: list[dict[str, Any]], expected_count: int) -> dict[str, str]:
    result = {row["content_id"]: row["id"] for row in rows if row.get("content_id") and row.get("id")}
    if len(result) != expected_count:
        raise RuntimeError(f"{table}: expected {expected_count} returned ids, got {len(result)}")
    return result


def import_to_supabase(bundle: ImportBundle, content_version: int, batch_size: int) -> None:
    base_url = os.environ.get("SUPABASE_URL")
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not base_url or not service_role_key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

    started_at = time.time()
    id_maps: dict[str, dict[str, str]] = {}

    existing_books = fetch_existing_rows(base_url, service_role_key, "books")
    inserted_books, updated_books, book_stats = classify_rows(bundle.books, existing_books)
    book_rows = upsert_rows(base_url, service_role_key, "books", inserted_books + updated_books, batch_size=batch_size)
    id_maps["books"] = {row["content_id"]: row["id"] for row in existing_books.values()}
    id_maps["books"].update({row["content_id"]: row["id"] for row in book_rows})
    print_import_stats("books", book_stats)

    section_payload = build_section_payload(bundle, id_maps["books"])
    existing_sections = fetch_existing_rows(base_url, service_role_key, "sections")
    inserted_sections, updated_sections, section_stats = classify_rows(section_payload, existing_sections)
    section_rows = upsert_rows(base_url, service_role_key, "sections", inserted_sections + updated_sections, batch_size=batch_size)
    id_maps["sections"] = {row["content_id"]: row["id"] for row in existing_sections.values()}
    id_maps["sections"].update({row["content_id"]: row["id"] for row in section_rows})
    print_import_stats("sections", section_stats)

    chapter_payload = build_chapter_payload(bundle, id_maps["sections"])
    existing_chapters = fetch_existing_rows(base_url, service_role_key, "chapters")
    inserted_chapters, updated_chapters, chapter_stats = classify_rows(chapter_payload, existing_chapters)
    chapter_rows = upsert_rows(base_url, service_role_key, "chapters", inserted_chapters + updated_chapters, batch_size=batch_size)
    id_maps["chapters"] = {row["content_id"]: row["id"] for row in existing_chapters.values()}
    id_maps["chapters"].update({row["content_id"]: row["id"] for row in chapter_rows})
    print_import_stats("chapters", chapter_stats)

    halakhah_payload = build_halakhah_payload(bundle, id_maps["chapters"])
    existing_halakhot = fetch_existing_rows(base_url, service_role_key, "halakhot")
    inserted_halakhot, updated_halakhot, halakhah_stats = classify_rows(halakhah_payload, existing_halakhot)
    upsert_rows(base_url, service_role_key, "halakhot", inserted_halakhot + updated_halakhot, batch_size=batch_size)
    print_import_stats("halakhot", halakhah_stats)

    changed_rows = (
        book_stats.inserted
        + book_stats.updated
        + section_stats.inserted
        + section_stats.updated
        + chapter_stats.inserted
        + chapter_stats.updated
        + halakhah_stats.inserted
        + halakhah_stats.updated
    )
    if changed_rows > 0:
        meta_payload = {
            "id": 1,
            "content_version": content_version,
            "schema_version": 2,
        }
        meta_url = table_url(base_url, "content_meta", on_conflict="id")
        request_json("POST", meta_url, service_role_key, [meta_payload], prefer="return=minimal")

    elapsed = time.time() - started_at
    print(f"Import complete in {elapsed:.1f}s")
    if changed_rows > 0:
        print(f"content_meta.content_version updated to {content_version}")
    else:
        print("content_meta.content_version unchanged; no content rows changed")


def simulate_import(bundle: ImportBundle) -> None:
    first_existing: dict[str, dict[str, Any]] = {}

    print("Simulated first import")
    for table, rows in [
        ("books", bundle.books),
        ("sections", bundle.sections),
        ("chapters", bundle.chapters),
        ("halakhot", bundle.halakhot),
    ]:
        _, _, stats = classify_rows(rows, first_existing)
        print_import_stats(table, stats)

    second_existing = {
        row["content_id"]: {"content_id": row["content_id"], "content_hash": row["content_hash"], "id": row["content_id"]}
        for rows in [bundle.books, bundle.sections, bundle.chapters, bundle.halakhot]
        for row in rows
    }

    print("Simulated repeat import without changes")
    for table, rows in [
        ("books", bundle.books),
        ("sections", bundle.sections),
        ("chapters", bundle.chapters),
        ("halakhot", bundle.halakhot),
    ]:
        _, _, stats = classify_rows(rows, second_existing)
        print_import_stats(table, stats)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import seed_books.json into Supabase content tables.")
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED_PATH, help="Path to seed_books.json")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print counts without importing")
    parser.add_argument("--simulate-import", action="store_true", help="Simulate first and repeated hash-aware imports without network access")
    parser.add_argument("--content-version", type=int, default=1, help="Published content version to write")
    parser.add_argument("--batch-size", type=int, default=500, help="Rows per Supabase upsert request")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        seed = load_seed(args.seed)
        bundle = build_import_bundle(seed, args.content_version)
        print_dry_run(bundle)

        if args.simulate_import:
            simulate_import(bundle)

        if args.dry_run:
            return 0

        import_to_supabase(bundle, args.content_version, args.batch_size)
        return 0
    except (OSError, ValidationError, RuntimeError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
