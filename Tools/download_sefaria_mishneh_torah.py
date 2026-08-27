#!/usr/bin/env python3
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "Sources" / "MishnehTorahApp" / "Resources" / "seed_books.json"
ATTRIBUTION_PATH = ROOT / "TEXT_ATTRIBUTION.md"
CACHE_DIR = ROOT / "Tools" / ".sefaria_cache"
TOC_URL = "https://www.sefaria.org/api/index/"
TEXT_URL = "https://www.sefaria.org/api/texts/{ref}?context=0&commentary=0"
VERSION_TEXT_URL = "https://www.sefaria.org/api/texts/{ref}/he/{version}?context=0&commentary=0"
VERSIONS_URL = "https://www.sefaria.org/api/texts/versions/{index}"
ALLOWED_LICENSES = {"Public Domain", "CC-BY-SA"}

BOOK_RUSSIAN = {
    "Sefer Madda": "Книга знания",
    "Sefer Ahavah": "Книга любви",
    "Sefer Zemanim": "Книга времён",
    "Sefer Nashim": "Книга женщин",
    "Sefer Kedushah": "Книга святости",
    "Sefer Haflaah": "Книга изречений",
    "Sefer Zeraim": "Книга Посевы",
    "Sefer Avodah": "Книга храмового служения",
    "Sefer Korbanot": "Книга жертвоприношений",
    "Sefer Taharah": "Книга чистоты",
    "Sefer Nezikim": "Книга ущербов",
    "Sefer Kinyan": "Книга приобретения",
    "Sefer Mishpatim": "Книга гражданских законов",
    "Sefer Shoftim": "Книга судей",
}

