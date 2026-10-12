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

module.exports = {
  submitContactMessage,
  submitFeedback,
};
