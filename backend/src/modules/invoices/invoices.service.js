const repo = require('./invoices.repository');
const ApiError = require('../../utils/ApiError');
const pdfService = require('../../utils/pdf.service');
const { sendMail } = require('../../utils/email');
const { query } = require('../../config/db');

async function list(companyId) {
  return repo.findAll(companyId);
}

async function getOne(companyId, id) {
  const invoice = await repo.findById(companyId, id);
  if (!invoice) throw ApiError.notFound('Invoice not found');
  return invoice;
}

async function markPaid(companyId, id) {
  const updated = await repo.updateStatus(companyId, id, 'paid');
  if (!updated) throw ApiError.notFound('Invoice not found');
  return updated;
}

async function streamInvoicePdf(res, companyId, id) {
  const [companyRes, invoice] = await Promise.all([
    query('SELECT name, phone, address FROM companies WHERE id = $1', [companyId]),
    getOne(companyId, id),
  ]);
  const company = companyRes.rows[0] || {};
  pdfService.streamStandardInvoicePdf(res, { company, invoice });
}

async function emailInvoice(companyId, id, recipientEmail) {
  if (!recipientEmail || typeof recipientEmail !== 'string' || !recipientEmail.includes('@')) {
    throw ApiError.badRequest('Valid recipient email address is required');
  }
  const [companyRes, invoice] = await Promise.all([
    query('SELECT name, phone, address FROM companies WHERE id = $1', [companyId]),
    getOne(companyId, id),
  ]);
  const company = companyRes.rows[0] || {};
  const pdfBuffer = await pdfService.generateStandardInvoicePdfBuffer({ company, invoice });
  const companyName = company.name || 'Modiri AI';
  const invoiceNumber = invoice.invoice_number || id;

  const subject = `Facture / Invoice ${invoiceNumber} - ${companyName}`;
  const html = `
    <div style="font-family: sans-serif; padding: 20px; color: #333;">
      <h2 style="color: #2563eb;">${companyName}</h2>
      <p>Bonjour,</p>
      <p>Veuillez trouver ci-joint votre facture <strong>${invoiceNumber}</strong> d'un montant total de <strong>${invoice.total || 0} DZD</strong>.</p>
      <p>Merci pour votre confiance !</p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
      <small style="color: #888;">Généré par Modiri AI</small>
    </div>
  `;

  await sendMail({
    to: recipientEmail.trim(),
    subject,
    html,
    attachments: [
      {
        content: pdfBuffer.toString('base64'),
        name: `${invoiceNumber}.pdf`,
      },
    ],
  });

  return { ok: true, recipient: recipientEmail.trim() };
}

module.exports = { list, getOne, markPaid, streamInvoicePdf, emailInvoice };
