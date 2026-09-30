const { validateScanInvoice, validateChat, validateFeedback } = require('../ai.validators');

function runValidator(fn, body) {
  const req = { body };
  let calledWith;
  const next = (arg) => {
    calledWith = arg;
  };
  fn(req, {}, next);
  return calledWith; // undefined = passed through; an ApiError = rejected
}

describe('validateScanInvoice', () => {
  test('rejects missing imageBase64', () => {
    const err = runValidator(validateScanInvoice, {});
    expect(err).toBeDefined();
    expect(err.code).toBe('VALIDATION_ERROR');
  });

  test('rejects an oversized payload', () => {
    const huge = 'a'.repeat(7 * 1024 * 1024);
    const err = runValidator(validateScanInvoice, { imageBase64: huge });
    expect(err).toBeDefined();
  });

  test('accepts a normal-sized payload', () => {
    const err = runValidator(validateScanInvoice, { imageBase64: 'aGVsbG8=' });
    expect(err).toBeUndefined();
  });
});

describe('validateChat', () => {
  test('rejects empty message', () => {
    const err = runValidator(validateChat, { message: '   ' });
    expect(err).toBeDefined();
  });

  test('rejects an overly long message', () => {
    const err = runValidator(validateChat, { message: 'a'.repeat(3000) });
    expect(err).toBeDefined();
  });

  test('accepts a normal message, including Arabic/Darija text', () => {
    const err = runValidator(validateChat, { message: 'شحال بعنا اليوم؟' });
    expect(err).toBeUndefined();
  });
});

describe('validateFeedback', () => {
  test('rejects an invalid feedback value', () => {
    const err = runValidator(validateFeedback, { feedback: 'love_it' });
    expect(err).toBeDefined();
  });

  test('rejects when neither feedback nor correctedAnswer is provided', () => {
    const err = runValidator(validateFeedback, {});
    expect(err).toBeDefined();
  });

  test('accepts a valid feedback value alone', () => {
    const err = runValidator(validateFeedback, { feedback: 'helpful' });
    expect(err).toBeUndefined();
  });

  test('accepts a corrected answer alone', () => {
    const err = runValidator(validateFeedback, { correctedAnswer: 'The real answer is 500 DZD.' });
    expect(err).toBeUndefined();
  });
});
