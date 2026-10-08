const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT i.*,
            COALESCE(s.total, ro.total_amount, 0) AS total,
            COALESCE(s.sold_at, ro.completed_at, ro.created_at) AS sold_at,
            COALESCE(c.name, ro.customer_name) AS customer_name
     FROM invoices i
     LEFT JOIN sales s
       ON s.id = i.sale_id
      AND s.company_id = i.company_id
     LEFT JOIN restaurant_orders ro
       ON ro.id = i.order_id
      AND ro.company_id = i.company_id
     LEFT JOIN customers c
       ON c.id = s.customer_id
      AND c.company_id = i.company_id
     WHERE i.company_id = $1
     ORDER BY i.created_at DESC`,
    [companyId],
  );

  return result.rows;
}

async function findById(companyId, id) {
  const invoiceResult = await query(
    `SELECT i.*, 
            COALESCE(s.total, ro.total_amount, 0) AS total,
            COALESCE(s.subtotal, ro.total_amount, 0) AS subtotal,
            COALESCE(s.discount, 0) AS discount,
            COALESCE(s.sold_at, ro.completed_at, ro.created_at) AS sold_at,
            COALESCE(c.name, ro.customer_name) AS customer_name,
            COALESCE(c.phone, ro.customer_phone) AS customer_phone
     FROM invoices i
     LEFT JOIN sales s
       ON s.id = i.sale_id
      AND s.company_id = i.company_id
     LEFT JOIN restaurant_orders ro
       ON ro.id = i.order_id
      AND ro.company_id = i.company_id
     LEFT JOIN customers c
       ON c.id = s.customer_id
      AND c.company_id = i.company_id
     WHERE i.company_id = $1
       AND i.id = $2`,
    [companyId, id],
  );

  const invoice = invoiceResult.rows[0];

  if (!invoice) {
    return null;
  }

  let items = [];
  if (invoice.sale_id) {
    const itemsResult = await query(
      `SELECT si.quantity,
              si.unit_price,
              si.line_total,
              p.name AS product_name
       FROM sale_items si
       JOIN products p
         ON p.id = si.product_id
        AND p.company_id = $1
       WHERE si.sale_id = $2`,
      [companyId, invoice.sale_id],
    );
    items = itemsResult.rows;
  } else if (invoice.order_id) {
    const itemsResult = await query(
      `SELECT roi.quantity,
              roi.unit_price,
              roi.subtotal AS line_total,
              roi.item_name AS product_name
       FROM restaurant_order_items roi
       WHERE roi.company_id = $1 AND roi.order_id = $2`,
      [companyId, invoice.order_id],
    );
    items = itemsResult.rows;
  }

  return {
    ...invoice,
    items,
  };
}

async function updateStatus(companyId, id, status) {
  const result = await query(
    `UPDATE invoices
     SET status = $3
     WHERE company_id = $1
       AND id = $2
     RETURNING *`,
    [companyId, id, status],
  );

  const invoice = result.rows[0];
  if (invoice && status === 'paid') {
    if (invoice.sale_id) {
      await query(
        `UPDATE sales
         SET payment_status = 'paid', updated_at = now()
         WHERE company_id = $1 AND id = $2`,
        [companyId, invoice.sale_id],
      );
    } else if (invoice.order_id) {
      await query(
        `UPDATE restaurant_orders
         SET payment_status = 'paid', amount_paid = total_amount, updated_at = now()
         WHERE company_id = $1 AND id = $2`,
        [companyId, invoice.order_id],
      );
    }
  }

  return invoice || null;
}

module.exports = {
  findAll,
  findById,
  updateStatus,
};