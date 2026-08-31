import json
import os
from pathlib import Path
import sys
from typing import List
from urllib.parse import unquote, urlsplit


def verify_media(root: Path, urls: List[str]) -> int:
    checked = 0
    for url in urls:
        parsed = urlsplit(url)
        if parsed.netloc and parsed.netloc not in {"idabuda.com", "www.idabuda.com"}:
            continue
        path = parsed.path
        if path.startswith("/media/avatars/"):
            folder = "avatars"
        elif path.startswith("/api/v1/gallery/media/"):
            folder = "gallery"
        else:
            continue
        filename = unquote(path.rsplit("/", 1)[-1])
        if Path(filename).name != filename or "\\" in filename:
            raise ValueError("Backup contains an unsafe media filename")
        target = (root / folder / filename).resolve()
        if os.path.commonpath((str(target), str(root.resolve()))) != str(root.resolve()) or not target.is_file():
            raise ValueError("Backup contains a missing or unsafe media reference")
        checked += 1
    return checked


if __name__ == "__main__":
    count = verify_media(Path(sys.argv[1]), json.load(sys.stdin))
    print(f"[ok] restored media references: {count}")
