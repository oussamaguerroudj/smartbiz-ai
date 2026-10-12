/**
 * Secure Administrator Provisioning Script
 * Usage: node src/scripts/create_admin.js <email> <password> [name] [role]
 */

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Client } = require('pg');

const readline = require('readline');

function askQuestion(query, isPassword = false) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    if (isPassword && process.stdin.isTTY) {
      process.stdout.write(query);
      let pass = '';
      process.stdin.setRawMode(true);
      process.stdin.resume();
      process.stdin.setEncoding('utf8');

      const onData = (char) => {
        if (char === '\n' || char === '\r' || char === '\u0004') {
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdin.removeListener('data', onData);
          process.stdout.write('\n');
          rl.close();
          resolve(pass);
        } else if (char === '\u0003') {
          // Ctrl+C
          process.exit(1);
        } else if (char === '\u007f' || char === '\b') {
          // Backspace
          if (pass.length > 0) {
            pass = pass.slice(0, -1);
            process.stdout.write('\b \b');
          }
        } else {
          pass += char;
          process.stdout.write('*');
        }
      };

      process.stdin.on('data', onData);
    } else {
      rl.question(query, (answer) => {
        rl.close();
        resolve(answer.trim());
      });
    }
  });
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

/**
 * Safely provisions an administrator account.
 * Guarantees:
 * - Transactional row locking (FOR UPDATE)
 * - Ordinary business accounts can NEVER be elevated or overwritten
 * - Existing administrators are NEVER overwritten unless allowUpdate === true
 * - Returns cleanly on success or rolls back on any error
 */
async function provisionAdmin({
  email,
  password,
  name = 'System Administrator',
  role = 'super_admin',
  allowUpdate = false,
  client: externalClient = null,
}) {
  if (!email || !password) {
    throw new Error('Email and password are required for administrator provisioning');
  }

  const normalized = normalizeEmail(email);
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(normalized)) {
    throw new Error(`Invalid email format "${email}"`);
  }

  if (password.length < 8) {
    throw new Error('Administrator password must be at least 8 characters');
  }

  if (role !== 'super_admin' && role !== 'support') {
    throw new Error("Role must be 'super_admin' or 'support'");
  }

  const shouldCloseClient = !externalClient;
  const client = externalClient || new Client({ connectionString: process.env.DATABASE_URL });
  if (shouldCloseClient) {
    await client.connect();
  }

  try {
    await client.query('BEGIN');

    // 1. Lock existing user record if it exists to prevent concurrent provisioning races
    const existingRes = await client.query(
      `SELECT id, email, role, password_hash, deleted_at, company_id
       FROM users
       WHERE lower(trim(email)) = $1
       FOR UPDATE`,
      [normalized],
    );

    const existingUser = existingRes.rows[0];

    if (existingUser) {
      if (existingUser.deleted_at) {
        throw new Error(
          `Cannot provision administrator: Account "${normalized}" is soft-deleted. Restore or purge before provisioning.`,
        );
      }

      // Defense against privilege escalation: ordinary users/owners cannot be elevated via provisioning
      if (existingUser.role !== 'super_admin' && existingUser.role !== 'support') {
        throw new Error(
          `SECURITY ALERT: Account "${normalized}" already exists as a regular business user with role "${existingUser.role}". Admin privilege escalation is prohibited.`,
        );
      }

      // Existing admin: refuse overwrite unless explicitly authorized
      if (!allowUpdate) {
        throw new Error(
          `Administrator account "${normalized}" already exists. Re-running provisioning will not overwrite existing credentials. To deliberately update this administrator, specify ALLOW_ADMIN_UPDATE=true or --allow-update.`,
        );
      }

      // Explicitly authorized update
      const passwordHash = await bcrypt.hash(password, 12);
      const updateRes = await client.query(
        `UPDATE users
         SET password_hash = $1, role = $2, name = $3, updated_at = now()
         WHERE id = $4
         RETURNING id, email, role`,
        [passwordHash, role, name, existingUser.id],
      );

      await client.query('COMMIT');
      return {
        action: 'updated',
        user: updateRes.rows[0],
      };
    }

    // 2. Fresh Administrator Provisioning
    const passwordHash = await bcrypt.hash(password, 12);

    // Ensure system company exists idempotently
    let companyId;
    const compRes = await client.query(
      `SELECT id FROM companies WHERE name = 'Modiri Administration' LIMIT 1`,
    );
    if (compRes.rows.length > 0) {
      companyId = compRes.rows[0].id;
    } else {
      const newComp = await client.query(
        `INSERT INTO companies (name, business_type, currency)
         VALUES ('Modiri Administration', 'company', 'DZD')
         RETURNING id`,
      );
      companyId = newComp.rows[0].id;
    }

    // Insert new administrator
    const insertRes = await client.query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, $2, $3, $4, $5, true)
       RETURNING id, email, role`,
      [companyId, name, normalized, passwordHash, role],
    );

    await client.query('COMMIT');
    return {
      action: 'created',
      user: insertRes.rows[0],
    };
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    if (err && err.code === '23505') {
      throw new Error(
        `Cannot provision administrator: An account with email "${normalized}" was created concurrently. Operation aborted safely.`,
      );
    }
    throw err;
  } finally {
    if (shouldCloseClient) {
      await client.end();
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  let email = process.env.ADMIN_EMAIL;
  let password = process.env.ADMIN_PASSWORD;
  let name = process.env.ADMIN_NAME || 'System Administrator';
  let role = process.env.ADMIN_ROLE || 'super_admin';
  const allowUpdate =
    process.env.ALLOW_ADMIN_UPDATE === 'true' || args.includes('--allow-update');

  const filteredArgs = args.filter((a) => a !== '--allow-update');
  if (filteredArgs[0]) email = email || filteredArgs[0];
  if (filteredArgs[1]) password = password || filteredArgs[1];
  if (filteredArgs[2]) name = name || filteredArgs[2];
  if (filteredArgs[3]) role = role || filteredArgs[3];

  if (filteredArgs[1]) {
    console.warn('[SECURITY WARNING] Passing passwords via CLI arguments exposes them in process listings and shell history.');
    console.warn('Recommendation: Provide credentials via ADMIN_PASSWORD environment variable or interactive prompt.\n');
  }

  if (!email && process.stdin.isTTY) {
    email = await askQuestion('Enter Administrator Email: ');
  }

  if (!password && process.stdin.isTTY) {
    password = await askQuestion('Enter Administrator Password (hidden): ', true);
  }

  if (!email || !password) {
    console.error('Usage:');
    console.error('  Interactive: node src/scripts/create_admin.js [--allow-update]');
    console.error('  Env vars:    ADMIN_EMAIL="admin@modiri.ai" ADMIN_PASSWORD="secret" [ALLOW_ADMIN_UPDATE=true] node src/scripts/create_admin.js');
    console.error('  CLI args:    node src/scripts/create_admin.js <email> <password> [name] [role] [--allow-update]');
    process.exit(1);
  }

  try {
    const result = await provisionAdmin({
      email,
      password,
      name,
      role,
      allowUpdate,
    });

    console.log(
      `[ADMIN BOOTSTRAP] Success: Admin user ${result.user.email} (${result.action}) with role ${result.user.role} (ID: ${result.user.id})`,
    );
  } catch (err) {
    console.error('[ADMIN BOOTSTRAP] Failed:', err.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  provisionAdmin,
  normalizeEmail,
};
