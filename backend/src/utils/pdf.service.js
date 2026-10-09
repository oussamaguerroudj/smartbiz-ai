const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const FONT_REGULAR_PATH = path.join(__dirname, '../assets/fonts/Cairo-Regular.ttf');
const FONT_BOLD_PATH = path.join(__dirname, '../assets/fonts/Cairo-Bold.ttf');

function createPdfDoc() {
  const doc = new PDFDocument({ size: 'A4', margin: 50 });
  let fontRegular = 'Helvetica';
  let fontBold = 'Helvetica-Bold';
  if (fs.existsSync(FONT_REGULAR_PATH) && fs.existsSync(FONT_BOLD_PATH)) {
    try {
      doc.registerFont('Cairo', FONT_REGULAR_PATH);
      doc.registerFont('Cairo-Bold', FONT_BOLD_PATH);
      fontRegular = 'Cairo';
      fontBold = 'Cairo-Bold';
    } catch (_) {
      fontRegular = 'Helvetica';
      fontBold = 'Helvetica-Bold';
    }
  }
  return { doc, fontRegular, fontBold };
}

// This app's invoices module had a deliberate placeholder
// (invoices.controller.pdfPlaceholder: "PDF generation ... deliberately
// deferred to a dedicated batch"). This file is that dedicated batch
// for the Clinic module specifically (prescriptions + clinic invoices —
// Ch. 7/9/25), built as a small shared utility rather than duplicated
// per-document-type layout code, so the generic invoices module can
// adopt the same PDFDocument-based approach later instead of
// reinventing it.
//
// A4 = 595.28 x 841.89 pt at 72dpi (pdfkit's 'A4' size does this for us).

function money(amount) {
  return `${Number(amount).toFixed(0)} DZD`;
}

function formatDate(date) {
  const d = new Date(date);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function safeFilename(raw, fallback = 'document') {
  const cleaned = String(raw || fallback).replace(/[^a-zA-Z0-9._-]/g, '_');
  return cleaned.length > 0 ? cleaned.slice(0, 120) : fallback;
}

function drawHeader(doc, company, fontRegular = 'Helvetica', fontBold = 'Helvetica-Bold') {
  doc.fontSize(18).font(fontBold).text(company.name || '', { align: 'left' });
  doc.fontSize(9).font(fontRegular).fillColor('#555');
  if (company.address) doc.text(company.address);
  if (company.phone) doc.text(company.phone);
  doc.fillColor('#000');
  doc.moveDown(1);
  doc.moveTo(doc.page.margins.left, doc.y)
    .lineTo(doc.page.width - doc.page.margins.right, doc.y)
    .strokeColor('#ddd')
    .stroke();
  doc.moveDown(1);
}

/**
 * Ch. 7 — "Print Prescription". Renders directly onto the response
 * stream (no temp file on disk).
 */
function streamPrescriptionPdf(res, { company, patient, prescription }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${safeFilename(prescription.prescription_number, 'prescription')}.pdf"`,
  );
  doc.pipe(res);

  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('Ordonnance / Prescription');
  doc.fontSize(10).font(fontRegular);
  doc.text(`${prescription.prescription_number}    ${formatDate(prescription.issued_at)}`);
  if (prescription.doctor_name) doc.text(`Dr. ${prescription.doctor_name}`);
  doc.moveDown(0.5);
  doc.text(`Patient: ${patient.full_name}`);
  if (patient.phone) doc.text(patient.phone);
  doc.moveDown(1);

  for (const item of prescription.items) {
    doc.font(fontBold).fontSize(11).text(`•  ${item.medication_name}`);
    const details = [item.dosage, item.frequency, item.duration].filter(Boolean).join('  ·  ');
    doc.font(fontRegular).fontSize(9).fillColor('#555');
    if (details) doc.text(`   ${details}`);
    if (item.instructions) doc.text(`   ${item.instructions}`);
    doc.fillColor('#000');
    doc.moveDown(0.5);
  }

  if (prescription.notes) {
    doc.moveDown(0.5);
    doc.font(fontBold).fontSize(10).text('Notes');
    doc.font(fontRegular).fontSize(9).text(prescription.notes);
  }

  doc.moveDown(3);
  const signatureY = doc.y;
  doc.font(fontRegular).fontSize(9).text('Signature', doc.page.width - doc.page.margins.right - 150, signatureY);
  doc.moveTo(doc.page.width - doc.page.margins.right - 150, signatureY + 30)
    .lineTo(doc.page.width - doc.page.margins.right, signatureY + 30)
    .strokeColor('#aaa')
    .stroke();

  doc.end();
}

