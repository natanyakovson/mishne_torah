#!/usr/bin/env python3
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "Sources" / "MishnehTorahApp" / "Resources" / "seed_books.json"
ATTRIBUTION_PATH = ROOT / "TEXT_ATTRIBUTION.md"
CACHE_DIR = ROOT / "Tools" / ".m770_cache"
BASE_URL = "https://m770.org"
INDEX_URL = "https://m770.org/maimonid.php?from_moshiach_ru=1&book=5&num=10"
USER_AGENT = "MishnehTorahPrototype/0.2"

BOOK_TITLES = {
    1: ("ספר המדע", "Книга Знания"),
    2: ("ספר אהבה", "Книга Любовь"),
    3: ("ספר זמנים", "Книга Времена"),
    4: ("ספר נשים", "Книга Женщины"),
    5: ("ספר קדושה", "Книга Святость"),
    6: ("ספר הפלאה", "Книга Изречения"),
    7: ("ספר זרעים", "Книга Посевы"),
    8: ("ספר עבודה", "Книга Служение"),
    9: ("ספר קרבנות", "Книга Жертвоприношения"),
    10: ("ספר טהרה", "Книга Чистота"),
    11: ("ספר נזיקין", "Книга Ущербы"),
    12: ("ספר קניין", "Книга Приобретение"),
    13: ("ספר משפטים", "Книга Законы"),
    14: ("ספר שופטים", "Книга Судьи"),
}


def get_text(url):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_key = re.sub(r"[^A-Za-z0-9._-]+", "_", url)
    cache_path = CACHE_DIR / f"{cache_key}.html"
    if cache_path.exists():
        return cache_path.read_text(encoding="utf-8")

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                text = response.read().decode("utf-8", "replace")
            cache_path.write_text(text, encoding="utf-8")
            return text
        except Exception as error:
            last_error = error
            time.sleep(1.5 * (attempt + 1))
    raise last_error


def clean_text(value):
    value = re.sub(r"<br\s*/?>", "\n", value or "", flags=re.I)
    value = re.sub(r"</p\s*>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    value = value.replace("\xa0", " ")
    value = re.sub(r"[ \t\r\f\v]+", " ", value)
    value = re.sub(r"\n\s*", "\n", value)
    return value.strip()


def strip_russian_number(value):
    return re.sub(r"^\s*\d+[.)]?\s*", "", value).strip()


def normalize_book_title(order, raw_title):
    hebrew, russian = BOOK_TITLES.get(order, ("", clean_text(raw_title)))
    return hebrew, russian


class RambamIndexParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_rambam_book = False
        self.depth = 0
        self.current_tag = None
        self.current_attrs = {}
        self.current_text = []
        self.current_href = None
        self.events = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "div" and attrs.get("id") == "rambamBoook":
            self.in_rambam_book = True
            self.depth = 1
            return
        if not self.in_rambam_book:
            return
        if tag == "div":
            self.depth += 1
        if tag in {"h2", "h3", "a"}:
            self.current_tag = tag
            self.current_attrs = attrs
            self.current_text = []
            self.current_href = attrs.get("href")

    def handle_endtag(self, tag):
        if not self.in_rambam_book:
            return
        if tag == self.current_tag:
            text = clean_text("".join(self.current_text))
            if tag in {"h2", "h3"} and text:
                self.events.append((tag, text, None))
            elif tag == "a" and self.current_href and re.fullmatch(r"/rambam/\d+", self.current_href):
                self.events.append(("a", text, self.current_href))
            self.current_tag = None
            self.current_attrs = {}
            self.current_text = []
            self.current_href = None
        if tag == "div":
            self.depth -= 1
            if self.depth <= 0:
                self.in_rambam_book = False

    def handle_data(self, data):
        if self.in_rambam_book and self.current_tag:
            self.current_text.append(data)


def parse_index():
    parser = RambamIndexParser()
    parser.feed(get_text(INDEX_URL))

    books = []
    current_book = None
    current_section = None

    for tag, text, href in parser.events:
        if tag == "h2":
            order = len(books) + 1
            if order > 14:
                break
            title_hebrew, title_russian = normalize_book_title(order, text)
            current_book = {
                "order": order,
                "titleHebrew": title_hebrew,
                "titleRussian": title_russian,
                "sourceTitle": text,
                "sections": [],
            }
            books.append(current_book)
            current_section = None
        elif tag == "h3" and current_book is not None:
            current_section = {
                "order": len(current_book["sections"]) + 1,
                "titleHebrew": "",
                "titleRussian": text,
                "chapters": [],
            }
            current_book["sections"].append(current_section)
        elif tag == "a" and current_section is not None and text.isdigit():
            current_section["chapters"].append({
                "number": int(text),
                "m770Id": int(href.rsplit("/", 1)[1]),
                "m770Url": urllib.parse.urljoin(BASE_URL, href),
                "halakhot": [],
            })

    return books


def parse_chapter(url):
    page = get_text(url)
    table_match = re.search(
        r"<table\s+class\s*=\s*[\"']?rambam[\"']?\s*>(.*?)</table>",
        page,
        flags=re.S | re.I,
    )
    if table_match is None:
        return []

    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", table_match.group(1), flags=re.S | re.I)
    halakhot = []
    for row in rows:
        rus_match = re.search(
            r"<td\s+class\s*=\s*[\"']?rus[\"']?[^>]*>(.*?)</td>",
            row,
            flags=re.S | re.I,
        )
        heb_match = re.search(
            r"<td\s+class\s*=\s*[\"']?heb[\"']?[^>]*>(.*?)</td>",
            row,
            flags=re.S | re.I,
        )
        if rus_match is None and heb_match is None:
            continue

        russian = strip_russian_number(clean_text(rus_match.group(1) if rus_match else ""))
        hebrew = clean_text(heb_match.group(1) if heb_match else "")
        if not russian and not hebrew:
            continue

        halakhot.append({
            "number": len(halakhot) + 1,
            "hebrewText": hebrew,
            "russianText": russian,
        })
    return halakhot


def main():
    books = parse_index()
    if len(books) != 14:
        raise RuntimeError(f"Expected 14 books, found {len(books)}")

    for book in books:
        print(f"{book['order']}. {book['titleRussian']}", file=sys.stderr)
        for section in book["sections"]:
            print(f"   {section['order']}. {section['titleRussian']}", file=sys.stderr)
            for chapter in section["chapters"]:
                chapter["halakhot"] = parse_chapter(chapter["m770Url"])
                time.sleep(0.04)

    SEED_PATH.write_text(json.dumps(books, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ATTRIBUTION_PATH.write_text(
        "# Text Attribution\n\n"
        "Russian and Hebrew Mishneh Torah text in this prototype was downloaded from m770.org after the user stated that permission was granted for use in this application.\n\n"
        "Source index: https://m770.org/maimonid.php\n\n"
        "The application should keep visible attribution to m770.org before distribution.\n",
        encoding="utf-8",
    )

    section_count = sum(len(book["sections"]) for book in books)
    chapter_count = sum(len(section["chapters"]) for book in books for section in book["sections"])
    halakhah_count = sum(
        len(chapter["halakhot"])
        for book in books
        for section in book["sections"]
        for chapter in section["chapters"]
    )
    print(f"Wrote {SEED_PATH}", file=sys.stderr)
    print(f"Books: {len(books)}; sections: {section_count}; chapters: {chapter_count}; halakhot: {halakhah_count}", file=sys.stderr)


if __name__ == "__main__":
    main()
