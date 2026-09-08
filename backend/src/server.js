const app = require('./app');
const env = require('./config/env');

const server = app.listen(env.port, () => {
  // eslint-disable-next-line no-console
  console.log(
    `Backend listening on port ${env.port} (${env.nodeEnv})`,
  );
});

function shutdown(signal) {
  // eslint-disable-next-line no-console
  console.log(`${signal} received. Shutting down gracefully...`);

  server.close((err) => {
    if (err) {
      // eslint-disable-next-line no-console
      console.error('Error during server shutdown:', err);
      process.exit(1);
    }

    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));