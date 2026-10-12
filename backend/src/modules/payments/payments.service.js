const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { query, withTransaction } = require('../../config/db');
const subscriptionConfig = require('../../config/subscription');
const ApiError = require('../../utils/ApiError');

const RECEIPTS_DIR = path.join(__dirname, '..', '..', '..', 'storage', 'receipts');

// Ensure private receipts storage directory exists
if (!fs.existsSync(RECEIPTS_DIR)) {
  fs.mkdirSync(RECEIPTS_DIR, { recursive: true });
}

/**
 * Validates file magic bytes (signatures) against claimed extension/mime
 */
function validateFileSignature(buffer, originalFilename) {
  if (!buffer || buffer.length < 4) {
    throw ApiError.badRequest('File is empty or corrupted', 'INVALID_FILE');
  }

  const ext = path.extname(originalFilename || '').toLowerCase();
  if (!subscriptionConfig.storage.allowedExtensions.includes(ext)) {
    throw ApiError.badRequest(
      `File format not allowed. Supported formats: ${subscriptionConfig.storage.allowedExtensions.join(', ')}`,
      'INVALID_FILE_TYPE',
    );
  }

  // Magic bytes checks
  const isJpg = buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  const isPng =
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47;
  const isPdf =
    buffer[0] === 0x25 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x44 &&
    buffer[3] === 0x46; // %PDF

  if (ext === '.jpg' || ext === '.jpeg') {
    if (!isJpg) throw ApiError.badRequest('Invalid JPEG file content', 'MIME_SPOOFING_DETECTED');
  } else if (ext === '.png') {
    if (!isPng) throw ApiError.badRequest('Invalid PNG file content', 'MIME_SPOOFING_DETECTED');
  } else if (ext === '.pdf') {
    if (!isPdf) throw ApiError.badRequest('Invalid PDF file content', 'MIME_SPOOFING_DETECTED');
  }

  return ext;
}

/**
 * Creates a Chargily checkout session for the lifetime license.
 */
async function createChargilyCheckout({ companyId, userId, successUrl, failureUrl }) {
  const fixedAmount = subscriptionConfig.product.priceDzd; // Fixed 15,000 DZD
  const currency = subscriptionConfig.product.currency;

  const orderNumber = `ORD-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
  const idempotencyKey = crypto.randomUUID();

  return withTransaction(async (client) => {
    // Check if company already has lifetime license
    const companyRes = await client.query(
      `SELECT entitlement_type, is_suspended FROM companies WHERE id = $1 FOR UPDATE`,
      [companyId],
    );
    const company = companyRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');
    if (company.is_suspended) {
      throw ApiError.forbidden('Account is suspended', 'ACCOUNT_SUSPENDED');
    }
    if (company.entitlement_type === 'lifetime') {
      throw ApiError.badRequest('Company already owns a lifetime license', 'ALREADY_PURCHASED');
    }

    const orderRes = await client.query(
      `INSERT INTO payment_orders (
         order_number, company_id, user_id, product_type, payment_method,
         amount, currency, status, idempotency_key
       ) VALUES ($1, $2, $3, 'lifetime_license', 'chargily', $4, $5, 'created', $6)
       RETURNING *`,
      [orderNumber, companyId, userId, fixedAmount, currency, idempotencyKey],
    );

    const order = orderRes.rows[0];

    // If Chargily credentials are configured, call the Chargily API
    const apiKey = subscriptionConfig.chargily.apiKey;
    let checkoutUrl = null;
    let providerCheckoutId = null;

    if (apiKey) {
      try {
        const chargilyRes = await fetch(`${subscriptionConfig.chargily.baseUrl}/checkouts`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: fixedAmount,
            currency: 'dzd',
            success_url:
              successUrl ||
              `https://modiri-ai.com/payment/success?order_id=${order.id}`,
            failure_url:
              failureUrl ||
              `https://modiri-ai.com/payment/failure?order_id=${order.id}`,
            metadata: {
              order_id: order.id,
              order_number: order.order_number,
              company_id: companyId,
              user_id: userId,
            },
          }),
        });

        const chargilyData = await chargilyRes.json();
        if (chargilyRes.ok && chargilyData && chargilyData.checkout_url) {
          checkoutUrl = chargilyData.checkout_url;
          providerCheckoutId = chargilyData.id;

          await client.query(
            `UPDATE payment_orders
             SET status = 'pending',
                 provider_checkout_id = $2,
                 checkout_url = $3,
                 raw_response = $4,
                 updated_at = now()
             WHERE id = $1`,
            [order.id, providerCheckoutId, checkoutUrl, JSON.stringify(chargilyData)],
          );
        } else {
          // eslint-disable-next-line no-console
          console.warn('[CHARGILY] API rejected checkout creation:', chargilyData);
          throw new Error(chargilyData.message || 'Chargily checkout creation rejected');
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('[CHARGILY] Error invoking Chargily API:', err.message);
        throw ApiError.internal(
          'Chargily electronic payment service is temporarily unavailable. Please use manual CCP payment.',
          'PAYMENT_GATEWAY_ERROR',
        );
      }
    } else {
      if (process.env.NODE_ENV === 'production') {
        throw ApiError.internal(
          'Chargily electronic payment service is not configured. Please use manual CCP payment.',
          'PAYMENT_GATEWAY_NOT_CONFIGURED',
        );
      }
      // In sandbox/development when API key is not yet set
      checkoutUrl = `https://pay.chargily.net/test/checkout/simulated-${order.id}`;
      providerCheckoutId = `ch_test_${order.id}`;

      await client.query(
        `UPDATE payment_orders
         SET status = 'pending',
             provider_checkout_id = $2,
             checkout_url = $3,
             updated_at = now()
         WHERE id = $1`,
        [order.id, providerCheckoutId, checkoutUrl],
      );
    }

    return {
      orderId: order.id,
      orderNumber: order.order_number,
      amount: fixedAmount,
      currency,
      checkoutUrl,
      status: 'pending',
      chargilyConfigured: !!apiKey,
    };
  });
}

