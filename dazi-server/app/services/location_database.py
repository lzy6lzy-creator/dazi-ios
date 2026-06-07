from __future__ import annotations

import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
SHANGHAI_LOCATION_DATA = DATA_DIR / "shanghai_location_hierarchy.json"


@dataclass(frozen=True)
class LocationRecord:
    name: str
    kind: str
    city: str
    district: str | None
    region: str
    aliases: tuple[str, ...]


def normalize_location_key(text: str | None) -> str:
    value = str(text or "").strip().lower()
    value = re.sub(r"[\s,，。；;:：/\\|_()（）-]+", "", value)
    for suffix in ("新区", "市", "区", "县"):
        if value.endswith(suffix) and len(value) > len(suffix) + 1:
            value = value[: -len(suffix)]
    return value


def _unique_aliases(*groups: Iterable[str | None]) -> tuple[str, ...]:
    aliases: list[str] = []
    seen: set[str] = set()
    for group in groups:
        for alias in group:
            if not alias:
                continue
            key = normalize_location_key(alias)
            if not key or key in seen:
                continue
            aliases.append(alias)
            seen.add(key)
    return tuple(aliases)


@lru_cache(maxsize=1)
def load_location_records() -> tuple[LocationRecord, ...]:
    data = json.loads(SHANGHAI_LOCATION_DATA.read_text(encoding="utf-8"))
    records: list[LocationRecord] = []
    for city in data.get("cities", []):
        city_name = str(city["name"])
        region = str(city["region"])
        for district in city.get("districts", []):
            district_name = str(district["name"])
            district_aliases = _unique_aliases([district_name], district.get("aliases", []))
            records.append(
                LocationRecord(
                    name=district_name,
                    kind="district",
                    city=city_name,
                    district=district_name,
                    region=region,
                    aliases=district_aliases,
                )
            )
            for place in district.get("places", []):
                place_name = str(place["name"])
                place_aliases = _unique_aliases([place_name], place.get("aliases", []))
                records.append(
                    LocationRecord(
                        name=place_name,
                        kind=str(place.get("kind") or "neighborhood"),
                        city=city_name,
                        district=district_name,
                        region=region,
                        aliases=place_aliases,
                    )
                )
    return tuple(records)


@lru_cache(maxsize=1)
def _lookup_entries() -> tuple[tuple[str, LocationRecord], ...]:
    entries: list[tuple[str, LocationRecord]] = []
    for record in load_location_records():
        for alias in record.aliases:
            key = normalize_location_key(alias)
            if key:
                entries.append((key, record))
    return tuple(sorted(entries, key=lambda item: (-len(item[0]), item[0], item[1].name)))


def find_location_record(text: str | None, *, kinds: set[str] | None = None) -> LocationRecord | None:
    key = normalize_location_key(text)
    if not key:
        return None
    for alias_key, record in _lookup_entries():
        if kinds and record.kind not in kinds:
            continue
        if alias_key == key or alias_key in key:
            return record
    return None


def location_records_for_city(city_name: str) -> tuple[LocationRecord, ...]:
    return tuple(record for record in load_location_records() if record.city == city_name)
