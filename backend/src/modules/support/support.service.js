const crypto = require('crypto');
const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

function sanitizeText(str) {
  if (typeof str !== 'string') return '';
  return str.trim();
}

function validateEmail(email) {
  return typeof email === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());
}

async function submitContactMessage({
  name,
  email,
  phone,
  category,
  subject,
  message,
  userId = null,
  companyId = null,
}) {
  const cleanName = sanitizeText(name);
  const cleanEmail = sanitizeText(email).toLowerCase();
  const cleanPhone = phone ? sanitizeText(phone) : null;
  const cleanCategory = sanitizeText(category) || 'general';
  const cleanSubject = subject ? sanitizeText(subject) : null;
  const cleanMessage = sanitizeText(message);

  if (!cleanName || cleanName.length < 2) {
    throw ApiError.badRequest('Name must be at least 2 characters', 'VALIDATION_ERROR');
  }

  if (!validateEmail(cleanEmail)) {
    throw ApiError.badRequest('A valid email address is required', 'VALIDATION_ERROR');
  }

  if (!cleanMessage || cleanMessage.length < 10) {
    throw ApiError.badRequest('Message must be at least 10 characters', 'VALIDATION_ERROR');
  }

  if (cleanMessage.length > 5000) {
    throw ApiError.badRequest('Message cannot exceed 5000 characters', 'VALIDATION_ERROR');
  }

  const ticketNumber = `TIC-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

  const res = await query(
    `INSERT INTO support_messages (
       ticket_number, user_id, company_id, name, email, phone,
       category, subject, message, status
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'new')
     RETURNING id, ticket_number, status, created_at`,
    [
      ticketNumber,
      userId,
      companyId,
      cleanName,
      cleanEmail,
      cleanPhone,
      cleanCategory,
      cleanSubject,
      cleanMessage,
    ],
  );

  return {
    ticketId: res.rows[0].id,
    ticketNumber: res.rows[0].ticket_number,
    status: res.rows[0].status,
    message: 'Your message has been received. Our team will contact you shortly.',
    messageAr: 'تم استلام رسالتك بنجاح. سيتواصل معك فريق الدعم قريباً.',
    messageFr: 'Votre message a été reçu. Notre équipe vous répondra sous peu.',
  };
}

async function submitFeedback({
  category,
  message,
  rating = null,
  userId = null,
  companyId = null,
}) {
  const cleanCategory = sanitizeText(category) || 'general_feedback';
  const cleanMessage = sanitizeText(message);

  if (!cleanMessage || cleanMessage.length < 5) {
    throw ApiError.badRequest('Feedback message must be at least 5 characters', 'VALIDATION_ERROR');
  }

  if (cleanMessage.length > 5000) {
    throw ApiError.badRequest('Feedback message cannot exceed 5000 characters', 'VALIDATION_ERROR');
  }

  let numericRating = null;
  if (rating !== null && rating !== undefined) {
    numericRating = Number.parseInt(rating, 10);
    if (Number.isNaN(numericRating) || numericRating < 1 || numericRating > 5) {
      throw ApiError.badRequest('Rating must be an integer between 1 and 5', 'VALIDATION_ERROR');
    }
  }

  const res = await query(
    `INSERT INTO feedback_submissions (
       user_id, company_id, category, message, rating, status
     ) VALUES ($1, $2, $3, $4, $5, 'new')
     RETURNING id, status, created_at`,
    [userId, companyId, cleanCategory, cleanMessage, numericRating],
  );

  return {
    feedbackId: res.rows[0].id,
    status: res.rows[0].status,
    message: 'Thank you for your valuable feedback!',
    messageAr: 'شكراً جزيلاً على ملاحظاتك القيمة!',
    messageFr: 'Merci pour vos précieux retours !',
  };
}

/**
 * Submits a suspension appeal bound strictly to the server-verified
 * `appealContext` (`userId`, `companyId`, `name`, `email`).
 * Never trusts client-supplied tenant/user identifiers.
 */
async function submitSuspensionAppeal({
  appealContext,
  message,
  subject = null,
  contactPhone = null,
}) {
  if (!appealContext || !appealContext.userId || !appealContext.companyId) {
    throw ApiError.unauthorized(
      'Authenticated appeal context is required.',
      'APPEAL_AUTH_REQUIRED',
    );
  }

  if (!appealContext.isSuspended) {
    throw ApiError.badRequest(
      'This account is not currently suspended.',
      'ACCOUNT_NOT_SUSPENDED',
    );
  }

  const cleanMessage = sanitizeText(message);
  if (!cleanMessage || cleanMessage.length < 10) {
    throw ApiError.badRequest(
      'Appeal explanation must be at least 10 characters.',
      'VALIDATION_ERROR',
    );
  }

  if (cleanMessage.length > 2000) {
    throw ApiError.badRequest(
      'Appeal explanation cannot exceed 2000 characters.',
      'VALIDATION_ERROR',
    );
  }

  const defaultSubject = `Account Suspension Appeal — ${appealContext.companyName || appealContext.email}`;
  const cleanSubject = subject
    ? sanitizeText(subject).slice(0, 255) || defaultSubject
    : defaultSubject;
  const cleanPhone = contactPhone
    ? sanitizeText(contactPhone).slice(0, 60)
    : appealContext.phone || null;

  // Prevent flooding open appeal tickets for the same company
  const openRes = await query(
    `SELECT COUNT(*)::int AS open_count
     FROM support_messages
     WHERE company_id = $1
       AND category = 'suspension_appeal'
       AND status IN ('new', 'in_progress')`,
    [appealContext.companyId],
  );

  const openCount = openRes.rows[0]?.open_count || 0;
  if (openCount >= 3) {
    throw ApiError.tooManyRequests(
      'You already have pending appeals under review. Please wait for the administrator to review your existing request.',
      'TOO_MANY_OPEN_APPEALS',
    );
  }

  const ticketNumber = `APL-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

  const res = await query(
    `INSERT INTO support_messages (
       ticket_number, user_id, company_id, name, email, phone,
       category, subject, message, status
     ) VALUES ($1, $2, $3, $4, $5, $6, 'suspension_appeal', $7, $8, 'new')
     RETURNING id, ticket_number, subject, message, status, created_at`,
    [
      ticketNumber,
      appealContext.userId,
      appealContext.companyId,
      appealContext.name || 'Modiri User',
      appealContext.email,
      cleanPhone,
      cleanSubject,
      cleanMessage,
    ],
  );

  const row = res.rows[0];
  return {
    appealId: row.id,
    ticketNumber: row.ticket_number,
    ticketId: row.ticket_number,
    status: row.status,
    createdAt: row.created_at,
    message: 'Your appeal has been submitted to the administrator for review.',
    messageAr: 'تم إرسال طلب المراجعة إلى الإدارة بنجاح وسيتم دراسته قريباً.',
    messageFr: 'Votre recours a été transmis à l’administrateur pour examen.',
  };
}

