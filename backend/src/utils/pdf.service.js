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

function formatPdfText(text) {
  if (!text || typeof text !== 'string') return '';
  return text;
}

function drawHeader(doc, company, fontRegular = 'Helvetica', fontBold = 'Helvetica-Bold') {
  doc.fontSize(18).font(fontBold).text(formatPdfText(company.name) || '', { align: 'left' });
  doc.fontSize(9).font(fontRegular).fillColor('#555');
  if (company.address) doc.text(formatPdfText(company.address));
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
  if (prescription.doctor_name) doc.text(`Dr. ${formatPdfText(prescription.doctor_name)}`);
  doc.moveDown(0.5);
  doc.text(`Patient: ${formatPdfText(patient.full_name)}`);
  if (patient.phone) doc.text(patient.phone);
  doc.moveDown(1);

  for (const item of prescription.items) {
    doc.font(fontBold).fontSize(11).text(`•  ${formatPdfText(item.medication_name)}`);
    const details = [item.dosage, item.frequency, item.duration].filter(Boolean).map(formatPdfText).join('  ·  ');
    doc.font(fontRegular).fontSize(9).fillColor('#555');
    if (details) doc.text(`   ${details}`);
    if (item.instructions) doc.text(`   ${formatPdfText(item.instructions)}`);
    doc.fillColor('#000');
    doc.moveDown(0.5);
  }

  if (prescription.notes) {
    doc.moveDown(0.5);
    doc.font(fontBold).fontSize(10).text('Notes');
    doc.font(fontRegular).fontSize(9).text(formatPdfText(prescription.notes));
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
  doc.text(`Patient: ${formatPdfText(invoice.patient.fullName)}`);
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
  doc.text(formatPdfText(invoice.serviceLabel), 50, doc.y);
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
  if (invoice.customerName) doc.text(`Client: ${formatPdfText(invoice.customerName)}`);
  if (invoice.customerPhone) doc.text(`Tél / Phone: ${invoice.customerPhone}`);
  if (invoice.deliveryAddress) doc.text(`Adresse / Address: ${formatPdfText(invoice.deliveryAddress)}`);
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
    doc.text(formatPdfText(item.itemName), 50, rowY, { width: 240 });
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

function renderStandardInvoiceDoc(doc, { company, invoice }, fontRegular, fontBold) {
  drawHeader(doc, company, fontRegular, fontBold);

  const isPaid = (invoice.status || '').toLowerCase() === 'paid';
  const statusLabel = isPaid ? 'FACTURE ACQUITTÉE / RECEIPT (PAID)' : 'FACTURE NON ACQUITTÉE / PROFORMA INVOICE';
  const statusColor = isPaid ? '#2e7d32' : '#c62828';

  doc.fontSize(14).font(fontBold).fillColor(statusColor).text(statusLabel);
  doc.fillColor('#000');
  doc.fontSize(10).font(fontRegular);
  doc.text(`${invoice.invoice_number || ''}    ${formatDate(invoice.created_at || invoice.sold_at || new Date())}`);
  if (invoice.customer_name) {
    doc.moveDown(0.5);
    doc.text(`Client / Customer: ${formatPdfText(invoice.customer_name)}`);
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
    doc.text(formatPdfText(item.product_name || item.name || 'Item'), 50, rowY, { width: 240 });
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
  doc.font(fontBold).fillColor(statusColor).text(`Statut: ${isPaid ? 'ACQUITTÉE (PAID)' : 'NON ACQUITTÉE (UNPAID / PROFORMA)'}`, summaryX, doc.y);
  doc.fillColor('#000');

  doc.end();
}

function streamStandardInvoicePdf(res, { company, invoice }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(invoice.invoice_number, 'invoice')}.pdf"`);
  doc.pipe(res);
  renderStandardInvoiceDoc(doc, { company, invoice }, fontRegular, fontBold);
}

function generateStandardInvoicePdfBuffer({ company, invoice }) {
  return new Promise((resolve, reject) => {
    const { doc, fontRegular, fontBold } = createPdfDoc();
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    renderStandardInvoiceDoc(doc, { company, invoice }, fontRegular, fontBold);
  });
}

/**
 * Restaurant Kitchen Ticket (KOT / Bon de Commande Cuisine).
 * Pure operational document without financial totals or pricing.
 */
function renderKitchenTicketDoc(doc, { company, order, items }, fontRegular, fontBold) {
  doc.fontSize(16).font(fontBold).text(formatPdfText(company.name) || 'Restaurant', { align: 'center' });
  doc.moveDown(0.3);
  doc.fontSize(14).font(fontBold).fillColor('#c62828').text('*** BON DE CUISINE / KITCHEN TICKET ***', { align: 'center' });
  doc.fillColor('#000');
  doc.moveDown(0.5);

  doc.moveTo(doc.page.margins.left, doc.y)
    .lineTo(doc.page.width - doc.page.margins.right, doc.y)
    .strokeColor('#333')
    .lineWidth(2)
    .stroke();
  doc.lineWidth(1);
  doc.moveDown(0.5);

  const orderNumStr = `#${order.order_number || (order.id ? String(order.id).slice(0, 8) : '')}`;
  doc.fontSize(20).font(fontBold).text(`COMMANDE ${orderNumStr}`);
  doc.fontSize(10).font(fontRegular);
  doc.text(`Date & Heure: ${new Date(order.created_at || Date.now()).toLocaleString()}`);

  const typeLabel = order.order_type === 'delivery'
    ? 'LIVRAISON / DELIVERY'
    : (order.order_type === 'takeaway' ? 'À EMPORTER / TAKEAWAY' : 'SUR PLACE / DINE-IN');
  doc.font(fontBold).fontSize(12).text(`Type: ${typeLabel}`);

  const tableName = order.tableName || order.table_name;
  if (tableName) {
    doc.text(`Table: ${formatPdfText(tableName)}`);
  }
  const custName = order.customer_name || order.customerName;
  if (custName) {
    doc.text(`Client: ${formatPdfText(custName)}`);
  }
  const custPhone = order.customer_phone || order.customerPhone;
  if (custPhone) {
    doc.text(`Tél: ${formatPdfText(custPhone)}`);
  }
  const deliveryAddr = order.delivery_address || order.deliveryAddress;
  if (deliveryAddr) {
    doc.text(`Adresse: ${formatPdfText(deliveryAddr)}`);
  }
  if (order.notes) {
    doc.moveDown(0.5);
    doc.fontSize(11).font(fontBold).fillColor('#c62828').text(`NOTE / INSTRUCTIONS: ${formatPdfText(order.notes)}`);
    doc.fillColor('#000');
  }

  doc.moveDown(1);
  const tableTop = doc.y;
  doc.fontSize(12).font(fontBold);
  doc.text('QTÉ', 50, tableTop, { width: 60 });
  doc.text('ARTICLE / INGRÉDIENTS / NOTES', 120, tableTop, { width: 400 });
  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#333').lineWidth(1.5).stroke();
  doc.lineWidth(1);
  doc.moveDown(0.5);

  const orderItems = items || order.items || [];
  for (const it of orderItems) {
    const rowY = doc.y;
    doc.font(fontBold).fontSize(14).text(`${it.quantity}x`, 50, rowY, { width: 60 });
    doc.font(fontBold).fontSize(12).text(formatPdfText(it.itemName || it.item_name || it.name || 'Article'), 120, rowY, { width: 400 });
    if (it.notes) {
      doc.font(fontRegular).fontSize(10).fillColor('#666').text(`  -> ${formatPdfText(it.notes)}`, 130, doc.y);
      doc.fillColor('#000');
    }
    doc.moveDown(0.8);
  }

  doc.moveDown(1.5);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#888').stroke();
  doc.moveDown(0.5);
  doc.fontSize(9).font(fontRegular).fillColor('#666').text('Transmission directe au poste cuisine — Document interne sans valeur financière.', { align: 'center' });
  doc.fillColor('#000');
  doc.end();
}

function streamKitchenTicketPdf(res, { company, order, items }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(`kitchen-ticket-${order.order_number || order.id}`)}.pdf"`);
  doc.pipe(res);
  renderKitchenTicketDoc(doc, { company, order, items }, fontRegular, fontBold);
}

function generateKitchenTicketPdfBuffer({ company, order, items }) {
  return new Promise((resolve, reject) => {
    const { doc, fontRegular, fontBold } = createPdfDoc();
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    renderKitchenTicketDoc(doc, { company, order, items }, fontRegular, fontBold);
  });
}

/**
 * Supplier Account Statement (Relevé Fournisseur).
 * Displays AP ledger, purchases, payments, and running balance.
 */
function renderSupplierStatementDoc(doc, { company, supplier, statement }, fontRegular, fontBold) {
  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('RELEVÉ DE COMPTE FOURNISSEUR / SUPPLIER STATEMENT');
  doc.fontSize(10).font(fontRegular);
  doc.text(`Date d'émission: ${formatDate(new Date())}`);
  doc.moveDown(0.5);

  doc.font(fontBold).fontSize(11).text(`Fournisseur: ${formatPdfText(supplier.name)}`);
  doc.font(fontRegular).fontSize(10);
  if (supplier.phone) doc.text(`Téléphone: ${supplier.phone}`);
  if (supplier.address) doc.text(`Adresse: ${formatPdfText(supplier.address)}`);
  doc.moveDown(1);

  // 3 KPI Boxes
  const kpiTop = doc.y;
  const boxWidth = 150;
  const boxHeight = 50;

  doc.rect(50, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('TOTAL FACTURÉ / ACHATS', 55, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor('#000').font(fontBold).fontSize(12).text(money(statement.totalPurchases || 0), 55, kpiTop + 24, { width: boxWidth - 10 });

  doc.rect(210, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('TOTAL RÉGLÉ / PAYÉ', 215, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor('#2e7d32').font(fontBold).fontSize(12).text(money(statement.totalPaid || 0), 215, kpiTop + 24, { width: boxWidth - 10 });

  const balanceDue = Number(statement.balanceDue || 0);
  const balColor = balanceDue > 0 ? '#c62828' : '#2e7d32';
  doc.rect(370, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('SOLDE RESTANT DÛ', 375, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor(balColor).font(fontBold).fontSize(12).text(money(balanceDue), 375, kpiTop + 24, { width: boxWidth - 10 });
  doc.fillColor('#000');

  doc.y = kpiTop + boxHeight + 20;

  // Transactions Ledger Table
  doc.font(fontBold).fontSize(10);
  const tableTop = doc.y;
  doc.text('Date', 50, tableTop, { width: 70 });
  doc.text('Opération / Réf', 125, tableTop, { width: 155 });
  doc.text('Débit (+Achats)', 285, tableTop, { width: 85, align: 'right' });
  doc.text('Crédit (-Paiements)', 375, tableTop, { width: 85, align: 'right' });
  doc.text('Solde Dû', 465, tableTop, { width: 80, align: 'right' });

  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#bbb').stroke();
  doc.moveDown(0.3);

  const transactions = statement.transactions || [];
  doc.font(fontRegular).fontSize(9);
  for (const tx of transactions) {
    if (doc.y > 750) {
      doc.addPage();
      drawHeader(doc, company, fontRegular, fontBold);
      doc.font(fontBold).fontSize(10);
      const nextTableTop = doc.y;
      doc.text('Date', 50, nextTableTop, { width: 70 });
      doc.text('Opération / Réf', 125, nextTableTop, { width: 155 });
      doc.text('Débit (+Achats)', 285, nextTableTop, { width: 85, align: 'right' });
      doc.text('Crédit (-Paiements)', 375, nextTableTop, { width: 85, align: 'right' });
      doc.text('Solde Dû', 465, nextTableTop, { width: 80, align: 'right' });
      doc.moveDown(0.3);
      doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#bbb').stroke();
      doc.moveDown(0.3);
      doc.font(fontRegular).fontSize(9);
    }

    const rowY = doc.y;
    doc.text(formatDate(tx.date), 50, rowY, { width: 70 });
    doc.text(formatPdfText(tx.description || tx.reference || tx.type), 125, rowY, { width: 155 });
    doc.text(tx.debit ? money(tx.debit) : '-', 285, rowY, { width: 85, align: 'right' });
    doc.text(tx.credit ? money(tx.credit) : '-', 375, rowY, { width: 85, align: 'right' });
    doc.text(money(tx.balanceAfter), 465, rowY, { width: 80, align: 'right' });
    doc.moveDown(0.5);
  }

  doc.moveDown(2);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#ddd').stroke();
  doc.moveDown(0.5);
  doc.fontSize(8).font(fontRegular).fillColor('#666').text('Ce relevé retrace l\'ensemble des mouvements enregistrés avec ce fournisseur. Pour toute réclamation, veuillez contacter le service comptabilité.', { align: 'center' });
  doc.fillColor('#000');
  doc.end();
}

function streamSupplierStatementPdf(res, { company, supplier, statement }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(`supplier-statement-${supplier.name || supplier.id}`)}.pdf"`);
  doc.pipe(res);
  renderSupplierStatementDoc(doc, { company, supplier, statement }, fontRegular, fontBold);
}

function generateSupplierStatementPdfBuffer({ company, supplier, statement }) {
  return new Promise((resolve, reject) => {
    const { doc, fontRegular, fontBold } = createPdfDoc();
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    renderSupplierStatementDoc(doc, { company, supplier, statement }, fontRegular, fontBold);
  });
}

/**
 * Customer Credit Statement (Relevé Crédit Client).
 * Displays customer credit purchases, repayments, and running debt balance.
 */
function renderCustomerCreditStatementDoc(doc, { company, customer, statement }, fontRegular, fontBold) {
  drawHeader(doc, company, fontRegular, fontBold);

  doc.fontSize(14).font(fontBold).text('RELEVÉ DE CRÉDIT CLIENT / CUSTOMER CREDIT STATEMENT');
  doc.fontSize(10).font(fontRegular);
  doc.text(`Date d'émission: ${formatDate(new Date())}`);
  doc.moveDown(0.5);

  doc.font(fontBold).fontSize(11).text(`Client: ${formatPdfText(customer.name)}`);
  doc.font(fontRegular).fontSize(10);
  if (customer.phone) doc.text(`Téléphone: ${customer.phone}`);
  if (customer.address) doc.text(`Adresse: ${formatPdfText(customer.address)}`);
  doc.moveDown(1);

  // 3 KPI Boxes
  const kpiTop = doc.y;
  const boxWidth = 150;
  const boxHeight = 50;

  doc.rect(50, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('TOTAL CRÉDIT ACCORDÉ', 55, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor('#000').font(fontBold).fontSize(12).text(money(statement.totalCredit || 0), 55, kpiTop + 24, { width: boxWidth - 10 });

  doc.rect(210, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('TOTAL RÈGLEMENTS REÇUS', 215, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor('#2e7d32').font(fontBold).fontSize(12).text(money(statement.totalPaid || 0), 215, kpiTop + 24, { width: boxWidth - 10 });

  const balanceDue = Number(statement.currentBalance || 0);
  const balColor = balanceDue > 0 ? '#c62828' : '#2e7d32';
  doc.rect(370, kpiTop, boxWidth, boxHeight).fillColor('#f5f5f5').fill().strokeColor('#ddd').stroke();
  doc.fillColor('#555').font(fontRegular).fontSize(9).text('SOLDE DÛ ACTUEL', 375, kpiTop + 8, { width: boxWidth - 10 });
  doc.fillColor(balColor).font(fontBold).fontSize(12).text(money(balanceDue), 375, kpiTop + 24, { width: boxWidth - 10 });
  doc.fillColor('#000');

  doc.y = kpiTop + boxHeight + 20;

  // Transactions Table
  doc.font(fontBold).fontSize(10);
  const tableTop = doc.y;
  doc.text('Date', 50, tableTop, { width: 70 });
  doc.text('Opération / Description', 125, tableTop, { width: 155 });
  doc.text('Débit (+Dette)', 285, tableTop, { width: 85, align: 'right' });
  doc.text('Crédit (-Paiement)', 375, tableTop, { width: 85, align: 'right' });
  doc.text('Solde Dû', 465, tableTop, { width: 80, align: 'right' });

  doc.moveDown(0.3);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#bbb').stroke();
  doc.moveDown(0.3);

  const transactions = statement.transactions || [];
  doc.font(fontRegular).fontSize(9);
  for (const tx of transactions) {
    if (doc.y > 750) {
      doc.addPage();
      drawHeader(doc, company, fontRegular, fontBold);
      doc.font(fontBold).fontSize(10);
      const nextTableTop = doc.y;
      doc.text('Date', 50, nextTableTop, { width: 70 });
      doc.text('Opération / Description', 125, nextTableTop, { width: 155 });
      doc.text('Débit (+Dette)', 285, nextTableTop, { width: 85, align: 'right' });
      doc.text('Crédit (-Paiement)', 375, nextTableTop, { width: 85, align: 'right' });
      doc.text('Solde Dû', 465, nextTableTop, { width: 80, align: 'right' });
      doc.moveDown(0.3);
      doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#bbb').stroke();
      doc.moveDown(0.3);
      doc.font(fontRegular).fontSize(9);
    }

    const rowY = doc.y;
    doc.text(formatDate(tx.created_at || tx.date), 50, rowY, { width: 70 });
    doc.text(formatPdfText(tx.description || tx.type), 125, rowY, { width: 155 });
    const isCredit = Number(tx.amount) < 0;
    const debitVal = !isCredit ? Math.abs(Number(tx.amount)) : null;
    const creditVal = isCredit ? Math.abs(Number(tx.amount)) : null;

    doc.text(debitVal ? money(debitVal) : '-', 285, rowY, { width: 85, align: 'right' });
    doc.text(creditVal ? money(creditVal) : '-', 375, rowY, { width: 85, align: 'right' });
    doc.text(money(tx.balance_after || tx.balanceAfter || 0), 465, rowY, { width: 80, align: 'right' });
    doc.moveDown(0.5);
  }

  doc.moveDown(2);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#ddd').stroke();
  doc.moveDown(0.5);
  doc.fontSize(8).font(fontRegular).fillColor('#666').text('Relevé de compte client certifié exact par l\'établissement émetteur.', { align: 'center' });
  doc.fillColor('#000');
  doc.end();
}

function streamCustomerCreditStatementPdf(res, { company, customer, statement }) {
  const { doc, fontRegular, fontBold } = createPdfDoc();
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${safeFilename(`credit-statement-${customer.name || customer.id}`)}.pdf"`);
  doc.pipe(res);
  renderCustomerCreditStatementDoc(doc, { company, customer, statement }, fontRegular, fontBold);
}

function generateCustomerCreditStatementPdfBuffer({ company, customer, statement }) {
  return new Promise((resolve, reject) => {
    const { doc, fontRegular, fontBold } = createPdfDoc();
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    renderCustomerCreditStatementDoc(doc, { company, customer, statement }, fontRegular, fontBold);
  });
}

module.exports = {
  streamPrescriptionPdf,
  streamClinicInvoicePdf,
  streamRestaurantInvoicePdf,
  streamStandardInvoicePdf,
  generateStandardInvoicePdfBuffer,
  streamKitchenTicketPdf,
  generateKitchenTicketPdfBuffer,
  streamSupplierStatementPdf,
  generateSupplierStatementPdfBuffer,
  streamCustomerCreditStatementPdf,
  generateCustomerCreditStatementPdfBuffer,
  formatPdfText,
};
