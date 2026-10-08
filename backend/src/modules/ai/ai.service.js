const OpenAI = require('openai');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');
const { query } = require('../../config/db');
const {
  SYSTEM_PROMPT,
  buildSystemPrompt,
  INVOICE_EXTRACTION_PROMPT,
  OCR_EXTRACTION_PROMPT,
  INSIGHT_NARRATION_PROMPT,
} = require('./ai.prompts');
const { TOOL_DEFINITIONS, executeTool } = require('./ai.tools');
const { detectLanguage } = require('./language.detector');
const {
  detectPreIntent,
  validateAndGroundResponse,
  formatDeterministicResponse,
} = require('./grounding.validator');
const { parseInvoiceText } = require('./invoice.parser');

/**
 * AI module  -  migrated off OpenAI's cloud API onto a self-hosted,
 * open-source Qwen stack (Ch. 25: ZERO OpenAI dependency). See
 * backend/AI_MIGRATION.md for the full migration report, model
 * choices, and setup instructions.
 *
 * The `openai` npm package is still used here  -  but only as a generic
 * HTTP client for the OpenAI-*API-shape*, pointed at env.ai.baseUrl
 * (your own vLLM/Ollama server via config/env.js). No request from
 * this file ever reaches openai.com; no OpenAI account or billing is
 * involved. This is the standard way to consume self-hosted LLMs
 * without hand-rolling a new HTTP client (Ch. 30: avoid unnecessary
 * dependencies).
 *
 * Design principle carried over unchanged from before the migration:
 * the AI layer never writes directly to products/sales/customers.
 * Every AI call here is read-only from the business's point of view  - 
 * invoice scanning returns extracted items for the client to review
 * and submit through the normal, already-validated /products or
 * /sales endpoints; chat/insights only ever read data via ai.tools.js.
 */

let runtimeAiConfig = {
  enabled: env.ai.enabled !== false,
  baseUrl: env.ai.baseUrl,
  ocrModel: env.ai.ocrModel,
  visionModel: env.ai.visionModel,
  chatModel: env.ai.chatModel,
};

let cachedClient = null;

function getAiConfig() {
  return { ...runtimeAiConfig };
}

function isAllowedAiBaseUrl(rawUrl) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return false;
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    return false;
  }

  // Reject userinfo tricks (e.g. http://user:pass@localhost:11434) and query/hash fragments
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    return false;
  }

  const host = parsed.hostname.toLowerCase();

  // Never allow cloud metadata or link-local SSRF targets
  if (
    host === '169.254.169.254' ||
    host.startsWith('169.254.') ||
    host === 'metadata.google.internal' ||
    host === '0.0.0.0'
  ) {
    return false;
  }

  // Allow configured env host/port or local inference hosts on AI inference ports only
  let configuredHost = 'localhost';
  let configuredPort = '11434';
  try {
    const envUrl = new URL(env.ai.baseUrl);
    configuredHost = envUrl.hostname.toLowerCase();
    if (envUrl.port) {
      configuredPort = envUrl.port;
    }
  } catch (_) {}

  const allowedHosts = new Set([
    configuredHost,
    'localhost',
    '127.0.0.1',
    '::1',
    '[::1]',
    'host.docker.internal',
    'ollama',
    'vllm',
  ]);

  if (!allowedHosts.has(host)) {
    return false;
  }

  const allowedPorts = new Set([configuredPort, '11434', '8000']);
  const effectivePort = parsed.port || (parsed.protocol === 'https:' ? '443' : '80');
  if (!allowedPorts.has(effectivePort)) {
    return false;
  }

  return true;
}

function updateRuntimeAiConfig(updates = {}) {
  if (typeof updates.enabled === 'boolean') {
    runtimeAiConfig.enabled = updates.enabled;
  }
  if (typeof updates.baseUrl === 'string' && updates.baseUrl.trim().length > 0) {
    const candidate = updates.baseUrl.trim();
    if (!isAllowedAiBaseUrl(candidate)) {
      throw ApiError.badRequest(
        'Invalid or disallowed AI baseUrl host',
        'INVALID_AI_BASE_URL',
      );
    }
    runtimeAiConfig.baseUrl = candidate;
    cachedClient = null;
  }
  if (typeof updates.ocrModel === 'string' && updates.ocrModel.trim().length <= 120) {
    runtimeAiConfig.ocrModel = updates.ocrModel.trim();
  }
  if (typeof updates.visionModel === 'string' && updates.visionModel.trim().length <= 120) {
    runtimeAiConfig.visionModel = updates.visionModel.trim();
  }
  if (typeof updates.chatModel === 'string' && updates.chatModel.trim().length <= 120) {
    runtimeAiConfig.chatModel = updates.chatModel.trim();
  }
  return { ...runtimeAiConfig };
}

