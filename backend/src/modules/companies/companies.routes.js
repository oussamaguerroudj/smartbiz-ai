const express = require('express');
const bcrypt = require('bcryptjs');
const { query, withTransaction } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware, requireRole } = require('../../middlewares/auth.middleware');

/**
 * Companies  -  one row per tenant.
 *
 * The authenticated user's companyId is always taken from the
 * verified JWT through req.user.companyId.
 *
 * IMPORTANT:
 * Never accept companyId from req.body, req.query, or req.params.
 */
// Ch. 1/16  -  SPECIALIZED BUSINESS CONTENT: matches business_type_enum
// after migration 016. Every value here works fully at the CORE level
// regardless of whether a dedicated specialized module (clinic_*,
// restaurant_*, ...) exists for it yet  -  see backend/SPECIALIZED_MODULES.md
// for which verticals currently have one.
const VALID_TYPES = [
  'clothing',
  'grocery',
  'pharmacy',
  'clinic',
  'restaurant',
  'company',
  'workshop',
  'retail_store',
  'cafe',
  'beauty_salon',
  'barbershop',
  'gym',
  'hotel',
  'dental_clinic',
  'medical_laboratory',
  'car_repair',
  'electronics_store',
  'supermarket',
  'bakery',
  'law_office',
  'accounting_office',
  'real_estate_agency',
  'education_center',
  'other',
];

const COMPANY_SELECT = `
  id,
  name,
  business_type,
  onboarding_completed,
  currency,
  phone,
  address,
  created_at,
  updated_at
`;