/**
 * Securely verifies and processes official Chargily webhooks.
 */
async function processChargilyWebhook({ rawBody, signatureHeader, eventData }) {
  // Webhooks are signed exclusively with the webhook Secret Key (not the public API key)
  const secret = subscriptionConfig.chargily.secretKey;

  // 1. Signature Verification - Fail closed if secret is unconfigured
  if (!secret || typeof secret !== 'string' || !secret.trim()) {
    throw ApiError.internal('Payment webhook secret is unconfigured', 'WEBHOOK_SECRET_UNCONFIGURED');
  }

  // Signature header is strictly mandatory
  if (!signatureHeader || typeof signatureHeader !== 'string' || !signatureHeader.trim()) {
    // eslint-disable-next-line no-console
    console.error('[CHARGILY WEBHOOK] Missing signature header on incoming webhook');
    throw ApiError.forbidden('Missing webhook signature header', 'MISSING_SIGNATURE');
  }

    if (!rawBody) {
      throw ApiError.badRequest('Raw webhook body missing for signature verification');
    }

    const calculatedSig = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    let isValid = false;
    try {
      const expectedBuffer = Buffer.from(calculatedSig, 'hex');
      const providedBuffer = Buffer.from(signatureHeader.trim(), 'hex');

      if (
        expectedBuffer.length === providedBuffer.length &&
        crypto.timingSafeEqual(expectedBuffer, providedBuffer)
      ) {
        isValid = true;
      }
    } catch (_) {
      isValid = false;
    }

    if (!isValid) {
      // eslint-disable-next-line no-console
      console.error('[CHARGILY WEBHOOK] Signature verification failed');
      throw ApiError.forbidden('Invalid webhook signature', 'INVALID_SIGNATURE');
    }

  // 2. Extract Event & Data
  const eventId = eventData?.id || eventData?.event_id || crypto.randomUUID();
  const eventType = eventData?.type || eventData?.event || 'checkout.paid';
  const checkout = eventData?.data || eventData;

  const checkoutId = checkout?.id;
  const status = checkout?.status;
  const metadata = checkout?.metadata || {};
  const orderId = metadata.order_id;
  const amount = checkout?.amount;

  return withTransaction(async (client) => {
    // 3. Idempotency Check on eventId
    const existingEvent = await client.query(
      `SELECT id FROM payment_webhook_events WHERE event_id = $1`,
      [String(eventId)],
    );
    if (existingEvent.rows.length > 0) {
      return { status: 'already_processed', eventId };
    }

    await client.query(
      `INSERT INTO payment_webhook_events (event_id, event_type, payload)
       VALUES ($1, $2, $3)`,
      [String(eventId), eventType, JSON.stringify(eventData)],
    );

    // Find the associated payment order
    let orderRes;
    if (orderId) {
      orderRes = await client.query(
        `SELECT * FROM payment_orders WHERE id = $1 FOR UPDATE`,
        [orderId],
      );
    } else if (checkoutId) {
      orderRes = await client.query(
        `SELECT * FROM payment_orders WHERE provider_checkout_id = $1 FOR UPDATE`,
        [checkoutId],
      );
    }

    const order = orderRes?.rows?.[0];
    if (!order) {
      // eslint-disable-next-line no-console
      console.warn('[CHARGILY WEBHOOK] Order not found for webhook:', { orderId, checkoutId });
      return { status: 'order_not_found', eventId };
    }

    if (order.status === 'paid') {
      return { status: 'already_paid', orderId: order.id };
    }

    if (order.status === 'cancelled' || order.status === 'refunded') {
      return { status: `order_${order.status}`, orderId: order.id };
    }

    // 4. Validate tenant/company association
    if (metadata.company_id && String(metadata.company_id) !== String(order.company_id)) {
      // eslint-disable-next-line no-console
      console.error('[CHARGILY WEBHOOK] Tenant mismatch on order:', {
        expected: order.company_id,
        received: metadata.company_id,
      });
      return { status: 'tenant_mismatch', orderId: order.id };
    }

    // 5. Validate Currency
    const checkoutCurrency = (checkout?.currency || '').toLowerCase();
    if (checkoutCurrency && checkoutCurrency !== 'dzd') {
      // eslint-disable-next-line no-console
      console.error('[CHARGILY WEBHOOK] Currency mismatch:', { currency: checkoutCurrency, expected: 'dzd' });
      await client.query(
        `UPDATE payment_orders SET status = 'under_review', updated_at = now() WHERE id = $1`,
        [order.id],
      );
      return { status: 'currency_mismatch', orderId: order.id };
    }

    // 6. Check payment outcome
    const isExplicitlyPaid =
      (status === 'paid' && (eventType === 'checkout.paid' || eventType === 'payment.paid' || !eventType)) ||
      (eventType === 'checkout.paid' && (!status || status === 'paid'));

    const isExplicitlyFailed =
      status === 'failed' ||
      status === 'canceled' ||
      status === 'expired' ||
      eventType === 'checkout.failed' ||
      eventType === 'checkout.canceled' ||
      eventType === 'checkout.expired';

    if (isExplicitlyPaid && !isExplicitlyFailed) {
      // Validate amount (15,000 DZD)
      if (amount && Number(amount) < subscriptionConfig.product.priceDzd) {
        // eslint-disable-next-line no-console
        console.error('[CHARGILY WEBHOOK] Payment amount mismatch:', { amount, expected: subscriptionConfig.product.priceDzd });
        await client.query(
          `UPDATE payment_orders SET status = 'under_review', updated_at = now() WHERE id = $1`,
          [order.id],
        );
        return { status: 'amount_mismatch', orderId: order.id };
      }

      // Mark order paid
      await client.query(
        `UPDATE payment_orders
         SET status = 'paid',
             paid_at = now(),
             provider_payment_id = $2,
             updated_at = now()
         WHERE id = $1`,
        [order.id, checkoutId || 'paid'],
      );

      // Transactionally activate lifetime license for the company
      await client.query(
        `UPDATE companies
         SET entitlement_type = 'lifetime',
             entitlement_granted_at = now(),
             entitlement_granted_by = $2,
             updated_at = now()
         WHERE id = $1`,
        [order.company_id, order.user_id],
      );

      // Audit Log
      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, actor_id, action, previous_entitlement,
           new_entitlement, reason, metadata
         ) VALUES ($1, $2, $2, 'chargily_activated', 'trial', 'lifetime',
           'Chargily Pay electronic payment verified', $3)`,
        [order.company_id, order.user_id, JSON.stringify({ orderId: order.id, amount })],
      );

      // Notification
      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'license_granted', $3, $4)`,
        [
          order.company_id,
          order.user_id,
          'Lifetime License Activated | تم تفعيل رخصة مدى الحياة',
          'Thank you! Your payment of 15,000 DZD has been verified. Your Modiri AI lifetime license is permanently active.\n\nشكراً لك! تم تأكيد دفع 15,000 دج. رخصة Modiri AI مدى الحياة مفعلة لحسابك بشكل دائم.\n\nMerci ! Votre paiement de 15 000 DZD est validé. Votre licence à vie Modiri AI est activée.',
        ],
      );

      return { status: 'activated', orderId: order.id };
    } else if (isExplicitlyFailed) {
      await client.query(
        `UPDATE payment_orders SET status = 'failed', updated_at = now() WHERE id = $1`,
        [order.id],
      );
      return { status: 'failed', orderId: order.id };
    } else {
      // Pending, processing, or unknown status - DO NOT activate
      return { status: status || 'pending', orderId: order.id };
    }

    return { status: 'unhandled_event', eventType };
  });
}