SECTION_RUSSIAN = {
    "Mishneh Torah, Foundations of the Torah": "Законы основ Торы",
    "Mishneh Torah, Human Dispositions": "Законы черт характера",
    "Mishneh Torah, Torah Study": "Законы изучения Торы",
    "Mishneh Torah, Foreign Worship and Customs of the Nations": "Законы идолопоклонства и обычаев народов",
    "Mishneh Torah, Repentance": "Законы раскаяния",
    "Mishneh Torah, Reading the Shema": "Законы чтения Шма",
    "Mishneh Torah, Prayer and the Priestly Blessing": "Законы молитвы и благословения коэнов",
    "Mishneh Torah, Tefillin, Mezuzah and the Torah Scroll": "Законы тфилин, мезузы и свитка Торы",
    "Mishneh Torah, Fringes": "Законы цицит",
    "Mishneh Torah, Blessings": "Законы благословений",
    "Mishneh Torah, Circumcision": "Законы обрезания",
    "Mishneh Torah, The Order of Prayer": "Порядок молитвы",
    "Mishneh Torah, Sabbath": "Законы Шаббата",
    "Mishneh Torah, Eruvin": "Законы эрувов",
    "Mishneh Torah, Rest on the Tenth of Tishrei": "Законы покоя десятого дня",
    "Mishneh Torah, Rest on a Holiday": "Законы покоя праздника",
    "Mishneh Torah, Leavened and Unleavened Bread": "Законы хамеца и мацы",
    "Mishneh Torah, Shofar, Sukkah and Lulav": "Законы шофара, сукки и лулава",
    "Mishneh Torah, Sheqel Dues": "Законы шекелей",
    "Mishneh Torah, Sanctification of the New Month": "Законы освящения месяца",
    "Mishneh Torah, Fasts": "Законы постов",
    "Mishneh Torah, Scroll of Esther and Hanukkah": "Законы свитка Эстер и Хануки",
    "Mishneh Torah, Marriage": "Законы брака",
    "Mishneh Torah, Divorce": "Законы развода",
    "Mishneh Torah, Levirate Marriage and Release": "Законы левиратного брака и халицы",
    "Mishneh Torah, Virgin Maiden": "Законы девицы",
    "Mishneh Torah, Sotah": "Законы сота",
    "Mishneh Torah, Forbidden Intercourse": "Законы запрещённых связей",
    "Mishneh Torah, Forbidden Foods": "Законы запрещённой пищи",
    "Mishneh Torah, Ritual Slaughter": "Законы шхиты",
    "Mishneh Torah, Oaths": "Законы клятв",
    "Mishneh Torah, Vows": "Законы обетов",
    "Mishneh Torah, Nazariteship": "Законы назорейства",
    "Mishneh Torah, Appraisals and Devoted Property": "Законы оценок и посвящённого имущества",
    "Mishneh Torah, Diverse Species": "Законы смешанных видов",
    "Mishneh Torah, Gifts to the Poor": "Законы даров бедным",
    "Mishneh Torah, Heave Offerings": "Законы трумот",
    "Mishneh Torah, Tithes": "Законы десятин",
    "Mishneh Torah, Second Tithes and Fourth Year's Fruit": "Законы второй десятины и плодов четвёртого года",
    "Mishneh Torah, First Fruits and other Gifts to Priests Outside the Sanctuary": "Законы первинок и даров коэнам вне Храма",
    "Mishneh Torah, Sabbatical Year and the Jubilee": "Законы шмиты и юбилея",
    "Mishneh Torah, The Chosen Temple": "Законы избранного Храма",
    "Mishneh Torah, Vessels of the Sanctuary and Those Who Serve Therein": "Законы храмовых сосудов и служителей",
    "Mishneh Torah, Admission into the Sanctuary": "Законы входа в Храм",
    "Mishneh Torah, Things Forbidden on the Altar": "Законы запретного для жертвенника",
    "Mishneh Torah, Sacrificial Procedure": "Законы порядка жертвоприношений",
    "Mishneh Torah, Daily Offerings and Additional Offerings": "Законы постоянных и дополнительных жертв",
    "Mishneh Torah, Sacrifices Rendered Unfit": "Законы негодных посвящений",
    "Mishneh Torah, Service on the Day of Atonement": "Законы служения Йом-Кипура",
    "Mishneh Torah, Trespass": "Законы незаконного пользования святынями",
    "Mishneh Torah, Paschal Offering": "Законы пасхальной жертвы",
    "Mishneh Torah, Festival Offering": "Законы праздничной жертвы",
    "Mishneh Torah, Firstlings": "Законы первенцев",
    "Mishneh Torah, Offerings for Unintentional Transgressions": "Законы непреднамеренных нарушений",
    "Mishneh Torah, Those Lacking Atonement": "Законы нуждающихся в искуплении",
    "Mishneh Torah, Substitution": "Законы замещения",
    "Mishneh Torah, Defilement by a Corpse": "Законы нечистоты от мёртвого",
    "Mishneh Torah, Red Heifer": "Законы красной коровы",
    "Mishneh Torah, Defilement by Leprosy": "Законы нечистоты цараат",
    "Mishneh Torah, Those Who Defile Bed or Seat": "Законы оскверняющих ложе и сиденье",
    "Mishneh Torah, Other Sources of Defilement": "Законы прочих источников нечистоты",
    "Mishneh Torah, Defilement of Foods": "Законы нечистоты пищи",
    "Mishneh Torah, Vessels": "Законы сосудов",
    "Mishneh Torah, Immersion Pools": "Законы микв",
    "Mishneh Torah, Damages to Property": "Законы имущественного ущерба",
    "Mishneh Torah, Theft": "Законы кражи",
    "Mishneh Torah, Robbery and Lost Property": "Законы грабежа и потерянного",
    "Mishneh Torah, One Who Injures a Person or Property": "Законы телесного и имущественного вреда",
    "Mishneh Torah, Murderer and the Preservation of Life": "Законы убийцы и охраны жизни",
    "Mishneh Torah, Sales": "Законы продажи",
    "Mishneh Torah, Ownerless Property and Gifts": "Законы бесхозного имущества и даров",
    "Mishneh Torah, Neighbors": "Законы соседей",
    "Mishneh Torah, Agents and Partners": "Законы представителей и партнёров",
    "Mishneh Torah, Slaves": "Законы рабов",
    "Mishneh Torah, Hiring": "Законы найма",
    "Mishneh Torah, Borrowing and Deposit": "Законы займа вещей и хранения",
    "Mishneh Torah, Creditor and Debtor": "Законы кредитора и должника",
    "Mishneh Torah, Plaintiff and Defendant": "Законы истца и ответчика",
    "Mishneh Torah, Inheritances": "Законы наследования",
    "Mishneh Torah, The Sanhedrin and the Penalties within Their Jurisdiction": "Законы Сангедрина и переданных ему наказаний",
    "Mishneh Torah, Testimony": "Законы свидетельства",
    "Mishneh Torah, Rebels": "Законы непокорных",
    "Mishneh Torah, Mourning": "Законы траура",
    "Mishneh Torah, Kings and Wars": "Законы царей и войн",
}


def get_json(url):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_key = re.sub(r"[^A-Za-z0-9._-]+", "_", url)
    cache_path = CACHE_DIR / f"{cache_key}.json"
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))

    request = urllib.request.Request(url, headers={"User-Agent": "MishnehTorahPrototype/0.1"})
    last_error = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                data = json.load(response)
            cache_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            return data
        except Exception as error:
            last_error = error
            time.sleep(1.5 * (attempt + 1))
    raise last_error


def clean_text(value):
    value = re.sub(r"<[^>]+>", "", value or "")
    value = html.unescape(value)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def ref_path(ref):
    return urllib.parse.quote(ref.replace(" ", "_"), safe=",_")


def version_path(version):
    return urllib.parse.quote(version.replace(" ", "_"), safe="_")


