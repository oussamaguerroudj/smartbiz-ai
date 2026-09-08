const app = require('./app');
const env = require('./config/env');

app.listen(env.port, () => {
  // eslint-disable-next-line no-console
  console.log(`SmartBiz AI backend listening on http://localhost:${env.port} (${env.nodeEnv})`);
});