/**
 * Ch. 9 — "Print Clinic Invoice". amounts are all taken verbatim from
 * the same computed invoice view the JSON endpoint returns (built in
 * clinic.service.getVisitInvoice) — this function does no calculation
 * of its own, so the printed total can never drift from the
 * backend-calculated one (Ch. 9: "Never calculate important financial
 * totals differently in the frontend and backend" — extended here to
 * mean "differently in the JSON view and the PDF view" too).
 */
function streamClinicInvoicePdf(res, { company, invoice }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(invoice.invoiceNumber, 'clinic-invoice')}.pdf"`);
  doc.pipe(res);

  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('Facture / Invoice');
  doc.fontSize(10).font(fontRegular);
  doc.text(`${invoice.invoiceNumber}    ${formatDate(invoice.date)}`);
  doc.moveDown(0.5);
  doc.text(`Patient: ${invoice.patient.fullName}`);
  if (invoice.patient.phone) doc.text(invoice.patient.phone);
  doc.moveDown(1);

  const tableTop = doc.y;
  doc.font(fontBold).fontSize(10);
  doc.text('Service', 50, tableTop);
  doc.text('Amount', 400, tableTop, { width: 145, align: 'right' });
  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#ddd').stroke();
  doc.moveDown(0.3);

  doc.font(fontRegular).fontSize(10);
  doc.text(invoice.serviceLabel, 50, doc.y);
  doc.text(money(invoice.consultationPrice), 400, doc.y - doc.currentLineHeight(), {
    width: 145,
    align: 'right',
  });
  doc.moveDown(1.5);

  const summaryX = 350;
  const line = (label, value, bold = false) => {
    doc.font(bold ? fontBold : fontRegular).fontSize(10);
    doc.text(label, summaryX, doc.y, { width: 100 });
    doc.text(value, summaryX + 100, doc.y - doc.currentLineHeight(), { width: 95, align: 'right' });
  };
  line('Subtotal', money(invoice.consultationPrice));
  line('Paid', money(invoice.amountPaid));
  line('Remaining', money(invoice.remaining), true);
  doc.moveDown(0.5);
  doc.font(fontBold).text(`Status: ${invoice.paymentStatus}`, summaryX, doc.y);

  doc.end();
}

/**
 * Ch. 9-equivalent for Restaurant — "Print Clinic Invoice" section's
 * amounts-from-one-source rule generalized: this itemized table comes
 * straight from invoice.items, which restaurant.service.getOrderInvoice
 * copies verbatim from restaurant_order_items — no recalculation here.
 */
