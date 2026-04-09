from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List


class Detector:
    def __init__(self, model_path: str | None = None) -> None:
        self.model_path = model_path

    def detect(self, image_path: Path) -> List[Dict[str, Any]]:
        # Placeholder baseline: return empty list until model integration is wired.
        # Replace with YOLO inference and dartboard geometry mapping.
        _ = image_path
        return []
