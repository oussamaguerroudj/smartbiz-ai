const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const env = require('./config/env');
const routes = require('./routes');
const { errorMiddleware, notFoundMiddleware } = require('./middlewares/error.middleware');

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

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }),
);
app.use(cors({ origin: env.corsOrigin }));
app.use(express.json({ limit: '20mb' }));

app.get('/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));
app.get('/api/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));

app.use('/api', routes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = app;
