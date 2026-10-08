/**
 * Ch. 21 security audit: requireBusinessType() gate on every specialized
 * router (clinic / restaurant / pharmacy / superette / clothing).
 *
 * Two things are verified here, because either one regressing silently
 * would reopen the gap the guard was added to close:
 *
 *  1. The middleware itself: allows exactly the declared types, rejects
 *     everything else with 403 BUSINESS_TYPE_NOT_ALLOWED, 404s an unknown
 *     company, forwards DB errors, and reads the company id ONLY from
 *     req.user (the verified JWT), never from anything client-supplied.
 *
 *  2. The wiring: for each specialized router, the first two layers are
 *     authMiddleware then the guard, and every real route comes AFTER
 *     them - and, across ALL 24 business_type_enum values, the router's
 *     guard admits exactly the types main_shell.dart routes to that
 *     module's dashboard.
 */

// env.js throws without these; supply harmless test values BEFORE any
// module that (transitively) requires config/env is loaded.
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'x'.repeat(48);
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'y'.repeat(48);
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://u:p@localhost:5432/test';

jest.mock('../../config/db', () => ({ query: jest.fn() }));

const { query } = require('../../config/db');
const { requireBusinessType } = require('../businessType.middleware');
const { authMiddleware } = require('../auth.middleware');

const COMPANY = '11111111-1111-1111-1111-111111111111';

// business_type_enum after migrations 001 + 016.
const ALL_TYPES = [
  'clothing', 'grocery', 'pharmacy', 'clinic', 'restaurant', 'company',
  'workshop', 'retail_store', 'cafe', 'beauty_salon', 'barbershop', 'gym',
  'hotel', 'dental_clinic', 'medical_laboratory', 'car_repair',
  'electronics_store', 'supermarket', 'bakery', 'law_office',
  'accounting_office', 'real_estate_agency', 'education_center', 'other',
];

// Mirrors the switch in mobile/lib/features/shell/presentation/main_shell.dart.
// Dashboard-family simplification: 'dental_clinic' and 'cafe' are now
// also admitted (folded into clinic/restaurant respectively) — see
// clinic.routes.js / restaurant.routes.js and
// backend/SPECIALIZED_MODULES.md. The mobile picker itself only ever
// sends the canonical 'clinic'/'restaurant' values to new signups; these
// two extra values exist purely for backward compatibility with
// accounts created before this change.
const EXPECTED = {
  clinic: ['clinic', 'dental_clinic'],
  restaurant: ['restaurant', 'cafe'],
  pharmacy: ['pharmacy'],
  superette: ['grocery', 'supermarket', 'retail_store'],
  clothing: ['clothing'],
};

function run(mw, req) {
  return new Promise((resolve) => {
    mw(req, {}, (err) => resolve(err));
  });
}

beforeEach(() => {
  query.mockReset();
});

describe('requireBusinessType middleware', () => {
  test('allows a company whose type is in the allowed list', async () => {
    query.mockResolvedValue({ rows: [{ business_type: 'clinic' }] });
    const err = await run(requireBusinessType('clinic'), { user: { companyId: COMPANY } });
    expect(err).toBeUndefined();
  });

  test('rejects any other type with 403 BUSINESS_TYPE_NOT_ALLOWED', async () => {
    query.mockResolvedValue({ rows: [{ business_type: 'restaurant' }] });
    const err = await run(requireBusinessType('clinic'), { user: { companyId: COMPANY } });
    expect(err).toBeDefined();
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('BUSINESS_TYPE_NOT_ALLOWED');
  });

  test('404s when the company no longer exists', async () => {
    query.mockResolvedValue({ rows: [] });
    const err = await run(requireBusinessType('clinic'), { user: { companyId: COMPANY } });
    expect(err.statusCode).toBe(404);
  });

  test('forwards database errors to the error middleware instead of throwing', async () => {
    const boom = new Error('connection lost');
    query.mockRejectedValue(boom);
    const err = await run(requireBusinessType('clinic'), { user: { companyId: COMPANY } });
    expect(err).toBe(boom);
  });

  test('binds the company id from req.user ONLY - never body/query/params', async () => {
    query.mockResolvedValue({ rows: [{ business_type: 'clinic' }] });
    const req = {
      user: { companyId: COMPANY },
      body: { companyId: 'attacker-body' },
      query: { companyId: 'attacker-query' },
      params: { companyId: 'attacker-param' },
    };
    await run(requireBusinessType('clinic'), req);
    expect(query).toHaveBeenCalledTimes(1);
    expect(query.mock.calls[0][1]).toEqual([COMPANY]);
  });

  test('a multi-type guard admits each listed type', async () => {
    const mw = requireBusinessType('grocery', 'supermarket', 'retail_store');
    for (const type of ['grocery', 'supermarket', 'retail_store']) {
      query.mockResolvedValue({ rows: [{ business_type: type }] });
      expect(await run(mw, { user: { companyId: COMPANY } })).toBeUndefined();
    }
  });
});

describe('specialized routers: guard wiring and allow/deny matrix', () => {
  const routers = {
    clinic: require('../../modules/clinic/clinic.routes'),
    restaurant: require('../../modules/restaurant/restaurant.routes'),
    pharmacy: require('../../modules/pharmacy/pharmacy.routes'),
    superette: require('../../modules/superette/superette.routes'),
    clothing: require('../../modules/clothing/clothing.routes'),
  };

  test.each(Object.keys(routers))(
    '%s router: authMiddleware, then guard, then every route',
    (name) => {
      const stack = routers[name].stack;
      // Layer 0 = authMiddleware, layer 1 = the guard, both plain
      // middleware (no .route) and both BEFORE any real route.
      expect(stack[0].route).toBeUndefined();
      expect(stack[0].handle).toBe(authMiddleware);
      expect(stack[1].route).toBeUndefined();
      expect(typeof stack[1].handle).toBe('function');

      const firstRouteIdx = stack.findIndex((l) => l.route);
      expect(firstRouteIdx).toBeGreaterThanOrEqual(2);
      // No plain middleware sneaks in after the routes begin, so nothing
      // can be reached without passing the guard.
      stack.slice(firstRouteIdx).forEach((l) => expect(l.route).toBeDefined());
    },
  );

  test.each(Object.keys(routers))(
    '%s router guard admits exactly its own business types (all 24 enum values)',
    async (name) => {
      const guard = routers[name].stack[1].handle;
      const admitted = [];
      for (const type of ALL_TYPES) {
        query.mockReset();
        query.mockResolvedValue({ rows: [{ business_type: type }] });
        const err = await run(guard, { user: { companyId: COMPANY } });
        if (err === undefined) admitted.push(type);
        else expect(err.code).toBe('BUSINESS_TYPE_NOT_ALLOWED');
      }
      expect(admitted.sort()).toEqual([...EXPECTED[name]].sort());
    },
  );

  test('no business type is admitted by more than one specialized router', async () => {
    const seen = {};
    for (const name of Object.keys(routers)) {
      const guard = routers[name].stack[1].handle;
      for (const type of ALL_TYPES) {
        query.mockReset();
        query.mockResolvedValue({ rows: [{ business_type: type }] });
        const err = await run(guard, { user: { companyId: COMPANY } });
        if (err === undefined) (seen[type] = seen[type] || []).push(name);
      }
    }
    Object.entries(seen).forEach(([type, names]) => {
      expect({ type, names }).toEqual({ type, names: [names[0]] });
    });
  });
});
