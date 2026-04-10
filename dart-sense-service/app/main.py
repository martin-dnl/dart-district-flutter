from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, HTTPException, Query, UploadFile

from .detector import Detector
from .scorer import to_response_dart

app = FastAPI(title="Dart Sense Service", version="0.1.0")
detector = Detector(
    model_path=os.getenv("MODEL_PATH"),
    conf_threshold=float(os.getenv("DART_SENSE_CONF", "0.25")),
    iou_threshold=float(os.getenv("DART_SENSE_IOU", "0.45")),
    max_det=int(os.getenv("DART_SENSE_MAX_DET", "12")),
    device=os.getenv("DART_SENSE_DEVICE") or None,
)


def _save_upload_to_temp(image: UploadFile) -> Path:
    suffix = Path(image.filename or "capture.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = image.file.read()
        tmp.write(content)
        return Path(tmp.name)


def _detect_from_upload(image: UploadFile) -> list[dict[str, Any]]:
    temp_path = _save_upload_to_temp(image)
    try:
        return detector.detect(temp_path)
    finally:
        temp_path.unlink(missing_ok=True)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "success": True,
        "model_path": detector.model_path,
        "ready": detector.is_ready,
        "error": detector.model_error,
    }


@app.post("/detect")
async def detect(image: UploadFile = File(...)) -> dict[str, object]:
    if not detector.is_ready:
        raise HTTPException(status_code=503, detail=detector.model_error or "Model is not ready")

    content = await image.read()
    image.file.seek(0)
    if not content:
        raise HTTPException(status_code=400, detail="Empty image payload")

    darts = _detect_from_upload(image)
    return {
        "success": True,
        "data": {
            "darts": [to_response_dart(d) for d in darts],
        },
    }


@app.post("/detect/batch")
async def detect_batch(
    images: list[UploadFile] = File(...),
    min_occurrences: int = Query(2, ge=1, le=10),
    max_frames: int = Query(24, ge=1, le=60),
) -> dict[str, object]:
    if not detector.is_ready:
        raise HTTPException(status_code=503, detail=detector.model_error or "Model is not ready")

    if not images:
        raise HTTPException(status_code=400, detail="No frames provided")

    sampled_images = images[:max_frames]
    frame_results: list[dict[str, object]] = []
    grouped: dict[tuple[int, int], list[dict[str, Any]]] = {}

    for frame_index, image in enumerate(sampled_images):
        content = await image.read()
        image.file.seek(0)
        if not content:
            frame_results.append({"frame_index": frame_index, "darts": []})
            continue

        raw_darts = _detect_from_upload(image)
        response_darts = [to_response_dart(d) for d in raw_darts]
        frame_results.append({"frame_index": frame_index, "darts": response_darts})

        for dart in response_darts:
            key = (dart["zone"], dart["multiplier"])
            grouped.setdefault(key, []).append(dart)

    stabilized: list[dict[str, Any]] = []
    for (zone, multiplier), values in grouped.items():
        if len(values) < min_occurrences:
            continue

        stabilized.append(
            {
                "zone": zone,
                "multiplier": multiplier,
                "confidence": sum(v["confidence"] for v in values) / len(values),
                "x": sum(v["x"] for v in values) / len(values),
                "y": sum(v["y"] for v in values) / len(values),
                "occurrences": len(values),
            }
        )

    stabilized.sort(
        key=lambda d: (d["occurrences"], d["confidence"]),
        reverse=True,
    )

    return {
        "success": True,
        "data": {
            "frames": frame_results,
            "darts": stabilized,
            "frames_processed": len(sampled_images),
            "min_occurrences": min_occurrences,
        },
    }
