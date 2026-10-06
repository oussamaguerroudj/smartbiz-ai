const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const env = require('./config/env');
const routes = require('./routes');
const { errorMiddleware, notFoundMiddleware } = require('./middlewares/error.middleware');
const { apiGlobalLimiter } = require('./middlewares/rateLimit.middleware');

const app = express();

// Request logger at the very top so EVERY incoming request is logged immediately
app.use((req, res, next) => {
  const start = Date.now();
  // eslint-disable-next-line no-console
  console.log(`--> [REQ IN] ${req.method} ${req.url}`);
  res.on('finish', () => {
    // eslint-disable-next-line no-console
    console.log(`<-- [REQ OUT] ${req.method} ${req.url} ${res.statusCode} (${Date.now() - start}ms)`);
  });
  next();
});

const path = require('path');
const landingHtmlPath = path.join(__dirname, 'public', 'index.html');

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: false,
  }),
);
app.use(cors({ origin: env.corsOrigin }));
app.use(express.json({ limit: '20mb' }));

app.get(['/', '/download'], (req, res) => res.sendFile(landingHtmlPath));
app.get('/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));
app.get('/api/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));

app.use('/api', apiGlobalLimiter, routes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = app;
