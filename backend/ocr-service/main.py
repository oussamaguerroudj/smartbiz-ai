"""
MODIRI AI — OCR microservice (Ch. 10, 25).

Wraps PaddleOCR (Apache 2.0, open-source) behind a tiny HTTP API so the
Node.js backend can call it over plain HTTP instead of needing a Python
runtime embedded in the main app. Chosen over Tesseract (weaker
accuracy on real-world receipts/mixed fonts) and EasyOCR (weaker
Arabic-script support) because PaddleOCR has strong, actively
maintained multilingual support — including Arabic — and is built
specifically for this kind of real-world document/receipt text
detection, matching Ch. 10's exact requirement list (Arabic, French,
English, numbers, dates, prices).

This service is OPTIONAL: ai.service.js's runOcr() degrades gracefully
(falls back to vision-only extraction) if this isn't running or
OCR_SERVICE_URL isn't set — see backend/AI_MIGRATION.md.

Run locally:
    pip install -r requirements.txt
    uvicorn main:app --host 0.0.0.0 --port 8001

Then set OCR_SERVICE_URL=http://localhost:8001 in backend/.env.
"""

import base64
import io

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="MODIRI AI - OCR Service")

# Loaded once at startup, reused across requests — PaddleOCR's model
# load is the expensive part; do it exactly once per process.
_ocr_engine = None


def get_engine():
    global _ocr_engine
    if _ocr_engine is None:
        from paddleocr import PaddleOCR

        # lang='ar' loads PaddleOCR's Arabic-script recognition model,
        # which also handles the Latin-script numbers/prices/dates that
        # appear mixed into Algerian invoices. `use_angle_cls=True`
        # corrects for a photo taken at a slight rotation, common with
        # a phone camera.
        _ocr_engine = PaddleOCR(use_angle_cls=True, lang="ar", show_log=False)
    return _ocr_engine


class OcrRequest(BaseModel):
    imageBase64: str
    mimeType: str | None = None


class OcrResponse(BaseModel):
    text: str
    lineCount: int


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ocr", response_model=OcrResponse)
def run_ocr(payload: OcrRequest):
    if not payload.imageBase64:
        raise HTTPException(status_code=400, detail="imageBase64 is required")

    try:
        image_bytes = base64.b64decode(payload.imageBase64)
    except Exception as exc:  # noqa: BLE001 - surfaced as a clean 400
        raise HTTPException(status_code=400, detail=f"Invalid base64 image: {exc}") from exc

    try:
        import numpy as np
        from PIL import Image

        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_array = np.array(image)

        engine = get_engine()
        result = engine.ocr(image_array, cls=True)
    except Exception as exc:  # noqa: BLE001
        # Ch. 21 error handling: OCR failure should never take down
        # invoice scanning — the Node backend treats any non-2xx here
        # as "no OCR text available" and continues with vision-only
        # extraction.
        raise HTTPException(status_code=500, detail=f"OCR failed: {exc}") from exc

    lines = []
    for page in result or []:
        for line in page or []:
            # PaddleOCR line shape: [box_points, (text, confidence)]
            text = line[1][0] if len(line) > 1 and len(line[1]) > 0 else None
            if text:
                lines.append(text)

    return OcrResponse(text="\n".join(lines), lineCount=len(lines))
