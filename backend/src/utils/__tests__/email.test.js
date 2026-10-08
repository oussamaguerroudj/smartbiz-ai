jest.mock('../../config/env', () => ({
  brevo: {
    apiKey: 'xkeysib-test-mock-key',
    fromEmail: 'oussama.guerroudj@ensia.edu.dz',
    fromName: 'Modiri AI',
  },
  nodeEnv: 'production',
}));

describe('email utility (Brevo HTTPS API)', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    jest.resetModules();
    global.fetch = jest.fn();
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  test('validates required email parameters', async () => {
    const { sendMail } = require('../email');

    await expect(sendMail({ to: '', subject: 'test', html: '<p>hi</p>' })).rejects.toThrow(
      'Email recipient is required',
    );
    await expect(sendMail({ to: 'to@example.com', subject: '', html: '<p>hi</p>' })).rejects.toThrow(
      'Email subject is required',
    );
    await expect(sendMail({ to: 'to@example.com', subject: 'test', html: '' })).rejects.toThrow(
      'Email content is required',
    );
  });

  test('sends email via Brevo HTTPS API with correct URL, method, headers, and payload', async () => {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      status: 201,
      json: async () => ({ messageId: '<brevo-msg-id-12345@smtp-relay.mailin.fr>' }),
    });

    const { sendMail } = require('../email');

    const result = await sendMail({
      to: 'recipient@example.com',
      subject: 'Your Modiri AI verification code',
      html: '<p>Your code is: 123456</p>',
      text: 'Your code is: 123456',
    });

    expect(result).toBeDefined();
    expect(result.messageId).toBe('<brevo-msg-id-12345@smtp-relay.mailin.fr>');
    expect(result.accepted).toEqual(['recipient@example.com']);

    expect(global.fetch).toHaveBeenCalledTimes(1);
    const [url, options] = global.fetch.mock.calls[0];

    expect(url).toBe('https://api.brevo.com/v3/smtp/email');
    expect(options.method).toBe('POST');
    expect(options.headers).toEqual({
      'api-key': 'xkeysib-test-mock-key',
      'accept': 'application/json',
      'content-type': 'application/json',
    });

    const parsedBody = JSON.parse(options.body);
    expect(parsedBody).toEqual({
      sender: {
        name: 'Modiri AI',
        email: 'oussama.guerroudj@ensia.edu.dz',
      },
      to: [
        {
          email: 'recipient@example.com',
        },
      ],
      subject: 'Your Modiri AI verification code',
      htmlContent: '<p>Your code is: 123456</p>',
      textContent: 'Your code is: 123456',
    });
  });

  test('handles Brevo 4xx client error response', async () => {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 400,
      json: async () => ({ code: 'invalid_parameter', message: 'Invalid recipient email' }),
    });

    const { sendMail } = require('../email');

    await expect(
      sendMail({
        to: 'bad-email@example.com',
        subject: 'Test Subject',
        html: '<p>Test</p>',
      }),
    ).rejects.toThrow('Invalid recipient email');
  });

  test('handles Brevo 5xx server error response', async () => {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 503,
      json: async () => ({ message: 'Service temporarily unavailable' }),
    });

    const { sendMail } = require('../email');

    await expect(
      sendMail({
        to: 'user@example.com',
        subject: 'Test Subject',
        html: '<p>Test</p>',
      }),
    ).rejects.toThrow('Service temporarily unavailable');
  });

  test('handles network failure', async () => {
    global.fetch.mockRejectedValueOnce(new Error('Connection refused'));

    const { sendMail } = require('../email');

    await expect(
      sendMail({
        to: 'user@example.com',
        subject: 'Test Subject',
        html: '<p>Test</p>',
      }),
    ).rejects.toThrow('Connection refused');
  });

  test('handles timeout via AbortError', async () => {
    const abortErr = new Error('The operation was aborted');
    abortErr.name = 'AbortError';
    global.fetch.mockRejectedValueOnce(abortErr);

    const { sendMail } = require('../email');

    const errPromise = sendMail({
      to: 'user@example.com',
      subject: 'Test Subject',
      html: '<p>Test</p>',
    });

    await expect(errPromise).rejects.toThrow('Brevo API request timed out');
  });
});
