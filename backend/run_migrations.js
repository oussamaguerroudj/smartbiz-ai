const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

async function runMigrations() {
  require('dotenv').config();

  const dbUrl = process.env.DATABASE_URL;
  if (!dbUrl || String(dbUrl).trim() === '') {
    console.error('FATAL: DATABASE_URL environment variable is required to run migrations.');
    process.exit(1);
  }

  const clientConfig = { connectionString: dbUrl.trim() };
  if (
    process.env.NODE_ENV === 'production' &&
    !dbUrl.includes('localhost') &&
    !dbUrl.includes('127.0.0.1')
  ) {
    clientConfig.ssl = { rejectUnauthorized: false };
  }

  const client = new Client(clientConfig);
  try {
    await client.connect();
    console.log('Connected to PostgreSQL database successfully.');

    // 1. Ensure tracking table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);

    // 2. Fetch already-executed migrations
    const executedResult = await client.query('SELECT version FROM schema_migrations');
    const executedSet = new Set(executedResult.rows.map((r) => r.version));

    const migrationsDir = path.join(__dirname, 'migrations');
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    // 3. Idempotent adoption for existing legacy databases:
    // If schema_migrations is brand new (0 rows) but the database already has the 'companies' table,
    // backfill pre-existing baseline migrations up to 031 so existing databases do not re-run non-idempotent DDL.
    if (executedSet.size === 0) {
      const tableCheck = await client.query(`
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'companies'
      `);
      if (tableCheck.rows.length > 0) {
        console.log('Existing database schema detected. Backfilling baseline migrations (000-031) into schema_migrations...');
        const baseline = files.filter((f) => f <= '031_add_super_admin_and_support_roles.sql');
        for (const file of baseline) {
          await client.query(
            'INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING',
            [file],
          );
          executedSet.add(file);
        }
      }
    }

    // 4. Run pending migrations in strict sequential order
    let ranCount = 0;
    for (const file of files) {
      if (executedSet.has(file)) {
        continue;
      }

      console.log(`Running migration: ${file}...`);
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (version) VALUES ($1)',
          [file],
        );
        ranCount += 1;
        console.log(`  OK: ${file}`);
      } catch (err) {
        console.error(`FATAL: Migration failed on ${file}:`, err.message);
        throw err;
      }
    }

    await client.end();
    if (ranCount === 0) {
      console.log('Database is already up to date. No pending migrations.');
    } else {
      console.log(`Successfully executed ${ranCount} pending migration(s).`);
    }
  } catch (err) {
    console.error('Migration runner failed:', err.message);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

runMigrations();
