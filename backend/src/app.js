const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const env = require('./config/env');
const routes = require('./routes');
const { errorMiddleware, notFoundMiddleware } = require('./middlewares/error.middleware');
const { apiGlobalLimiter } = require('./middlewares/rateLimit.middleware');

const app = express();

app.set('trust proxy', 1);
app.disable('x-powered-by');

// Request logger at the very top so EVERY incoming request is logged immediately
app.use((req, res, next) => {
  const start = Date.now();
  const fullPath = req.originalUrl || req.url;
  // eslint-disable-next-line no-console
  console.log(`--> [REQ IN] ${req.method} ${fullPath}`);
  res.on('finish', () => {
    // eslint-disable-next-line no-console
    console.log(`<-- [REQ OUT] ${req.method} ${fullPath} ${res.statusCode} (${Date.now() - start}ms)`);
  });
  next();
});

const path = require('path');
const landingHtmlPath = path.join(__dirname, 'public', 'index.html');
const adminPublicDir = path.join(__dirname, 'public', 'admin');
const adminHtmlPath = path.join(adminPublicDir, 'index.html');

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: false,
  }),
);
app.use(cors({ origin: env.corsOrigin }));
app.use(
  express.json({
    limit: '20mb',
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  }),
);

app.get(['/', '/download'], (req, res) => res.sendFile(landingHtmlPath));
app.get('/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));
app.get('/api/health', async (req, res) => {
  let dbStatus = 'ok';
  let dbError = null;
  let dbCode = null;
  let executedMigrations = [];
  try {
    const { pool } = require('./config/db');
    await pool.query('SELECT 1');
    const migRes = await pool.query('SELECT version FROM schema_migrations ORDER BY version');
    executedMigrations = migRes.rows.map((r) => r.version);
  } catch (err) {
    dbStatus = 'error';
    dbError = err.message || String(err);
    dbCode = err.code || null;
  }
  return res.json({
    status: 'ok',
    env: env.nodeEnv,
    commit: process.env.RENDER_GIT_COMMIT || '990b5a2',
    db: {
      status: dbStatus,
      code: dbCode,
      message: dbError,
      migrationsCount: executedMigrations.length,
      lastMigration: executedMigrations[executedMigrations.length - 1] || null,
    },
  });
});

app.use('/admin', express.static(adminPublicDir));
app.get(['/admin', '/admin/*'], (req, res) => {
  const fs = require('fs');
  if (fs.existsSync(adminHtmlPath)) {
    return res.sendFile(adminHtmlPath);
  }
  return res.status(404).send('Admin dashboard not found');
});

app.use('/api', apiGlobalLimiter, routes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = app;
