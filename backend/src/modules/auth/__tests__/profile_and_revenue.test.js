const authService = require('../auth.service');
const { query } = require('../../../config/db');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => cb({ query: jest.fn() })),
}));

jest.mock('../../../utils/email', () => ({
  sendMail: jest.fn().mockResolvedValue(true),
}));

describe('Profile, Password Change, Account Deletion & Calculations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getProfile', () => {
    it('returns public user profile and company info', async () => {
      query.mockResolvedValueOnce({
        rows: [
          {
            id: 'u123',
            name: 'John Doe',
            email: 'john@example.com',
            phone: '12345678',
            avatar_url: 'http://example.com/photo.jpg',
            role: 'owner',
            company_id: 'c123',
            email_verified: true,
            company_name: 'Test Business',
            business_type: 'retail',
            currency: 'DZD',
          },
        ],
      });

      const profile = await authService.getProfile('u123');
      expect(profile.user.name).toBe('John Doe');
      expect(profile.user.phone).toBe('12345678');
      expect(profile.user.avatarUrl).toBe('http://example.com/photo.jpg');
      expect(profile.company.name).toBe('Test Business');
    });
  });

  describe('updateProfile', () => {
    it('updates user profile fields successfully', async () => {
      query
        .mockResolvedValueOnce({
          rows: [
            { id: 'u123', email: 'john@example.com' },
          ],
        })
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'u123',
              name: 'John Updated',
              email: 'john@example.com',
              phone: '98765432',
              avatar_url: 'http://example.com/new.jpg',
              role: 'owner',
              company_id: 'c123',
              email_verified: true,
            },
          ],
        });

      const updated = await authService.updateProfile('u123', {
        name: 'John Updated',
        phone: '98765432',
        avatarUrl: 'http://example.com/new.jpg',
      });

      expect(updated.name).toBe('John Updated');
      expect(updated.phone).toBe('98765432');
      expect(updated.avatarUrl).toBe('http://example.com/new.jpg');
    });
  });

  describe('verifyPassword', () => {
    it('returns verified: true when password matches hash', async () => {
      const bcrypt = require('bcryptjs');
      const hash = await bcrypt.hash('CorrectPass123', 10);
      query.mockResolvedValueOnce({
        rows: [{ id: 'u123', password_hash: hash }],
      });

      const res = await authService.verifyPassword('u123', { password: 'CorrectPass123' });
      expect(res).toEqual({ verified: true });
    });

    it('rejects with INVALID_PASSWORD when password is wrong', async () => {
      const bcrypt = require('bcryptjs');
      const hash = await bcrypt.hash('CorrectPass123', 10);
      query.mockResolvedValueOnce({
        rows: [{ id: 'u123', password_hash: hash }],
      });

      await expect(
        authService.verifyPassword('u123', { password: 'WrongPassword' }),
      ).rejects.toThrow('Password is incorrect');
    });

    it('rejects when password is empty', async () => {
      await expect(
        authService.verifyPassword('u123', { password: '' }),
      ).rejects.toThrow('Password is required');
    });
  });
});