function getClient() {
  if (!cachedClient) {
    cachedClient = new OpenAI({ baseURL: runtimeAiConfig.baseUrl || env.ai.baseUrl, apiKey: env.ai.apiKey });
  }
  return cachedClient;
}

// Generous but bounded  -  protects the self-hosted server (and its GPU
// queue) from a runaway client bug or a compromised token, without
// getting in the way of any real, legitimate usage pattern for a small
// business.
const MAX_DAILY_AI_REQUESTS_PER_COMPANY = 200;

async function checkRateLimit(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count
     FROM ai_logs
     WHERE company_id = $1
       AND created_at >= now() - interval '1 day'`,
    [companyId],
  );

  if (result.rows[0].count >= MAX_DAILY_AI_REQUESTS_PER_COMPANY) {
    throw ApiError.badRequest(
      'Daily AI usage limit reached for this company. Try again tomorrow.',
      'AI_RATE_LIMIT',
    );
  }
}

async function logAi({ companyId, userId, type, inputRef, result, confirmed = false }) {
  const inserted = await query(
    `INSERT INTO ai_logs (company_id, user_id, type, input_ref, result, confirmed)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [
      companyId,
      userId,
      type,
      inputRef ?? null,
      result !== undefined ? JSON.stringify(result) : null,
      confirmed,
    ],
  );

  return inserted.rows[0].id;
}

async function confirmAiLog(companyId, logId) {
  const result = await query(
    `UPDATE ai_logs
     SET confirmed = true
     WHERE id = $1
       AND company_id = $2
     RETURNING id`,
    [logId, companyId],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('AI log not found');
  }
}

/**
 * Records user feedback / a corrected answer against a previous AI
 * interaction (Ch. 26-27: future dataset pipeline). Purely additive  - 
 * writes to the SAME ai_logs row rather than a new parallel table,
 * avoiding duplicate infrastructure (Ch. 30). Never stores anything
 * beyond what the user explicitly submits here; no passwords, tokens,
 * or payment data ever pass through this path.
 */
async function submitFeedback(companyId, logId, { feedback, correctedAnswer }) {
  const result = await query(
    `UPDATE ai_logs
     SET user_feedback = $3,
         corrected_answer = $4
     WHERE id = $1 AND company_id = $2
     RETURNING id`,
    [logId, companyId, feedback ?? null, correctedAnswer ?? null],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('AI log not found');
  }
}

/**
 * Normalizes Ollama model tags by stripping the implicit ':latest' tag.
 * E.g.: 'glm-ocr' and 'glm-ocr:latest' -> 'glm-ocr'
 * Preserves specific explicit version/size tags:
 * E.g.: 'qwen2.5vl:7b' remains 'qwen2.5vl:7b'
 */
function normalizeOllamaModelName(name) {
  if (!name || typeof name !== 'string') return '';
  const trimmed = name.trim();
  if (trimmed.endsWith(':latest')) {
    return trimmed.slice(0, -7);
  }
  return trimmed;
}

function isModelAvailable(configuredModel, availableModels) {
  if (!configuredModel) return true;
  const norm = normalizeOllamaModelName(configuredModel);
  return (availableModels || []).some((m) => normalizeOllamaModelName(m) === norm);
}

/**
 * Fast failure preflight: verifies that the local Ollama server is reachable
 * within 5 seconds and that the required models are present.
 */
