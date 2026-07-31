from __future__ import annotations

import re
from pathlib import Path
from typing import Optional


MAINLAND_PHONE_RE = re.compile(r"^1[3-9]\d{9}$")


def _normalize_phone(raw: object) -> Optional[str]:
    phone = str(raw or "").strip().replace(" ", "").replace("-", "")
    if phone.startswith("+86"):
        phone = phone[3:]
    elif phone.startswith("86") and len(phone) == 13:
        phone = phone[2:]
    return phone if MAINLAND_PHONE_RE.fullmatch(phone) else None


def _phone_values(raw: Optional[str]) -> set[str]:
    phones: set[str] = set()
    for item in (raw or "").split(","):
        phone = _normalize_phone(item)
        if phone:
            phones.add(phone)
    return phones


def _file_values(raw_path: Optional[str]) -> set[str]:
    if not raw_path:
        return set()
    path = Path(raw_path)
    candidates = [path]
    if not path.is_absolute():
        candidates.append(Path("/code/runtime-config") / path)
    for candidate in candidates:
        try:
            lines = candidate.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        phones: set[str] = set()
        for line in lines:
            phones.update(_phone_values(line.split("#", 1)[0]))
        return phones
    return set()


def is_internal_test_phone(
    *,
    phone: str,
    allowed_phones_csv: Optional[str],
    allowed_phones_file: Optional[str],
) -> bool:
    normalized = _normalize_phone(phone)
    if not normalized:
        return False
    allowed = _phone_values(allowed_phones_csv) | _file_values(allowed_phones_file)
    return normalized in allowed


def is_internal_test_code(
    *,
    phone: str,
    submitted_code: str,
    configured_code: Optional[str],
    allowed_phones_csv: Optional[str],
    allowed_phones_file: Optional[str],
) -> bool:
    return bool(configured_code) and submitted_code == configured_code and is_internal_test_phone(
        phone=phone,
        allowed_phones_csv=allowed_phones_csv,
        allowed_phones_file=allowed_phones_file,
    )
