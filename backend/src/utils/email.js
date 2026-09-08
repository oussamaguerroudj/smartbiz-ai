const nodemailer = require('nodemailer');
const env = require('../config/env');

/**
 * Shared SMTP transporter.
 *
 * TLS certificate verification is enabled by default.
 * For local development only, it can be explicitly disabled with:
 *
 * SMTP_REJECT_UNAUTHORIZED=false
 *
 * Never use this setting in production.
 */

const rejectUnauthorized =
  process.env.SMTP_REJECT_UNAUTHORIZED !== 'false';

if (
  env.smtp.user &&
  !env.smtp.pass
) {
  throw new Error(
    'SMTP_PASS is required when SMTP_USER is configured',
  );
}

const transporter = env.smtp.host
  ? nodemailer.createTransport({
      host: env.smtp.host,
      port: env.smtp.port,
      secure: env.smtp.port === 465,

      auth: env.smtp.user
        ? {
            user: env.smtp.user,
            pass: env.smtp.pass,
          }
        : undefined,

      tls: {
        rejectUnauthorized,
      },
    })
  : null;

async function sendMail({ to, subject, html }) {
  if (!transporter) {
    // eslint-disable-next-line no-console
    console.error(
      `[email] SMTP is not configured (SMTP_HOST missing) - ` +
        `cannot send "${subject}" to ${to}. ` +
        'Set SMTP_HOST/PORT/USER/PASS/FROM in .env.',
    );

    throw new Error(
      'Email delivery is not configured on this server',
    );
  }

  if (env.nodeEnv === 'production' && !rejectUnauthorized) {
    throw new Error(
      'SMTP certificate verification cannot be disabled in production',
    );
  }

  if (
    typeof to !== 'string' ||
    to.trim().length === 0
  ) {
    throw new Error('Email recipient is required');
  }

  if (
    typeof subject !== 'string' ||
    subject.trim().length === 0
  ) {
    throw new Error('Email subject is required');
  }

  if (
    typeof html !== 'string' ||
    html.trim().length === 0
  ) {
    throw new Error('Email content is required');
  }

  await transporter.sendMail({
    from: env.smtp.from,
    to: to.trim(),
    subject: subject.trim(),
    html,
  });
}

module.exports = {
  sendMail,
};