def find_mishneh_torah(toc):
    for category in toc:
        if category.get("category") == "Halakhah":
            for item in category.get("contents", []):
                if item.get("category") == "Mishneh Torah":
                    return item
    raise RuntimeError("Mishneh Torah category not found in Sefaria TOC")


def download_section(section_title):
    first_url = TEXT_URL.format(ref=ref_path(section_title))
    first = get_json(first_url)
    source = {
        "versionTitle": first.get("heVersionTitle"),
        "license": first.get("heLicense"),
        "versionSource": first.get("heVersionSource"),
    }

    if source["license"] not in ALLOWED_LICENSES:
        versions = get_json(VERSIONS_URL.format(index=urllib.parse.quote(section_title, safe="")))
        source = next(
            (
                {
                    "versionTitle": version.get("versionTitle"),
                    "license": version.get("license"),
                    "versionSource": version.get("versionSource"),
                }
                for version in versions
                if version.get("language") == "he" and version.get("license") in ALLOWED_LICENSES
            ),
            None,
        )
        if source is None:
            raise RuntimeError(f"{section_title}: no reusable Hebrew version found")
        first = get_json(VERSION_TEXT_URL.format(ref=ref_path(section_title), version=version_path(source["versionTitle"])))

    chapter_count = first.get("lengths", [0])[0]
    chapters = []
    for chapter_number in range(1, chapter_count + 1):
        chapter_ref = f"{section_title}.{chapter_number}"
        if source["versionTitle"]:
            data = get_json(VERSION_TEXT_URL.format(ref=ref_path(chapter_ref), version=version_path(source["versionTitle"])))
        else:
            data = get_json(TEXT_URL.format(ref=ref_path(chapter_ref)))
        halakhot = [
            {
                "number": index + 1,
                "hebrewText": clean_text(text),
                "russianText": None,
            }
            for index, text in enumerate(data.get("he", []))
            if clean_text(text)
        ]
        chapters.append({"number": chapter_number, "halakhot": halakhot})
        time.sleep(0.03)
    return chapters, source


def main():
    toc = get_json(TOC_URL)
    mishneh_torah = find_mishneh_torah(toc)

    books = []
    attributions = {}
    source_books = [
        item for item in mishneh_torah.get("contents", [])
        if item.get("category") in BOOK_RUSSIAN
    ]

    for book_order, book_node in enumerate(source_books, start=1):
        book_title = book_node["category"]
        print(f"{book_order}. {book_title}", file=sys.stderr)
        sections = []

        for section_order, section_node in enumerate(book_node.get("contents", []), start=1):
            section_title = section_node["title"]
            print(f"   {section_order}. {section_title}", file=sys.stderr)
            chapters, source = download_section(section_title)
            key = (source["versionTitle"], source["license"], source["versionSource"])
            attributions[key] = attributions.get(key, 0) + 1

            sections.append({
                "order": section_order,
                "titleHebrew": section_node.get("heTitle", ""),
                "titleRussian": SECTION_RUSSIAN.get(section_title, section_title),
                "sefariaTitle": section_title,
                "sourceVersion": source["versionTitle"],
                "sourceLicense": source["license"],
                "sourceUrl": source["versionSource"],
                "chapters": chapters,
            })

        books.append({
            "order": book_order,
            "titleHebrew": book_node.get("heCategory", ""),
            "titleRussian": BOOK_RUSSIAN[book_title],
            "sefariaTitle": book_title,
            "sections": sections,
        })

    SEED_PATH.write_text(json.dumps(books, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    attribution_lines = [
        "# Text Attribution",
        "",
        "The bundled Hebrew Mishneh Torah text was downloaded from the Sefaria API.",
        "Only Hebrew versions marked by Sefaria as `Public Domain` or `CC-BY-SA` were included.",
        "Russian text fields are intentionally left empty unless a permitted Russian source is imported by the user.",
        "",
        "## Hebrew Sources",
        "",
    ]
    for (version_title, license_name, source_url), count in sorted(attributions.items()):
        attribution_lines.append(f"- {version_title} - {license_name} - {source_url} ({count} sections)")
    ATTRIBUTION_PATH.write_text("\n".join(attribution_lines) + "\n", encoding="utf-8")

    chapter_count = sum(len(section["chapters"]) for book in books for section in book["sections"])
    halakhah_count = sum(
        len(chapter["halakhot"])
        for book in books
        for section in book["sections"]
        for chapter in section["chapters"]
    )
    print(f"Wrote {SEED_PATH}", file=sys.stderr)
    print(f"Books: {len(books)}; sections: {sum(len(b['sections']) for b in books)}; chapters: {chapter_count}; halakhot: {halakhah_count}", file=sys.stderr)


if __name__ == "__main__":
    main()