function formatCompanyResponse(row) {
  return {
    id: row.id,
    name: row.name,
    businessType: row.business_type || null,
    business_type: row.business_type || null,
    onboardingCompleted: row.onboarding_completed === true,
    onboarding_completed: row.onboarding_completed === true,
    currency: row.currency,
    phone: row.phone || null,
    address: row.address || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function validateOptionalString(value, fieldName, { minLength = 1, maxLength = 255 } = {}) {
  if (value === undefined) {
    return;
  }

  if (typeof value !== 'string') {
    throw ApiError.badRequest(
      `${fieldName} must be a string`,
      'VALIDATION_ERROR',
    );
  }

  const trimmed = value.trim();

  if (trimmed.length < minLength) {
    throw ApiError.badRequest(
      `${fieldName} must be at least ${minLength} character${minLength === 1 ? '' : 's'}`,
      'VALIDATION_ERROR',
    );
  }

  if (trimmed.length > maxLength) {
    throw ApiError.badRequest(
      `${fieldName} must not exceed ${maxLength} characters`,
      'VALIDATION_ERROR',
    );
  }
}

const getMe = asyncHandler(async (req, res) => {
  const result = await query(
    `SELECT ${COMPANY_SELECT}
     FROM companies
     WHERE id = $1`,
    [req.user.companyId],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('Company not found');
  }

  return res.json({
    data: formatCompanyResponse(result.rows[0]),
  });
});

const updateMe = asyncHandler(async (req, res) => {
  const body = req.body || {};

  const {
    name,
    businessType,
    currency,
    phone,
    address,
  } = body;

  /*
   * Validate only fields that are actually supplied.
   */
  validateOptionalString(name, 'name', {
    minLength: 2,
    maxLength: 255,
  });

  validateOptionalString(currency, 'currency', {
    minLength: 1,
    maxLength: 10,
  });

  validateOptionalString(phone, 'phone', {
    minLength: 3,
    maxLength: 50,
  });

  validateOptionalString(address, 'address', {
    minLength: 1,
    maxLength: 500,
  });

  if (
    businessType !== undefined &&
    (typeof businessType !== 'string' ||
      !VALID_TYPES.includes(businessType.trim()))
  ) {
    throw ApiError.badRequest(
      `businessType must be one of: ${VALID_TYPES.join(', ')}`,
      'VALIDATION_ERROR',
    );
  }

  const willCompleteOnboarding = businessType !== undefined;
  const result = await query(
    `UPDATE companies
     SET
       name = COALESCE($2, name),
       business_type = COALESCE($3, business_type),
       currency = COALESCE($4, currency),
       phone = COALESCE($5, phone),
       address = COALESCE($6, address),
       onboarding_completed = CASE WHEN $7::boolean THEN true ELSE onboarding_completed END,
       updated_at = now()
     WHERE id = $1
     RETURNING ${COMPANY_SELECT}`,
    [
      req.user.companyId,
      name === undefined ? null : name.trim(),
      businessType === undefined ? null : businessType.trim(),
      currency === undefined ? null : currency.trim(),
      phone === undefined ? null : phone.trim(),
      address === undefined ? null : address.trim(),
      willCompleteOnboarding,
    ],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('Company not found');
  }

  return res.json({
    data: formatCompanyResponse(result.rows[0]),
  });
});

const clearBusinessData = asyncHandler(async (req, res) => {
  const { password } = req.body || {};
  if (!password || typeof password !== 'string' || password.trim().length === 0) {
    throw ApiError.badRequest('Password is required to confirm business data reset', 'VALIDATION_ERROR');
  }

  const userRes = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [req.user.id],
  );
  const user = userRes.rows[0];
  if (!user) {
    throw ApiError.notFound('User not found');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.badRequest('Password is incorrect', 'INVALID_PASSWORD');
  }

  const companyId = req.user.companyId;

  await withTransaction(async (client) => {
    let existing = null;
    try {
      const res = await client.query(
        `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`,
      );
      if (res && res.rows) {
        existing = new Set(res.rows.map((r) => r.table_name));
      }
    } catch (_) {
      existing = null;
    }

    async function safeDelete(tbl, sql, params) {
      if (existing && !existing.has(tbl)) return;
      try {
        await client.query(sql, params);
      } catch (err) {
        if (err && err.code === '42P01') return;
        throw err;
      }
    }

    // 1. Invoices
    await safeDelete('invoices', `DELETE FROM invoices WHERE company_id = $1`, [companyId]);

    // 2. Sale items & sales
    await safeDelete(
      'sale_items',
      `DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE company_id = $1)`,
      [companyId],
    );
    await safeDelete('sales', `DELETE FROM sales WHERE company_id = $1`, [companyId]);

    // 3. Credit system
    await safeDelete('credit_payments', `DELETE FROM credit_payments WHERE company_id = $1`, [companyId]);
    await safeDelete(
      'credit_purchase_items',
      `DELETE FROM credit_purchase_items WHERE credit_purchase_id IN (SELECT id FROM credit_purchases WHERE company_id = $1)`,
      [companyId],
    );
    await safeDelete('credit_purchases', `DELETE FROM credit_purchases WHERE company_id = $1`, [companyId]);
    await safeDelete('customer_transactions', `DELETE FROM customer_transactions WHERE company_id = $1`, [companyId]);

    // 4. Appointments
    await safeDelete('appointments', `DELETE FROM appointments WHERE company_id = $1`, [companyId]);

    // 5. Enterprise projects
    await safeDelete('enterprise_projects', `DELETE FROM enterprise_projects WHERE company_id = $1`, [companyId]);

    // 6. Clinic system
    await safeDelete('clinic_payments', `DELETE FROM clinic_payments WHERE company_id = $1`, [companyId]);
    await safeDelete(
      'clinic_prescription_items',
      `DELETE FROM clinic_prescription_items WHERE prescription_id IN (SELECT id FROM clinic_prescriptions WHERE company_id = $1)`,
      [companyId],
    );
    await safeDelete('clinic_prescriptions', `DELETE FROM clinic_prescriptions WHERE company_id = $1`, [companyId]);
    await safeDelete('clinic_documents', `DELETE FROM clinic_documents WHERE company_id = $1`, [companyId]);
    await safeDelete('clinic_visits', `DELETE FROM clinic_visits WHERE company_id = $1`, [companyId]);
    await safeDelete('clinic_queue', `DELETE FROM clinic_queue WHERE company_id = $1`, [companyId]);
    await safeDelete('clinic_appointments', `DELETE FROM clinic_appointments WHERE company_id = $1`, [companyId]);
    await safeDelete('clinic_patients', `DELETE FROM clinic_patients WHERE company_id = $1`, [companyId]);

    // 7. Restaurant system
    await safeDelete('restaurant_payments', `DELETE FROM restaurant_payments WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_order_items', `DELETE FROM restaurant_order_items WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_orders', `DELETE FROM restaurant_orders WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_reservations', `DELETE FROM restaurant_reservations WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_menu_item_ingredients', `DELETE FROM restaurant_menu_item_ingredients WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_menu_items', `DELETE FROM restaurant_menu_items WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_inventory_movements', `DELETE FROM restaurant_inventory_movements WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_inventory_items', `DELETE FROM restaurant_inventory_items WHERE company_id = $1`, [companyId]);
    await safeDelete('restaurant_tables', `DELETE FROM restaurant_tables WHERE company_id = $1`, [companyId]);

    // 8. Customers
    await safeDelete('customers', `DELETE FROM customers WHERE company_id = $1`, [companyId]);

    // 9. Products & inventory
    await safeDelete('products', `DELETE FROM products WHERE company_id = $1`, [companyId]);

    // 10. Suppliers
    await safeDelete('suppliers', `DELETE FROM suppliers WHERE company_id = $1`, [companyId]);

    // 11. Employees, Attendance, Salaries, Expenses
    await safeDelete('salary_adjustments', `DELETE FROM salary_adjustments WHERE company_id = $1`, [companyId]);
    await safeDelete('attendance_records', `DELETE FROM attendance_records WHERE company_id = $1`, [companyId]);
    await safeDelete('expenses', `DELETE FROM expenses WHERE company_id = $1`, [companyId]);
    await safeDelete('employees', `DELETE FROM employees WHERE company_id = $1`, [companyId]);

    // 12. Notifications & AI logs
    await safeDelete('notifications', `DELETE FROM notifications WHERE company_id = $1`, [companyId]);
    await safeDelete('ai_logs', `DELETE FROM ai_logs WHERE company_id = $1`, [companyId]);
  });

  return res.json({
    success: true,
    message: 'Business data cleared successfully',
    companyId,
  });
});

const router = express.Router();

/*
 * All company endpoints are tenant-scoped through req.user.companyId.
 */
router.use(authMiddleware);

router.get('/me', getMe);
router.put('/me', requireRole('owner'), updateMe);
router.post('/me/clear-business-data', requireRole('owner'), clearBusinessData);
router.delete('/me/business-data', requireRole('owner'), clearBusinessData);

module.exports = router;
module.exports.clearBusinessDataHandler = clearBusinessData;