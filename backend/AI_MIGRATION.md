# MODIRI AI — OpenAI → Open-Source Qwen Migration Report

Status: **Phases 1-9 implemented and reviewed; Phase 10-11 partially
automated (see Test Plan below); nothing here has been run against a
live model server** — I have no network/GPU access in this environment,
so every change below is verified by static review and syntax checks
(`node -c` on every `.js` file, `py_compile` on the OCR service), not by
actually calling a running Qwen server. Please run the Test Plan for
real before relying on this in production.

---

## 1. What changed, in one sentence

The AI module (`backend/src/modules/ai/`) now talks to a **self-hosted,
open-source Qwen model server** instead of OpenAI's cloud API. Nothing
outside that module changed — same endpoints (`/ai/invoices/scan`,
`/ai/chat`, `/ai/insights`, now also `/ai/logs/:id/feedback`), same
request/response shapes, same Flutter screens, same UI, same database
tables (plus one small additive migration for feedback columns).

## 2. OpenAI dependency audit (Phase 2)

Before this migration, exactly one file called OpenAI's API:
`ai.service.js`, via the `openai` npm package configured with no
`baseURL` override (so it defaulted to `https://api.openai.com`) and a
real `OPENAI_API_KEY`. Three call sites: invoice-scan vision extraction,
chat completion, and insight narration — all using `gpt-4o-mini`.

No other file, and no Flutter code, ever referenced OpenAI directly —
the mobile app only ever talks to `/ai/*` on our own backend. This is
exactly the "Flutter UI → AI Service Layer → Backend/Gateway → model"
architecture Ch. 4 asks for; it already existed, so no Flutter changes
were needed for this migration (Ch. 3 preserved as a side effect, not
a special effort).

## 3. Model selection (Phase 5, Ch. 5/24)

| Purpose | Model | Why |
|---|---|---|
| Vision + invoice extraction | **Qwen2.5-VL-7B-Instruct** | Current Qwen vision-language generation (chosen over the older Qwen-VL / Qwen2-VL lines) — materially better structured document/receipt extraction. 7B realistically self-hosts on one consumer/prosumer GPU (~16GB VRAM at 8-bit, less with 4-bit quantization); the 72B sibling is documented as a drop-in upgrade (`AI_VISION_MODEL=Qwen2.5-VL-72B-Instruct`) if you have the hardware. |
| Chat / insights (text-only) | **Qwen2.5-7B-Instruct** | Same generation, text-only sibling, so the heavier vision model is only ever loaded/invoked for image requests. Strong Arabic/French/English multilingual quality and instruction-following for its size; a **14B or 32B variant is a reasonable upgrade** for noticeably better Arabic/Darija fluency if hardware allows — both are drop-in via `AI_CHAT_MODEL`. |
| OCR (auxiliary) | **PaddleOCR (PP-OCR, Apache 2.0)** | Chosen over Tesseract (weaker on real-world receipts/mixed fonts) and EasyOCR (weaker Arabic-script support). PaddleOCR is actively maintained and specifically strong at exactly Ch. 10's requirement list: Arabic + French + English + numbers/dates/prices on real photographed documents. |

**Licensing**: Qwen2.5 models are released under Apache 2.0 (the
smaller sizes) — free for commercial use, no royalties. PaddleOCR is
Apache 2.0. Nothing in this stack requires a paid license.

**Darija honesty (Ch. 5, 19)**: no claim is made that any model
perfectly understands Algerian Darija. `ai.prompts.js`'s `SYSTEM_PROMPT`
explicitly instructs the model to ask a short clarifying question
rather than guess when a Darija message is ambiguous, and the future
dataset pipeline (Ch. 27, §8 below) is exactly how this should keep
improving over time — via real user feedback, not a one-time prompt
tweak.

## 4. Serving stack (how to actually run Qwen)

Any **OpenAI-API-compatible** server works, because `ai.service.js`
just points the existing `openai` npm package's `baseURL` at it — the
package is reused purely as a generic HTTP client for that API shape,
never talking to openai.com. Two practical options:

### Option A — vLLM (recommended for anything beyond local dev)
```bash
pip install vllm
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-VL-7B-Instruct \
  --port 8000
```
Run a second instance (different port) for the text-only chat model, or
serve both from one vLLM instance if your GPU has room — either way,
point `AI_BASE_URL` at whichever one instance you want the majority of
traffic to reach (simplest: run one vLLM instance with the vision model,
since it can also handle text-only chat requests fine — see §6).

