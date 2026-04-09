from __future__ import annotations

from typing import Dict, Any


def to_response_dart(raw: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "zone": int(raw.get("zone", 0)),
        "multiplier": int(raw.get("multiplier", 1)),
        "confidence": float(raw.get("confidence", 0.0)),
        "x": float(raw.get("x", 0.0)),
        "y": float(raw.get("y", 0.0)),
    }
