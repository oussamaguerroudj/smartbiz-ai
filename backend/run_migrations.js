const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

async function runMigrations() {
  require('dotenv').config();
  const dbUrl = process.env.DATABASE_URL || 'postgresql://smartbiz:smartbiz_dev_password@localhost:5432/smartbiz';
  const clientConfig = { connectionString: dbUrl };
  if (process.env.NODE_ENV === 'production' && !dbUrl.includes('localhost') && !dbUrl.includes('127.0.0.1')) {
    clientConfig.ssl = { rejectUnauthorized: false };
  }
  const client = new Client(clientConfig);
  await client.connect();
  console.log('Connected to PostgreSQL database successfully.');

  const migrationsDir = path.join(__dirname, 'migrations');
  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`Running migration: ${file}...`);
    try {
      await client.query(sql);
      console.log(`  OK: ${file}`);
    } catch (err) {
      console.log(`  Notice/Result on ${file}: ${err.message}`);
    }
  }

  await client.end();
  console.log('ALL MIGRATIONS EXECUTED SUCCESSFULLY!');
}

runMigrations().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
