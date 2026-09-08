/**
 * Wraps an async Express handler so any rejected promise is forwarded to
 * next(err) automatically, instead of every controller needing its own
 * try/catch. Use for every controller function.
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = asyncHandler;