/**
 * Creates a manual CCP payment request with official account details.
 */
async function createManualPaymentRequest({ companyId, userId, transferReference }) {
  const fixedAmount = subscriptionConfig.product.priceDzd;
  const currency = subscriptionConfig.product.currency;
  const orderNumber = `CCP-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;

  return withTransaction(async (client) => {
    // Check if company already has lifetime license
    const companyRes = await client.query(
      `SELECT entitlement_type, is_suspended FROM companies WHERE id = $1 FOR UPDATE`,
      [companyId],
    );
    const company = companyRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');
    if (company.is_suspended) {
      throw ApiError.forbidden('Account is suspended', 'ACCOUNT_SUSPENDED');
    }
    if (company.entitlement_type === 'lifetime') {
      throw ApiError.badRequest('Company already owns a lifetime license', 'ALREADY_PURCHASED');
    }

    // Create payment order
    const orderRes = await client.query(
      `INSERT INTO payment_orders (
         order_number, company_id, user_id, product_type, payment_method,
         amount, currency, status
       ) VALUES ($1, $2, $3, 'lifetime_license', 'manual_ccp', $4, $5, 'pending')
       RETURNING *`,
      [orderNumber, companyId, userId, fixedAmount, currency],
    );

    const order = orderRes.rows[0];

    // Create manual payment request
    const requestRes = await client.query(
      `INSERT INTO manual_payment_requests (
         order_id, company_id, user_id, amount, currency,
         transfer_reference, status
       ) VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       RETURNING *`,
      [order.id, companyId, userId, fixedAmount, currency, transferReference ? String(transferReference).trim() : null],
    );

    const manualRequest = requestRes.rows[0];

    return {
      requestId: manualRequest.id,
      orderId: order.id,
      orderNumber: order.order_number,
      amount: fixedAmount,
      currency,
      status: manualRequest.status,
      transferReference: manualRequest.transfer_reference,
      ccpDetails: {
        accountHolder: subscriptionConfig.business.ownerName,
        accountHolderAr: subscriptionConfig.business.ownerNameAr,
        ccpAccount: subscriptionConfig.business.ccpAccount,
        businessAddress: subscriptionConfig.business.address,
        supportWhatsApp: subscriptionConfig.business.supportWhatsApp,
        whatsappUrl: subscriptionConfig.business.whatsappUrl,
      },
    };
  });
}

/**
 * Directly uploads a payment receipt for a manual payment request.
 */
async function uploadReceipt({ requestId, companyId, userId, fileBuffer, originalFilename, mimeType }) {
  if (!fileBuffer || fileBuffer.length === 0) {
    throw ApiError.badRequest('Receipt file is required', 'MISSING_FILE');
  }

  if (fileBuffer.length > subscriptionConfig.storage.maxReceiptSizeBytes) {
    throw ApiError.badRequest(
      `Receipt file size exceeds maximum limit of 5 MB (${(fileBuffer.length / (1024 * 1024)).toFixed(1)} MB)`,
      'FILE_TOO_LARGE',
    );
  }

  const ext = validateFileSignature(fileBuffer, originalFilename);

  return withTransaction(async (client) => {
    const reqRes = await client.query(
      `SELECT * FROM manual_payment_requests WHERE id = $1 AND company_id = $2 FOR UPDATE`,
      [requestId, companyId],
    );

    const manualReq = reqRes.rows[0];
    if (!manualReq) {
      throw ApiError.notFound('Manual payment request not found or unauthorized');
    }

    if (manualReq.status === 'approved') {
      throw ApiError.badRequest('This payment request is already approved', 'ALREADY_APPROVED');
    }

    // Generate secure randomized storage filename
    const storageFilename = `${crypto.randomUUID()}${ext}`;
    const storagePath = path.join(RECEIPTS_DIR, storageFilename);

    // Write file securely to private storage
    fs.writeFileSync(storagePath, fileBuffer);

    // Update manual payment record
    const updatedRes = await client.query(
      `UPDATE manual_payment_requests
       SET receipt_storage_path = $2,
           receipt_original_filename = $3,
           receipt_mime_type = $4,
           receipt_file_size = $5,
           receipt_data = $6,
           receipt_uploaded_at = now(),
           status = 'under_review',
           updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [
        requestId,
        storageFilename,
        path.basename(originalFilename).replace(/[^a-zA-Z0-9._-]/g, '_'),
        mimeType || 'application/octet-stream',
        fileBuffer.length,
        fileBuffer,
      ],
    );

    // Update order status
    if (manualReq.order_id) {
      await client.query(
        `UPDATE payment_orders SET status = 'under_review', updated_at = now() WHERE id = $1`,
        [manualReq.order_id],
      );
    }

    return {
      requestId,
      status: 'under_review',
      message: 'Payment receipt uploaded successfully. Our team will review and verify your payment.',
      messageAr: 'وصل الدفع قيد المراجعة — لم يتم تفعيل الرخصة بعد.',
      messageFr: 'Justificatif en cours de vérification — la licence n\'est pas encore activée.',
    };
  });
}

