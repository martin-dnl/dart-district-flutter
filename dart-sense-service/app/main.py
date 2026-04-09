from __future__ import annotations

import os
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, UploadFile

from .detector import Detector
from .scorer import to_response_dart

app = FastAPI(title="Dart Sense Service", version="0.1.0")
detector = Detector(model_path=os.getenv("MODEL_PATH"))


@app.get("/health")
def health() -> dict[str, object]:
    return {"success": True, "model_path": detector.model_path}


@app.post("/detect")
async def detect(image: UploadFile = File(...)) -> dict[str, object]:
    suffix = Path(image.filename or "capture.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await image.read()
        tmp.write(content)
        temp_path = Path(tmp.name)

    try:
        darts = detector.detect(temp_path)
        return {
            "success": True,
            "data": {
                "darts": [to_response_dart(d) for d in darts],
            },
        }
    finally:
        temp_path.unlink(missing_ok=True)
