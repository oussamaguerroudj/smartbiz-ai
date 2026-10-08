const env = require('../config/env');

function getRecipientDomain(email) {
  const parts = String(email || '').split('@');
  return parts.length > 1 ? `@${parts[1]}` : 'unknown';
}

/**
 * Sends a transactional email using the Brevo HTTPS REST API.
 * Endpoint: POST https://api.brevo.com/v3/smtp/email
 *
 * This bypasses outbound SMTP port restrictions (e.g. Render Free tier blocking ports 25, 465, 587).
 */
async function sendMail({ to, subject, html, text }) {
  const apiKey = env.brevo.apiKey;
  const fromEmail = env.brevo.fromEmail;
  const fromName = env.brevo.fromName;

  if (!apiKey) {
    if (env.nodeEnv === 'test') {
      return { messageId: 'mock-test-id', accepted: [to ? to.trim() : ''] };
    }

    // eslint-disable-next-line no-console
    console.error(
      `[EMAIL] Brevo API key is not configured (BREVO_API_KEY missing) - ` +
        `cannot send "${subject}" to ${getRecipientDomain(to)}. ` +
        'Set BREVO_API_KEY in .env.',
    );

    throw new Error('Email delivery is not configured on this server');
  }

  if (typeof to !== 'string' || to.trim().length === 0) {
    throw new Error('Email recipient is required');
  }

  if (typeof subject !== 'string' || subject.trim().length === 0) {
    throw new Error('Email subject is required');
  }

  if (typeof html !== 'string' || html.trim().length === 0) {
    throw new Error('Email content is required');
  }

  const recipientDomain = getRecipientDomain(to);
  const startTime = Date.now();

  // eslint-disable-next-line no-console
  console.log(`[EMAIL] verification_email start: provider=brevo-https toDomain=${recipientDomain}`);

  const payload = {
    sender: {
      name: fromName,
      email: fromEmail,
    },
    to: [
      {
        email: to.trim(),
      },
    ],
    subject: subject.trim(),
    htmlContent: html,
  };

  if (text && typeof text === 'string' && text.trim().length > 0) {
    payload.textContent = text.trim();
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000);
  if (typeof timeoutId.unref === 'function') {
    timeoutId.unref();
  }

  try {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const duration = Date.now() - startTime;

    if (!response.ok) {
      let errBody;
      try {
        errBody = await response.json();
      } catch (_) {
        errBody = await response.text();
      }

      // eslint-disable-next-line no-console
      console.error(`[EMAIL] verification_email failed after ${duration} ms (status ${response.status}):`, {
        status: response.status,
        code: errBody?.code || 'BREVO_ERROR',
        message: errBody?.message || errBody?.error || 'Brevo API error',
      });

      const err = new Error(errBody?.message || `Brevo API returned status ${response.status}`);
      err.code = 'BREVO_API_ERROR';
      err.status = response.status;
      err.brevoCode = errBody?.code;
      throw err;
    }

    const data = await response.json().catch(() => ({}));
    // eslint-disable-next-line no-console
    console.log(`[EMAIL] Brevo HTTPS API completed in ${duration} ms`);
    // eslint-disable-next-line no-console
    console.log(`[EMAIL] verification_email success: messageId=${data?.messageId || 'accepted'}`);

    return {
      messageId: data?.messageId || 'accepted',
      accepted: [to.trim()],
    };
  } catch (err) {
    const duration = Date.now() - startTime;
    if (err.name === 'AbortError') {
      // eslint-disable-next-line no-console
      console.error(`[EMAIL] verification_email failed after ${duration} ms: Request timed out after 8000ms`);
      const timeoutErr = new Error('Brevo API request timed out');
      timeoutErr.code = 'ETIMEDOUT';
      throw timeoutErr;
    }
    if (err.code !== 'BREVO_API_ERROR') {
      // eslint-disable-next-line no-console
      console.error(`[EMAIL] verification_email network failure after ${duration} ms:`, err.message);
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

async function verifyEmailService() {
  const apiKey = env.brevo.apiKey;
  if (!apiKey) {
    return { ok: false, error: 'BREVO_API_KEY is not configured' };
  }
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000);
  if (typeof timeoutId.unref === 'function') {
    timeoutId.unref();
  }
  try {
    const res = await fetch('https://api.brevo.com/v3/account', {
      method: 'GET',
      headers: {
        'api-key': apiKey,
        'accept': 'application/json',
      },
      signal: controller.signal,
    });
    return { ok: res.ok, status: res.status };
  } catch (err) {
    return { ok: false, error: err.message };
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = {
  sendMail,
  verifyEmailService,
  verifySmtp: verifyEmailService,
};