async function pingOllama(requiredModels = []) {
  const baseUrl = runtimeAiConfig.baseUrl || env.ai.baseUrl;
  const ollamaUrl = baseUrl.replace(/\/v1\/?$/, '');
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000);

  let res;
  try {
    res = await fetch(`${ollamaUrl}/api/tags`, { signal: controller.signal });
  } catch (err) {
    clearTimeout(timeoutId);
    throw ApiError.serviceUnavailable(
      `AI server is unreachable (${baseUrl}). Make sure Ollama is running with "ollama serve".`,
      'AI_NOT_CONFIGURED',
    );
  } finally {
    clearTimeout(timeoutId);
  }

  if (!res.ok) {
    throw ApiError.serviceUnavailable(
      `AI server is unreachable (${baseUrl}). Make sure Ollama is running with "ollama serve".`,
      'AI_NOT_CONFIGURED',
    );
  }

  let data;
  try {
    data = await res.json();
  } catch (err) {
    throw ApiError.serviceUnavailable(
      `Invalid response from AI server (${baseUrl}).`,
      'AI_NOT_CONFIGURED',
    );
  }

  const availableModels = (data.models || []).map((m) => m.name);
  const missingModels = requiredModels
    .filter(Boolean)
    .filter((modelName) => !isModelAvailable(modelName, availableModels));

  if (missingModels.length > 0) {
    throw ApiError.serviceUnavailable(
      `Required AI model(s) not found on the Ollama server: ${missingModels.join(', ')}. Run the required "ollama pull ..." command.`,
      'AI_NOT_CONFIGURED',
    );
  }

  return { availableModels, modelNames: availableModels };
}

/**
 * Best-effort call to the optional companion OCR microservice
 * (PaddleOCR  -  see backend/ocr-service/) or specialized fast Ollama OCR model (GLM-OCR).
 * Returns '' (not an error) if OCR fails  -  invoice scanning still
 * falls back gracefully to the vision model (Qwen2.5-VL).
 */