### Option B — Ollama (easiest local/dev setup)
```bash
ollama pull qwen2.5vl:7b
ollama pull qwen2.5:7b
ollama serve   # exposes an OpenAI-compatible API at :11434/v1
```
Set `AI_BASE_URL=http://localhost:11434/v1`, `AI_VISION_MODEL=qwen2.5vl:7b`,
`AI_CHAT_MODEL=qwen2.5:7b` (Ollama's exact tag names — check `ollama list`).

### OCR microservice (optional)
```bash
cd backend/ocr-service
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001
```
Set `OCR_SERVICE_URL=http://localhost:8001`. Leave blank to skip OCR
entirely — invoice scanning still works from the vision model alone
(`ai.service.js`'s `runOcr()` degrades gracefully, see Ch. 21).

> ⚠️ I could not install or run any of the above here (no GPU, no
> network). These commands are documented from the current, standard
> way to serve each project — please verify exact flags/tags against
> vLLM's/Ollama's own docs at setup time, since CLI details do shift
> between releases.

## 5. New AI abstraction (Phase 3, Ch. 4/18)

- **`ai.prompts.js`** — every system prompt in one place (`SYSTEM_PROMPT`,
  `INVOICE_EXTRACTION_PROMPT`, `INSIGHT_NARRATION_PROMPT`). Nothing
  scattered in Flutter or inline in service functions (Ch. 18).
- **`ai.tools.js`** — the tool/function-calling system (Ch. 8): 10
  narrow, specific tools (`get_sales_summary`, `calculate_profit`,
  `compare_periods`, etc.) instead of one generic "run any query"
  escape hatch. Every tool is a plain async function scoped by
  `companyId` — see §7 (Security) below.
- **`ai.service.js`** — orchestration only: rate limiting, ai_logs
  writes, the tool-calling loop for chat, JSON-repair for invoice scan/
  insights. Talks to the model exclusively through `getClient()`
  (config-driven `baseURL`) and to data exclusively through
  `ai.tools.js` — never raw SQL for anything the model sees.

## 6. Business intelligence (Phase 4, Ch. 6-8)

Every number the model narrates is computed **deterministically first**
by `ai.tools.js`, then handed to the model as already-final JSON. The
model's job is narration/explanation, never arithmetic — `insights()`
in `ai.service.js` calls `calculate_profit`, `get_top_products`,
`get_low_stock_products`, `get_unpaid_invoices`, and
`get_customers_with_debt` directly (deterministic), then asks
`INSIGHT_NARRATION_PROMPT` to turn that fixed JSON into short sentences.
`chat()` gives the model those same tools to call on demand, so a
free-form question like *"وشحال بعنا هذا الشهر؟"* triggers a real
`get_sales_summary` call rather than an invented number.

**Known gap**: the current database schema has no `purchases` /
supplier-transaction table (only a bare `suppliers` list — see
`004_create_suppliers.sql`). `get_suppliers()` can report supplier
names/phone numbers, but **cannot** answer "which supplier do we buy
most from" (Ch. 7's own example) because that data doesn't exist yet.
Documented here rather than fabricated — adding real purchase tracking
would be a separate, larger piece of work.

## 7. Security (Phase 8, Ch. 29) — READ THIS

This is the one guarantee that must hold or nothing else matters:
**a user can never get another company's data out of the AI.**

How it's enforced: `ai.controller.js` reads `companyId` **only** from
`req.user.companyId` (set by `authMiddleware` from the verified JWT —
never from the request body). That single value is threaded through
`ai.service.js` into every `executeTool(companyId, ...)` call in
`ai.tools.js`, where every SQL query binds it as `WHERE company_id = $1`.
The model's tool-call *arguments* (`period`, `limit`, `days`, etc.) are
the **only** thing the model ever influences — there is no code path
where a value the model outputs can become the `companyId` used in a
query.

`ai_tools_isolation.test.js` verifies this directly: it calls every
tool with a forged `companyId` hidden inside `args` and asserts (a) the
real, server-supplied companyId is what actually gets bound into SQL,
and (b) the forged one never appears anywhere in the query parameters —
run it (§8) rather than taking this description on faith.

## 8. Testing (Phase 10-11, Ch. 28-29)

Added: `package.json` now has a real `jest` devDependency and
`npm test` runs it (previously a no-op placeholder). Three new test
files:

- **`ai_tools_isolation.test.js`** — the Ch. 29 security test (§7).
- **`ai_service_json_parsing.test.js`** — Ch. 21 malformed-JSON /
  hallucination handling: `parseJsonLoose()` recovers JSON embedded in
  extra prose (open-source models are less strict than OpenAI about
  `response_format`) and returns `null` (not a throw) for genuinely
  unparseable text.
- **`ai_validators.test.js`** — input validation: empty/oversized
  requests, valid Arabic/Darija text passes through untouched.

Run them:
```bash
cd backend
npm install
npm test
```

### Full Ch. 28 scenario checklist

| # | Scenario | Status |
|---|---|---|
| 1 | General chatbot | 🔶 Manual — `POST /ai/chat {"message":"hello"}` against a running server |
| 2 | Arabic questions | 🔶 Manual — `POST /ai/chat {"message":"شحال بعنا اليوم؟"}` |
| 3 | Algerian Darija questions | 🔶 Manual — try a mixed Darija/French sentence; expect either a grounded answer or a clarifying question, never an invented number |
| 4 | French questions | 🔶 Manual |
| 5 | English questions | 🔶 Manual |
| 6 | Business insights | 🔶 Manual — `GET /ai/insights`; cross-check every number against the DB directly |
| 7 | Sales analysis | 🔶 Manual — ask "compare this month to last month" and verify `compare_periods` fires |
| 8 | Inventory analysis | 🔶 Manual — ask about low/slow-moving stock |
| 9 | Product recommendations | 🔶 Manual — no dedicated tool for this yet; the model can only reason from `get_top_products`/`get_slow_moving_products` output, not invent a recommendation from nowhere |
| 10 | Invoice OCR | 🔶 Manual — requires `OCR_SERVICE_URL` running; without it, confirm graceful fallback (see #15) |
| 11 | Invoice vision extraction | 🔶 Manual — `POST /ai/invoices/scan` with a real photo |
| 12 | Invalid invoice (blank/unrelated photo) | 🔶 Manual — expect `{"items": []}`, not an error, not invented items |
| 13 | Incorrect OCR | ✅ Automated (`ai_service_json_parsing.test.js` covers the JSON-repair path this depends on) + 🔶 Manual for the full vision+OCR-disagreement case |
| 14 | Database failures | 🔶 Manual — stop Postgres and confirm `/ai/*` returns a clean 500, not a stack trace to the client |
| 15 | Model/server failures | 🔶 Manual — stop the vLLM/Ollama server and confirm a clean `AI_REQUEST_FAILED` error, and that OCR-service-down degrades to vision-only (see `runOcr()`) |
| 16 | Authentication/security | ✅ Automated (`ai_tools_isolation.test.js`) + 🔶 Manual: call `/ai/chat` with no/expired token, expect 401 |
| 17 | JSON parsing | ✅ Automated (`ai_service_json_parsing.test.js`) |
| 18 | User isolation | ✅ Automated (`ai_tools_isolation.test.js`) — this is the Ch. 29 test |

**Why so many are manual**: everything marked 🔶 needs an actual running
Qwen server (and for #10/13/14/15, a running OCR service and/or a
Postgres instance to deliberately break) — none of which exist in this
sandboxed environment. The automated tests cover everything that's
testable with pure logic and mocks; the rest is a checklist for you to
run once infrastructure is up.

## 9. Future dataset pipeline (Phase-adjacent, Ch. 26-27)

Migration `015_add_ai_logs_feedback.sql` adds `user_feedback` (enum:
`helpful` / `not_helpful` / `incorrect`) and `corrected_answer` (text)
to the existing `ai_logs` table, plus `POST /ai/logs/:id/feedback` to
submit them. Deliberately additive to the table that already exists
(not a new parallel table) — every `ai_logs` row already has
`company_id`, `type`, `input_ref`, and `result`, which alongside
feedback is exactly the shape Ch. 27 describes for a future
MODIRI-specific dataset. Nothing is collected automatically: both new
columns stay `NULL` until a user explicitly submits feedback, and
`input_ref` was already capped to short excerpts (~500 chars) before
this migration — no passwords, tokens, or payment data ever pass
through this path. **No fine-tuning has been attempted or is planned
by this change** — per Ch. 26, that's explicitly future work once a
real MODIRI dataset exists.

## 10. What did NOT change

- Every non-AI endpoint, table, and Flutter screen — untouched.
- The `ai_logs` table's original columns and the `confirmed`-only-
  after-review design principle — untouched, just extended.
- Response shapes of `/ai/invoices/scan`, `/ai/chat`, `/ai/insights` —
  identical to before the migration (the Flutter app needed zero
  changes).
- `package.json`'s `openai` dependency — **kept**, repurposed as a
  generic OpenAI-API-shape HTTP client pointed at your own server (see
  §4/§5) rather than removed and reimplemented from scratch, per
  Ch. 30's "avoid unnecessary dependencies".

## 11. Environment variables (new/changed)

See `.env.example` for the authoritative list. Summary:
`OPENAI_API_KEY`/`OPENAI_MODEL` are **removed**; replaced by
`AI_BASE_URL`, `AI_API_KEY`, `AI_VISION_MODEL`, `AI_CHAT_MODEL`,
`OCR_SERVICE_URL`.

## 12. Files touched

**Modified**: `env.js`, `ai.service.js`, `ai.controller.js`,
`ai.routes.js`, `ai.validators.js`, `package.json`, `.env`,
`.env.example`.
**New**: `ai.prompts.js`, `ai.tools.js`, `015_add_ai_logs_feedback.sql`,
`backend/ocr-service/main.py`, `backend/ocr-service/requirements.txt`,
`ai_tools_isolation.test.js`, `ai_service_json_parsing.test.js`,
`ai_validators.test.js`, this file.
