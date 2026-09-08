const { Pool } = require('pg');
const env = require('./env');

// Single shared pool for the whole app. All queries MUST go through this
// (or a client checked out from it for transactions) — never a second
// ad-hoc connection — so pool sizing/limits stay predictable.
const pool = new Pool({
  connectionString: env.databaseUrl,
});

pool.on('error', (err) => {
  // Unexpected errors on idle clients (e.g. connection dropped by DB).
  // Logged, not thrown — a single dead idle client should not crash the
  // whole API process.
  // eslint-disable-next-line no-console
  console.error('Unexpected PostgreSQL pool error:', err);
});

/**
 * Run a query with automatic parameterization. Always prefer this (or a
 * transaction client, see withTransaction) over string-concatenated SQL —
 * this is the "parameterized queries / safe ORM" requirement from the
 * Phase 1 security architecture.
 */
async function query(text, params) {
  return pool.query(text, params);
}

/**
 * Runs `fn` inside a BEGIN/COMMIT transaction using a single checked-out
 * client. Any thrown error triggers ROLLBACK before re-throwing — this is
 * the mechanism behind the Sales module's required "Create Sale ...
 * Commit transaction / ROLLBACK on error" flow (Spec Ch. 11).
 */
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, withTransaction };
