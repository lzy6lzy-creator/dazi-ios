from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any


def _load_shanghai_boundary_polygons() -> tuple[tuple[tuple[float, float], ...], ...]:
    boundary_path = Path(__file__).resolve().parents[1] / "data" / "shanghai_boundary.json"
    payload = json.loads(boundary_path.read_text(encoding="utf-8"))
    polygons: list[tuple[tuple[float, float], ...]] = []
    for feature in payload["features"]:
        geometry = feature["geometry"]
        coordinates = geometry["coordinates"]
        geometry_polygons = coordinates if geometry["type"] == "MultiPolygon" else [coordinates]
        for polygon in geometry_polygons:
            if not polygon:
                continue
            exterior_ring = tuple((float(point[0]), float(point[1])) for point in polygon[0])
            if len(exterior_ring) >= 3:
                polygons.append(exterior_ring)
    if not polygons:
        raise RuntimeError("Shanghai boundary data contains no polygons")
    return tuple(polygons)


# Complete district geometry, including Chongming and Shanghai's inhabited islands.
SHANGHAI_BOUNDARY_POLYGONS = _load_shanghai_boundary_polygons()


def available_balance(account: Any) -> int:
    return int(account.granted_total) - int(account.consumed_total) - int(account.reserved_total)


def is_admission_active(admission: Any, now: datetime) -> bool:
    return admission.status == "issued" and admission.expires_at > now


def is_location_current(verification: Any, now: datetime) -> bool:
    return bool(verification.is_launch_city) and verification.expires_at > now


def should_transition(qualified_user_count: int, qualified_target: int) -> bool:
    return qualified_user_count >= qualified_target


def point_in_shanghai(*, latitude: float, longitude: float) -> bool:
    """Return whether a point falls inside any Shanghai district polygon."""
    return any(
        _point_in_ring(latitude=latitude, longitude=longitude, ring=ring)
        for ring in SHANGHAI_BOUNDARY_POLYGONS
    )


def _point_in_ring(
    *,
    latitude: float,
    longitude: float,
    ring: tuple[tuple[float, float], ...],
) -> bool:
    inside = False
    previous = ring[-1]
    for current in ring:
        x1, y1 = previous
        x2, y2 = current
        crosses = (y1 > latitude) != (y2 > latitude)
        if crosses:
            boundary_x = (x2 - x1) * (latitude - y1) / (y2 - y1) + x1
            if longitude < boundary_x:
                inside = not inside
        previous = current
    return inside
