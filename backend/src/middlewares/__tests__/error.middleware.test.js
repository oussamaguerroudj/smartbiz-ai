const { errorMiddleware } = require('../error.middleware');
const ApiError = require('../../utils/ApiError');
const env = require('../../config/env');

describe('errorMiddleware', () => {
  let req;
  let res;
  let statusMock;
  let jsonMock;

  beforeEach(() => {
    jsonMock = jest.fn();
    statusMock = jest.fn(() => ({ json: jsonMock }));
    req = { originalUrl: '/api/auth/register' };
    res = { status: statusMock };
  });

  it('handles ApiError with status and code correctly', () => {
    const err = ApiError.badRequest('Invalid input', 'VALIDATION_ERROR');
    errorMiddleware(err, req, res, jest.fn());

    expect(statusMock).toHaveBeenCalledWith(400);
    expect(jsonMock).toHaveBeenCalledWith({
      error: true,
      message: 'Invalid input',
      code: 'VALIDATION_ERROR',
    });
  });

  it('handles body-parser SyntaxError as 400 INVALID_JSON', () => {
    const syntaxErr = new SyntaxError('Unexpected token in JSON');
    syntaxErr.status = 400;

    errorMiddleware(syntaxErr, req, res, jest.fn());

    expect(statusMock).toHaveBeenCalledWith(400);
    expect(jsonMock).toHaveBeenCalledWith({
      error: true,
      message: 'Invalid JSON payload format',
      code: 'INVALID_JSON',
    });
  });

  it('handles PostgreSQL unique violation (23505) as 409 DUPLICATE', () => {
    const pgErr = new Error('duplicate key value');
    pgErr.code = '23505';

    errorMiddleware(pgErr, req, res, jest.fn());

    expect(statusMock).toHaveBeenCalledWith(409);
    expect(jsonMock).toHaveBeenCalledWith({
      error: true,
      message: 'Duplicate value',
      code: 'DUPLICATE',
    });
  });

  it('handles PostgreSQL foreign key violation (23503) as 400 FK_VIOLATION', () => {
    const pgErr = new Error('violates foreign key');
    pgErr.code = '23503';

    errorMiddleware(pgErr, req, res, jest.fn());

    expect(statusMock).toHaveBeenCalledWith(400);
    expect(jsonMock).toHaveBeenCalledWith({
      error: true,
      message: 'Related record not found',
      code: 'FK_VIOLATION',
    });
  });

  it('handles unhandled generic errors gracefully', () => {
    const genericErr = new Error('Something went wrong internally');
    errorMiddleware(genericErr, req, res, jest.fn());

    expect(statusMock).toHaveBeenCalledWith(500);
    expect(jsonMock).toHaveBeenCalledWith(
      expect.objectContaining({
        error: true,
        code: 'INTERNAL_ERROR',
      }),
    );
  });
});