async function getCompanyManualRequests(companyId) {
  const res = await query(
    `SELECT r.*, o.order_number
     FROM manual_payment_requests r
     LEFT JOIN payment_orders o ON o.id = r.order_id
     WHERE r.company_id = $1
     ORDER BY r.created_at DESC`,
    [companyId],
  );

  return res.rows.map((row) => ({
    id: row.id,
    orderId: row.order_id,
    orderNumber: row.order_number,
    amount: row.amount,
    currency: row.currency,
    status: row.status,
    transferReference: row.transfer_reference,
    receiptUploaded: !!row.receipt_storage_path,
    receiptUploadedAt: row.receipt_uploaded_at,
    rejectionReason: row.rejection_reason,
    createdAt: row.created_at,
  }));
}

async function getReceiptFile(filename, user) {
  // Validate filename strictly: must be a safe UUID + allowed extension to eliminate path traversal
  const safeFilename = path.basename(filename);
  if (
    safeFilename !== filename ||
    !/^[a-f0-9-]+\.(jpe?g|png|pdf)$/i.test(safeFilename)
  ) {
    throw ApiError.badRequest('Invalid file name');
  }

  // Authorization check: ensure user owns the receipt or is super_admin
  const reqRes = await query(
    `SELECT r.*, u.id as user_id, u.company_id
     FROM manual_payment_requests r
     JOIN users u ON u.id = r.user_id
     WHERE r.receipt_storage_path = $1`,
    [safeFilename],
  );

  const request = reqRes.rows[0];
  if (!request) {
    throw ApiError.notFound('Receipt not found');
  }

  const isPrivileged = user.role === 'super_admin';
  const isOwner = user.companyId === request.company_id;

  if (!isPrivileged && !isOwner) {
    throw ApiError.forbidden('Unauthorized access to private receipt');
  }

  const fullPath = path.join(RECEIPTS_DIR, safeFilename);
  let fileBuffer = null;

  if (fs.existsSync(fullPath)) {
    // Disk cache hit
  } else if (request.receipt_data) {
    // Durable DB hit (preserves receipt across Render Free container restarts)
    fileBuffer = request.receipt_data;
    try {
      fs.writeFileSync(fullPath, fileBuffer);
    } catch (_) {}
  } else {
    throw ApiError.notFound('Receipt file not found on disk or database');
  }

  return {
    filePath: fullPath,
    fileBuffer,
    mimeType: request.receipt_mime_type || 'application/octet-stream',
    originalFilename: request.receipt_original_filename || safeFilename,
  };
}


module.exports = {
  createChargilyCheckout,
  processChargilyWebhook,
  createManualPaymentRequest,
  uploadReceipt,
  getCompanyManualRequests,
  getReceiptFile,
};