function streamRestaurantInvoicePdf(res, { company, invoice }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(invoice.invoiceNumber, 'restaurant-invoice')}.pdf"`);
  doc.pipe(res);

  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('Facture / Invoice');
  doc.fontSize(10).font(fontRegular);
  doc.text(`${invoice.invoiceNumber}    ${formatDate(invoice.date)}`);
  if (invoice.orderType) doc.text(`Type: ${invoice.orderType === 'delivery' ? 'Livraison / Delivery' : 'Sur Place / Dine-in'}`);
  if (invoice.tableName) doc.text(`Table: ${invoice.tableName}`);
  if (invoice.customerName) doc.text(`Client: ${invoice.customerName}`);
  if (invoice.customerPhone) doc.text(`Tél / Phone: ${invoice.customerPhone}`);
  if (invoice.deliveryAddress) doc.text(`Adresse / Address: ${invoice.deliveryAddress}`);
  doc.moveDown(1);

  const tableTop = doc.y;
  doc.font(fontBold).fontSize(10);
  doc.text('Item', 50, tableTop);
  doc.text('Qty', 300, tableTop, { width: 60, align: 'right' });
  doc.text('Unit', 360, tableTop, { width: 80, align: 'right' });
  doc.text('Subtotal', 445, tableTop, { width: 100, align: 'right' });
  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#ddd').stroke();
  doc.moveDown(0.3);

  doc.font(fontRegular).fontSize(10);
  for (const item of invoice.items) {
    const rowY = doc.y;
    doc.text(item.itemName, 50, rowY, { width: 240 });
    doc.text(String(item.quantity), 300, rowY, { width: 60, align: 'right' });
    doc.text(money(item.unitPrice), 360, rowY, { width: 80, align: 'right' });
    doc.text(money(item.subtotal), 445, rowY, { width: 100, align: 'right' });
    doc.moveDown(0.4);
  }
  doc.moveDown(1);

  const summaryX = 350;
  const line = (label, value, bold = false) => {
    doc.font(bold ? fontBold : fontRegular).fontSize(10);
    doc.text(label, summaryX, doc.y, { width: 100 });
    doc.text(value, summaryX + 100, doc.y - doc.currentLineHeight(), { width: 95, align: 'right' });
  };
  line('Total', money(invoice.totalAmount));
  line('Paid', money(invoice.amountPaid));
  line('Remaining', money(invoice.remaining), true);
  doc.moveDown(0.5);
  doc.font(fontBold).text(`Status: ${invoice.paymentStatus}`, summaryX, doc.y);

  doc.end();
}

function streamStandardInvoicePdf(res, { company, invoice }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(invoice.invoice_number, 'invoice')}.pdf"`);
  doc.pipe(res);

  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('Facture / Invoice');
  doc.fontSize(10).font(fontRegular);
  doc.text(`${invoice.invoice_number || ''}    ${formatDate(invoice.created_at || invoice.sold_at || new Date())}`);
  if (invoice.customer_name) {
    doc.moveDown(0.5);
    doc.text(`Client / Customer: ${invoice.customer_name}`);
    if (invoice.customer_phone) doc.text(invoice.customer_phone);
  }
  doc.moveDown(1);

  const tableTop = doc.y;
  doc.font(fontBold).fontSize(10);
  doc.text('Article / Item', 50, tableTop);
  doc.text('Qty', 300, tableTop, { width: 60, align: 'right' });
  doc.text('Unit', 360, tableTop, { width: 80, align: 'right' });
  doc.text('Total', 445, tableTop, { width: 100, align: 'right' });
  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#ddd').stroke();
  doc.moveDown(0.3);

  doc.font(fontRegular).fontSize(10);
  const items = invoice.items || [];
  for (const item of items) {
    const rowY = doc.y;
    doc.text(item.product_name || item.name || 'Item', 50, rowY, { width: 240 });
    doc.text(String(item.quantity || 1), 300, rowY, { width: 60, align: 'right' });
    doc.text(money(item.unit_price || 0), 360, rowY, { width: 80, align: 'right' });
    doc.text(money(item.line_total || 0), 445, rowY, { width: 100, align: 'right' });
    doc.moveDown(0.4);
  }
  doc.moveDown(1);

  const summaryX = 350;
  const line = (label, value, bold = false) => {
    doc.font(bold ? fontBold : fontRegular).fontSize(10);
    doc.text(label, summaryX, doc.y, { width: 100 });
    doc.text(value, summaryX + 100, doc.y - doc.currentLineHeight(), { width: 95, align: 'right' });
  };
  if (invoice.subtotal && Number(invoice.subtotal) !== Number(invoice.total)) {
    line('Subtotal', money(invoice.subtotal));
  }
  if (invoice.discount && Number(invoice.discount) > 0) {
    line('Discount', money(invoice.discount));
  }
  line('Total', money(invoice.total), true);
  doc.moveDown(0.5);
  doc.font(fontBold).text(`Status: ${invoice.status || 'paid'}`, summaryX, doc.y);

  doc.end();
}

module.exports = {
  streamPrescriptionPdf,
  streamClinicInvoicePdf,
  streamRestaurantInvoicePdf,
  streamStandardInvoicePdf,
};
