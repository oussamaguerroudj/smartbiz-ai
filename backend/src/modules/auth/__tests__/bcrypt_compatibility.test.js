const bcryptjs = require('bcryptjs');

describe('bcrypt to bcryptjs Backward Compatibility Verification', () => {
  // Hash generated specifically by native bcrypt v5.1.1 on Node.js:
  // Password: 'LegacyBcryptPassword123!'
  const legacyBcryptHash = '$2b$10$G8IwPjolFLmJlKw0hJ7oG.h2BtvegKfjblL1ycf27uVPUiXGTmEiC';
  const correctPassword = 'LegacyBcryptPassword123!';

  test('1. bcryptjs verifies passwords hashed by legacy native bcrypt v5.1.1', async () => {
    const isMatch = await bcryptjs.compare(correctPassword, legacyBcryptHash);
    expect(isMatch).toBe(true);
  });

  test('2. bcryptjs rejects invalid passwords against legacy native bcrypt hashes', async () => {
    const isWrongMatch = await bcryptjs.compare('WrongPassword999!', legacyBcryptHash);
    expect(isWrongMatch).toBe(false);
  });

  test('3. bcryptjs generates valid hashes that verify cleanly', async () => {
    const newPassword = 'ModernBcryptjsPassword456!';
    const newHash = await bcryptjs.hash(newPassword, 10);

    expect(newHash).toMatch(/^\$2[aby]\$\d{2}\$/);
    const isValid = await bcryptjs.compare(newPassword, newHash);
    expect(isValid).toBe(true);
  });
});