/**
 * Returns the live suspension status and appeal history for the authenticated
 * appeal context.
 */
async function getAppealStatus({ appealContext }) {
  if (!appealContext || !appealContext.userId || !appealContext.companyId) {
    throw ApiError.unauthorized(
      'Authenticated appeal context is required.',
      'APPEAL_AUTH_REQUIRED',
    );
  }

  // Defensively check if public_reply column exists; if not, query NULL
  const colRes = await query(`
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'support_messages' AND column_name = 'public_reply'
  `);
  const hasPublicReply = colRes.rows && colRes.rows.length > 0;

  const res = await query(
    `SELECT id, ticket_number, subject, message, status,
            ${hasPublicReply ? 'public_reply' : 'NULL AS public_reply'},
            created_at, updated_at
     FROM support_messages
     WHERE company_id = $1
       AND category = 'suspension_appeal'
     ORDER BY created_at DESC
     LIMIT 10`,
    [appealContext.companyId],
  );

  return {
    companyId: appealContext.companyId,
    companyName: appealContext.companyName,
    isSuspended: appealContext.isSuspended,
    suspensionReason: appealContext.suspensionReason,
    suspendedAt: appealContext.suspendedAt,
    company: {
      id: appealContext.companyId,
      name: appealContext.companyName,
      isSuspended: appealContext.isSuspended,
      suspensionReason: appealContext.suspensionReason,
      suspendedAt: appealContext.suspendedAt,
    },
    appeals: res.rows.map((r) => ({
      id: r.id,
      ticketNumber: r.ticket_number,
      ticketId: r.ticket_number,
      subject: r.subject,
      message: r.message,
      status: r.status,
      publicReply: r.public_reply || null,
      public_reply: r.public_reply || null,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    })),
  };
}

module.exports = {
  submitContactMessage,
  submitFeedback,
  submitSuspensionAppeal,
  getAppealStatus,
};