async function runOcr(imageBase64, mimeType = 'image/jpeg') {
  const safeMime = ['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)
    ? mimeType
    : 'image/jpeg';
  const cleanBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '').trim();

  // 1. Try external OCR microservice (PaddleOCR) if configured
  if (env.ai.ocrServiceUrl) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);

    try {
      const response = await fetch(`${env.ai.ocrServiceUrl}/ocr`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ imageBase64: cleanBase64, mimeType: safeMime }),
        signal: controller.signal,
      });

      if (response.ok) {
        const data = await response.json();
        if (typeof data?.text === 'string' && data.text.trim().length > 0) {
          return data.text.trim();
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[INVOICE_SCAN] OCR microservice unavailable:', err.message);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  // 2. Try specialized fast Ollama OCR model (GLM-OCR)
  const ocrModel = runtimeAiConfig.ocrModel !== undefined ? runtimeAiConfig.ocrModel : env.ai.ocrModel;
  const baseUrl = runtimeAiConfig.baseUrl || env.ai.baseUrl;
  if (ocrModel) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);
    const ollamaUrl = baseUrl.replace(/\/v1\/?$/, '');

    try {
      // eslint-disable-next-line no-console
      console.log(`[INVOICE_SCAN] Invoking GLM-OCR: ${ocrModel}`);
      const ocrStart = Date.now();
      const response = await fetch(`${ollamaUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: ocrModel,
          prompt: 'Text Recognition:',
          images: [cleanBase64],
          stream: false,
          options: {
            num_predict: 1024,
            temperature: 0.0,
            stop: ['\n```', '```', '<|endoftext|>', '<|user|>', '<|observation|>'],
          },
        }),
        signal: controller.signal,
      });

      if (response.ok) {
        const data = await response.json();
        if (typeof data?.response === 'string' && data.response.trim().length > 0) {
          let cleanText = data.response.trim();
          cleanText = cleanText.replace(/```[a-z]*\n?/gi, '').replace(/```/g, '').trim();
          // eslint-disable-next-line no-console
          console.log(`[INVOICE_SCAN] GLM-OCR responded in ${Date.now() - ocrStart}ms`);
          // eslint-disable-next-line no-console
          console.log(`[INVOICE_SCAN] OCR text length: ${cleanText.length}`);
          return cleanText;
        }
        // eslint-disable-next-line no-console
        console.warn('[INVOICE_SCAN] GLM-OCR returned empty text response');
      } else {
        const errText = await response.text().catch(() => '');
        // eslint-disable-next-line no-console
        console.warn(`[INVOICE_SCAN] GLM-OCR HTTP error ${response.status}: ${errText}`);
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn(`[INVOICE_SCAN] GLM-OCR failed: ${err.message}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  return '';
}

async function extractOcr({ companyId, userId, imageBase64, mimeType }) {
  if (!runtimeAiConfig.enabled) {
    throw ApiError.badRequest('AI services are disabled in settings', 'AI_DISABLED');
  }
  await checkRateLimit(companyId);

  const ocrModel = runtimeAiConfig.ocrModel !== undefined ? runtimeAiConfig.ocrModel : env.ai.ocrModel;
  // Preflight check for Ollama and OCR model
  if (ocrModel) {
    await pingOllama([ocrModel]);
  }

  const safeMime = ['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)
    ? mimeType
    : 'image/jpeg';

  const text = await runOcr(imageBase64, safeMime);
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const logId = await logAi({
    companyId,
    userId,
    type: 'invoice_scan',
    inputRef: 'invoice ocr upload',
    result: { lineCount: lines.length, text },
    confirmed: true,
  });

  return {
    logId,
    text,
    lineCount: lines.length,
    lines,
  };
}

/**
 * Open-source models (served via vLLM/Ollama) are not always as
 * strict about `response_format: json_object` as OpenAI's own models.
 * This extracts the first {...} block from a response as a fallback
 * before giving up  -  a small robustness allowance for Ch. 21's
 * "malformed JSON" failure mode.
 */
function parseJsonLoose(raw) {
  try {
    return JSON.parse(raw);
  } catch (err) {
    const match = raw.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        return JSON.parse(match[0]);
      } catch (err2) {
        return null;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------
// Invoice scan (OCR text + vision, via Qwen2.5-VL + Deterministic Parser)
// ---------------------------------------------------------------------

async function scanInvoice({ companyId, userId, imageBase64, mimeType, scanId: clientScanId }) {
  if (!runtimeAiConfig.enabled) {
    throw ApiError.badRequest('AI services are disabled in settings', 'AI_DISABLED');
  }
  const scanId = clientScanId || `SCAN_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 6)}`;
  const scanStart = Date.now();
  // eslint-disable-next-line no-console
  console.log(`[${scanId}] START companyId=${companyId}`);

  await checkRateLimit(companyId);

  const safeMime = ['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)
    ? mimeType
    : 'image/jpeg';
  const cleanBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '').trim();
  // eslint-disable-next-line no-console
  console.log(`[${scanId}] IMAGE_PROCESSING_END base64Length=${cleanBase64.length} mimeType=${safeMime}`);

  const ocrModel = runtimeAiConfig.ocrModel !== undefined ? runtimeAiConfig.ocrModel : env.ai.ocrModel;
  const visionModel = runtimeAiConfig.visionModel !== undefined ? runtimeAiConfig.visionModel : env.ai.visionModel;
  const baseUrl = runtimeAiConfig.baseUrl || env.ai.baseUrl;

  // Step 0: Fast Failure Preflight check (Ollama reachable & required models installed)
  const requiredModels = [ocrModel, visionModel].filter(Boolean);
  let preflight;
  try {
    preflight = await pingOllama(requiredModels);
    // eslint-disable-next-line no-console
    console.log(`[${scanId}] PREFLIGHT_OK availableModels=${preflight.availableModels.join(', ')}`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(`[${scanId}] PREFLIGHT_FAILED error=${err.message}`);
    throw err;
  }

  // Step 1: Execute fast OCR model (GLM-OCR / microservice)
  let ocrText = '';
  const ocrStart = Date.now();
  // eslint-disable-next-line no-console
  console.log(`[${scanId}] OCR_START model=${ocrModel}`);
  try {
    ocrText = await runOcr(cleanBase64, safeMime);
    // eslint-disable-next-line no-console
    console.log(`[${scanId}] OCR_COMPLETE elapsedMs=${Date.now() - ocrStart} textLength=${ocrText.length}`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(`[${scanId}] OCR_FAILED error=${err.message}`);
  }

  // Step 2: Parse OCR output (deterministic text parser or direct JSON)
  let rawItems = [];
  let supplier = null;
  let date = null;
  let total = null;

  // eslint-disable-next-line no-console
  console.log(`[${scanId}] PARSING_START`);
  const jsonCandidate = parseJsonLoose(ocrText);
  if (jsonCandidate && Array.isArray(jsonCandidate.items) && jsonCandidate.items.length > 0) {
    rawItems = jsonCandidate.items;
    supplier = jsonCandidate.supplier || null;
    date = jsonCandidate.date || null;
    total = typeof jsonCandidate.total === 'number' ? jsonCandidate.total : null;
    // eslint-disable-next-line no-console
    console.log(`[${scanId}] PARSING_COMPLETE (JSON extracted ${rawItems.length} items)`);
  } else if (ocrText && ocrText.length > 0) {
    const deterministicParsed = parseInvoiceText(ocrText);
    rawItems = deterministicParsed.items;
    supplier = deterministicParsed.supplier;
    date = deterministicParsed.date;
    total = deterministicParsed.total;
    // eslint-disable-next-line no-console
    console.log(`[${scanId}] PARSING_COMPLETE (Rule-based extracted ${rawItems.length} items, total=${total})`);
  }

  // Step 3: Direct Vision fallback ONLY IF OCR returned completely empty/unusable items
  if (rawItems.length === 0) {
    const ollamaUrl = baseUrl.replace(/\/v1\/?$/, '');
    const visionStart = Date.now();
    // eslint-disable-next-line no-console
    console.log(`[${scanId}] VISION_FALLBACK_START model=${visionModel}`);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 40000);

    try {
      const response = await fetch(`${ollamaUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: visionModel,
          prompt: 'Extract all products, quantities and prices from this invoice or receipt image into JSON. Format: {"items": [{"name": "item name", "quantity": 1, "unitPrice": 100}], "supplier": "Store Name", "date": "YYYY-MM-DD", "total": 100}. Return JSON only.',
          images: [cleanBase64],
          stream: false,
          format: 'json',
        }),
        signal: controller.signal,
      });

      if (response.ok) {
        const data = await response.json();
        // eslint-disable-next-line no-console
        console.log(`[${scanId}] VISION_FALLBACK_COMPLETE elapsedMs=${Date.now() - visionStart}`);
        const parsed = parseJsonLoose(data.response || '{}');
        if (parsed) {
          if (Array.isArray(parsed.items) && parsed.items.length > 0) rawItems = parsed.items;
          if (parsed.supplier && !supplier) supplier = parsed.supplier;
          if (parsed.date && !date) date = parsed.date;
          if (typeof parsed.total === 'number' && total === null) total = parsed.total;
        }
      } else {
        const errText = await response.text().catch(() => '');
        // eslint-disable-next-line no-console
        console.warn(`[${scanId}] VISION_FALLBACK_HTTP_ERROR status=${response.status} msg=${errText}`);
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn(`[${scanId}] VISION_FALLBACK_FAILED error=${err.message}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  // Defensive sanitation  -  quantities must be >= 1, prices >= 0, names non-empty, max 100 items
  const items = rawItems
    .filter((item) => item && typeof item.name === 'string' && item.name.trim().length > 0)
    .slice(0, 100)
    .map((item) => ({
      name: item.name.trim().slice(0, 150),
      quantity: Math.max(1, Math.min(100000, Math.round(Number(item.quantity) || 1))),
      unitPrice: Math.max(0, Number(item.unitPrice) || 0),
    }));

  // eslint-disable-next-line no-console
  console.log(`[${scanId}] VALIDATION_COMPLETE validItems=${items.length}`);

  if (items.length === 0) {
    // eslint-disable-next-line no-console
    console.error(`[${scanId}] ERROR stage=VALIDATION elapsedMs=${Date.now() - scanStart} message=No items extracted`);
    throw ApiError.internal(
      'Unable to extract invoice items from the image. Please ensure the invoice is clear and well-lit, or add products manually.',
      'AI_REQUEST_FAILED',
    );
  }

  let logId = null;
  try {
    logId = await logAi({
      companyId,
      userId,
      type: 'invoice_scan',
      inputRef: `invoice scan [${scanId}]`,
      result: { items, supplier: supplier ?? null, date: date ?? null, total: total ?? null },
      confirmed: false,
    });
  } catch (logErr) {
    // eslint-disable-next-line no-console
    console.warn(`[${scanId}] DB_LOG_FAILED: ${logErr.message}`);
  }

  // eslint-disable-next-line no-console
  console.log(`[${scanId}] SUCCESS totalMs=${Date.now() - scanStart} itemsCount=${items.length}`);

  return {
    logId,
    scanId,
    items,
    supplier: supplier ?? null,
    date: date ?? null,
    total: total ?? null,
    ocrText: ocrText || null,
  };
}

// ---------------------------------------------------------------------
// AI Assistant (chat)  -  tool-calling loop, grounded in real data only
// ---------------------------------------------------------------------

const MAX_TOOL_CALL_ROUNDS = 4;

async function chat({ companyId, userId, message, history }) {
  if (!runtimeAiConfig.enabled) {
    throw ApiError.badRequest('AI services are disabled in settings', 'AI_DISABLED');
  }
  await checkRateLimit(companyId);

  const cleanMessage = (message || '').trim().slice(0, 2000);
  const lang = detectLanguage(cleanMessage);

  // Retrieve authenticated company context (tenant isolation & business type)
  const companyRes = await query(
    `SELECT name, business_type, currency FROM companies WHERE id = $1`,
    [companyId],
  );
  const company = companyRes.rows[0] || {
    name: 'My Business',
    business_type: 'business',
    currency: 'DZD',
  };

  const openai = getClient();
  const systemPrompt = buildSystemPrompt({ company, language: lang });

  const safeHistory = (Array.isArray(history) ? history : [])
    .filter(
      (m) => m && typeof m.content === 'string' && (m.role === 'user' || m.role === 'assistant'),
    )
    .slice(-10)
    .map((m) => ({ role: m.role, content: m.content.slice(0, 2000) }));

  const messages = [
    { role: 'system', content: systemPrompt },
    ...safeHistory,
    { role: 'user', content: cleanMessage },
  ];

  const collectedToolResults = [];

  // Proactive intent detection: if the user asks a direct business question
  // (e.g. "هل الحليب متوفر؟", "ما هي المنتجات في المخزون؟", "كم حققنا هذا الشهر؟"),
  // execute the database query immediately so Qwen is grounded with real PostgreSQL data.
  const preIntent = detectPreIntent(cleanMessage);
  if (preIntent) {
    try {
      const preResult = await executeTool(companyId, preIntent.toolName, preIntent.args);
      collectedToolResults.push(preResult);

      // If product lookup returned definitive not found or multiple matches,
      // return the verified deterministic template immediately to prevent hallucination.
      if (preIntent.toolName === 'get_product_stock') {
        if (preResult.found === false) {
          const directReply = formatDeterministicResponse(preResult, lang, company);
          const logId = await logAi({
            companyId,
            userId,
            type: 'assistant_chat',
            inputRef: cleanMessage.slice(0, 500),
            result: { reply: directReply },
            confirmed: true,
          });
          return { logId, reply: directReply };
        }
        if (preResult.multiple === true) {
          const directReply = formatDeterministicResponse(preResult, lang, company);
          const logId = await logAi({
            companyId,
            userId,
            type: 'assistant_chat',
            inputRef: cleanMessage.slice(0, 500),
            result: { reply: directReply },
            confirmed: true,
          });
          return { logId, reply: directReply };
        }
      }

      // Inject the proactive tool execution into the message history for Qwen to format naturally
      const syntheticCallId = `call_${Date.now()}`;
      messages.push({
        role: 'assistant',
        content: null,
        tool_calls: [
          {
            id: syntheticCallId,
            type: 'function',
            function: {
              name: preIntent.toolName,
              arguments: JSON.stringify(preIntent.args),
            },
          },
        ],
      });
      messages.push({
        role: 'tool',
        tool_call_id: syntheticCallId,
        content: JSON.stringify(preResult),
      });
    } catch (err) {
      // Continue to standard model loop if proactive query fails
    }
  }

  let toolCallCount = 0;
  let finalReply = null;

  // Standard tool-calling loop (Ch. 8): the model can ask for one or
  // more tools, we run them (scoped to companyId  -  see ai.tools.js),
  // feed the results back, and repeat until it answers in plain text
  // or we hit the round cap (protects against a model stuck looping).
  while (toolCallCount < MAX_TOOL_CALL_ROUNDS) {
    let completion;
    try {
      completion = await openai.chat.completions.create({
        model: runtimeAiConfig.chatModel || env.ai.chatModel,
        temperature: 0.2,
        max_tokens: 500,
        messages,
        tools: TOOL_DEFINITIONS,
      });
    } catch (err) {
      // If AI model call fails but we already have a proactive tool result,
      // provide the deterministic grounded template rather than an error!
      if (collectedToolResults.length > 0) {
        finalReply = formatDeterministicResponse(collectedToolResults[0], lang, company);
        break;
      }
      throw ApiError.internal(`AI chat request failed: ${err.message}`, 'AI_REQUEST_FAILED');
    }

    const choice = completion.choices?.[0];
    const responseMessage = choice?.message;

    if (!responseMessage) {
      throw ApiError.internal('AI returned an empty response', 'AI_BAD_RESPONSE');
    }

    const toolCalls = responseMessage.tool_calls;

    if (!toolCalls || toolCalls.length === 0) {
      finalReply = responseMessage.content?.trim() || '';
      break;
    }

    messages.push(responseMessage);
    toolCallCount += 1;

    for (const call of toolCalls) {
      let args = {};
      try {
        args = call.function?.arguments ? JSON.parse(call.function.arguments) : {};
      } catch (err) {
        args = {};
      }

      const toolResult = await executeTool(companyId, call.function?.name, args);
      collectedToolResults.push(toolResult);

      messages.push({
        role: 'tool',
        tool_call_id: call.id,
        content: JSON.stringify(toolResult),
      });
    }
  }

  const rawReply = finalReply || (
    collectedToolResults.length > 0
      ? formatDeterministicResponse(collectedToolResults[0], lang, company)
      : (lang === 'ar' ? 'عذراً، لم أتمكن من الحصول على إجابة حالياً.' : 'Désolé, je n\'ai pas pu trouver de réponse.')
  );

  // ANTI-HALLUCINATION & LANGUAGE VALIDATION LAYER:
  // Verifies that:
  // 1. Language matches user's request (rejects Chinese drift and unprompted language changes).
  // 2. All numbers stated correspond to real PostgreSQL database results.
  // 3. Products that do not exist are never fabricated.
  const reply = validateAndGroundResponse({
    reply: rawReply,
    lang,
    company,
    collectedToolResults,
  });

  const logId = await logAi({
    companyId,
    userId,
    type: 'assistant_chat',
    inputRef: cleanMessage.slice(0, 500),
    result: { reply },
    // Read-only/advisory  -  nothing for the user to "confirm" the way
    // there is for a scanned invoice.
    confirmed: true,
  });

  return { logId, reply };
}

// ---------------------------------------------------------------------
// AI Insights  -  deterministic metrics (Ch. 6) narrated by Qwen
// ---------------------------------------------------------------------

async function insights({ companyId, userId }) {
  if (!runtimeAiConfig.enabled) {
    throw ApiError.badRequest('AI services are disabled in settings', 'AI_DISABLED');
  }
  await checkRateLimit(companyId);

  // Backend performs every calculation deterministically first  -  the
  // model only ever narrates numbers it's handed, never computes them
  // (Ch. 6 "Use deterministic backend calculations... The LLM should
  // interpret the data, NOT perform critical calculations blindly").
  const [profitThisMonth, topProducts, lowStock, unpaidInvoices, customersWithDebt] =
    await Promise.all([
      executeTool(companyId, 'calculate_profit', { period: 'this_month' }),
      executeTool(companyId, 'get_top_products', { period: 'this_month', limit: 3 }),
      executeTool(companyId, 'get_low_stock_products', {}),
      executeTool(companyId, 'get_unpaid_invoices', {}),
      executeTool(companyId, 'get_customers_with_debt', { limit: 5 }),
    ]);

  const metrics = { profitThisMonth, topProducts, lowStock, unpaidInvoices, customersWithDebt };

  const openai = getClient();
  const chatModel = runtimeAiConfig.chatModel || env.ai.chatModel;

  let completion;
  try {
    completion = await openai.chat.completions.create({
      model: chatModel,
      temperature: 0.4,
      max_tokens: 700,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: INSIGHT_NARRATION_PROMPT },
        { role: 'user', content: `Business metrics (JSON): ${JSON.stringify(metrics)}` },
      ],
    });
  } catch (err) {
    throw ApiError.internal(`AI insights request failed: ${err.message}`, 'AI_REQUEST_FAILED');
  }

  const raw = completion.choices?.[0]?.message?.content || '{}';
  const parsed = parseJsonLoose(raw);

  if (!parsed) {
    throw ApiError.internal('AI returned an unreadable response', 'AI_BAD_RESPONSE');
  }

  const allowedSeverities = new Set(['info', 'watch', 'alert']);
  const cleanInsights = (Array.isArray(parsed.insights) ? parsed.insights : [])
    .filter((i) => i && typeof i.title === 'string' && typeof i.detail === 'string')
    .slice(0, 5)
    .map((i) => ({
      title: i.title.trim().slice(0, 120),
      detail: i.detail.trim().slice(0, 300),
      severity: allowedSeverities.has(i.severity) ? i.severity : 'info',
    }));

  await logAi({
    companyId,
    userId,
    type: 'insight_generation',
    inputRef: 'dashboard metrics',
    result: { insights: cleanInsights },
    confirmed: true,
  });

  return { insights: cleanInsights };
}

async function checkHealth() {
  const baseUrl = runtimeAiConfig.baseUrl || env.ai.baseUrl;
  const ollamaUrl = baseUrl.replace(/\/v1\/?$/, '');
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000);
  try {
    const res = await fetch(`${ollamaUrl}/api/tags`, { signal: controller.signal });
    clearTimeout(timeoutId);
    if (!res.ok) {
      return {
        status: 'offline',
        error: `Ollama returned status ${res.status}`,
        configured: {
          enabled: runtimeAiConfig.enabled,
          baseUrl: runtimeAiConfig.baseUrl,
          chatModel: runtimeAiConfig.chatModel || env.ai.chatModel,
          visionModel: runtimeAiConfig.visionModel || env.ai.visionModel,
          ocrModel: runtimeAiConfig.ocrModel || env.ai.ocrModel,
        },
      };
    }
    const data = await res.json();
    const availableModels = (data.models || []).map((m) => m.name);

    const configured = {
      enabled: runtimeAiConfig.enabled,
      baseUrl: runtimeAiConfig.baseUrl,
      chatModel: runtimeAiConfig.chatModel || env.ai.chatModel,
      visionModel: runtimeAiConfig.visionModel || env.ai.visionModel,
      ocrModel: runtimeAiConfig.ocrModel || env.ai.ocrModel,
    };

    const missingModels = [configured.chatModel, configured.visionModel, configured.ocrModel]
      .filter(Boolean)
      .filter((modelName) => !isModelAvailable(modelName, availableModels));

    return {
      status: !runtimeAiConfig.enabled ? 'disabled' : (missingModels.length > 0 ? 'degraded' : 'ok'),
      configured,
      availableModels,
      missingModels,
    };
  } catch (err) {
    clearTimeout(timeoutId);
    return {
      status: 'offline',
      error: err.message,
      configured: {
        enabled: runtimeAiConfig.enabled,
        baseUrl: runtimeAiConfig.baseUrl,
        chatModel: runtimeAiConfig.chatModel || env.ai.chatModel,
        visionModel: runtimeAiConfig.visionModel || env.ai.visionModel,
        ocrModel: runtimeAiConfig.ocrModel || env.ai.ocrModel,
      },
    };
  }
}

module.exports = {
  scanInvoice,
  extractOcr,
  runOcr,
  confirmAiLog,
  submitFeedback,
  chat,
  insights,
  checkHealth,
  getAiConfig,
  updateRuntimeAiConfig,
  pingOllama,
  normalizeOllamaModelName,
  isModelAvailable,
  // Exported for unit testing only (see __tests__/ai.service.test.js).
  parseJsonLoose,
};

