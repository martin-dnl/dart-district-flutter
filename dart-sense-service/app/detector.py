from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List

from ultralytics import YOLO


class Detector:
    def __init__(
        self,
        model_path: str | None = None,
        conf_threshold: float = 0.25,
        iou_threshold: float = 0.45,
        max_det: int = 12,
        device: str | None = None,
    ) -> None:
        self.model_path = model_path
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.max_det = max_det
        self.device = device
        self.model: YOLO | None = None
        self.model_error: str | None = None

        if not self.model_path:
            self.model_error = "MODEL_PATH is not configured"
            return

        model_file = Path(self.model_path)
        if not model_file.exists():
            self.model_error = f"Model file not found at {model_file}"
            return

        try:
            self.model = YOLO(str(model_file))
        except Exception as exc:  # pragma: no cover - runtime env specific
            self.model_error = f"Unable to load model: {exc}"

    @property
    def is_ready(self) -> bool:
        return self.model is not None and self.model_error is None

    def detect(self, image_path: Path) -> List[Dict[str, Any]]:
        if not self.is_ready or self.model is None:
            error = self.model_error or "Model is not ready"
            raise RuntimeError(error)

        results = self.model.predict(
            source=str(image_path),
            conf=self.conf_threshold,
            iou=self.iou_threshold,
            max_det=self.max_det,
            device=self.device,
            verbose=False,
        )
        if not results:
            return []

        result = results[0]
        boxes = result.boxes
        if boxes is None or boxes.cls is None:
            return []

        names: Dict[int, str] = result.names if isinstance(result.names, dict) else {}
        height, width = result.orig_shape
        detected: List[Dict[str, Any]] = []

        for index in range(len(boxes)):
            cls_idx = int(boxes.cls[index].item())
            label = str(names.get(cls_idx, cls_idx)).strip()
            parsed = self._parse_label(label)
            if parsed is None:
                continue

            xyxy = boxes.xyxy[index].tolist()
            x1, y1, x2, y2 = (float(v) for v in xyxy)
            center_x = (x1 + x2) / 2.0
            center_y = (y1 + y2) / 2.0
            confidence = float(boxes.conf[index].item()) if boxes.conf is not None else 0.0

            detected.append(
                {
                    "zone": parsed["zone"],
                    "multiplier": parsed["multiplier"],
                    "confidence": confidence,
                    "x": max(0.0, min(1.0, center_x / float(width))),
                    "y": max(0.0, min(1.0, center_y / float(height))),
                    "label": parsed["label"],
                    "bbox": {
                        "x1": max(0.0, min(1.0, x1 / float(width))),
                        "y1": max(0.0, min(1.0, y1 / float(height))),
                        "x2": max(0.0, min(1.0, x2 / float(width))),
                        "y2": max(0.0, min(1.0, y2 / float(height))),
                    },
                }
            )

        detected.sort(key=lambda d: d["confidence"], reverse=True)
        return detected

    def _parse_label(self, raw_label: str) -> Dict[str, Any] | None:
        label = raw_label.strip().lower()

        if label in {"miss", "outside", "out"}:
            return None

        if label in {"db", "doublebull", "double_bull", "innerbull", "inner_bull", "bullseye"}:
            return {"zone": 25, "multiplier": 2, "label": "DB"}

        if label in {"sb", "singlebull", "single_bull", "outerbull", "outer_bull", "bull"}:
            return {"zone": 25, "multiplier": 1, "label": "SB"}

        short_match = re.fullmatch(r"([sdt])\s*(20|1[0-9]|[1-9])", label)
        if short_match:
            prefix = short_match.group(1)
            zone = int(short_match.group(2))
            multiplier = {"s": 1, "d": 2, "t": 3}[prefix]
            return {
                "zone": zone,
                "multiplier": multiplier,
                "label": f"{prefix.upper()}{zone}",
            }

        long_match = re.fullmatch(
            r"(single|double|triple)\s*(20|1[0-9]|[1-9])",
            label,
        )
        if long_match:
            zone = int(long_match.group(2))
            mult_word = long_match.group(1)
            multiplier = {"single": 1, "double": 2, "triple": 3}[mult_word]
            prefix = {1: "S", 2: "D", 3: "T"}[multiplier]
            return {
                "zone": zone,
                "multiplier": multiplier,
                "label": f"{prefix}{zone}",
            }

        if re.fullmatch(r"20|1[0-9]|[1-9]", label):
            zone = int(label)
            return {
                "zone": zone,
                "multiplier": 1,
                "label": f"S{zone}",
            }

        return None
