const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../models/User');

describe('Security PIN vs Wallet MPIN Architecture Tests', () => {
  let testUser;

  beforeEach(() => {
    testUser = new User({
      retailerId: 'RET_TEST_99',
      name: 'Test Retailer',
      phone: '9876543210',
      role: 'retailer',
    });
    testUser.save = jest.fn().mockResolvedValue(testUser);
  });

  // TEST 1: Set Security PIN = 123456
  test('TEST 1: Setting Security PIN configures Security PIN ONLY, leaving Wallet MPIN unconfigured', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('123456', salt);

    const safeJson = testUser.toSafeJSON();

    expect(safeJson.hasSecurityPin).toBe(true);
    expect(safeJson.securityPinConfigured).toBe(true);

    expect(safeJson.hasWalletMpin).toBe(false);
    expect(safeJson.walletMpinConfigured).toBe(false);
  });

  // TEST 2: Set Wallet MPIN = 654321
  test('TEST 2: Setting Wallet MPIN maintains independent status for both credentials', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('123456', salt);
    testUser.walletMpinHash = await bcrypt.hash('654321', salt);

    const safeJson = testUser.toSafeJSON();

    expect(safeJson.hasSecurityPin).toBe(true);
    expect(safeJson.hasWalletMpin).toBe(true);
  });

  // TEST 3: App Lock requires Security PIN
  test('TEST 3: App lock accepts Security PIN (123456) and rejects Wallet MPIN (654321)', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('123456', salt);
    testUser.walletMpinHash = await bcrypt.hash('654321', salt);

    // 123456 -> app opens (matchSecurityPin returns true)
    const validAppUnlock = await testUser.matchSecurityPin('123456');
    expect(validAppUnlock).toBe(true);

    // 654321 -> rejected for app access
    const invalidAppUnlock = await testUser.matchSecurityPin('654321');
    expect(invalidAppUnlock).toBe(false);
  });

  // TEST 4: Wallet transaction requires Wallet MPIN
  test('TEST 4: Wallet transaction accepts Wallet MPIN (654321) and rejects Security PIN (123456)', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('123456', salt);
    testUser.walletMpinHash = await bcrypt.hash('654321', salt);

    // 654321 -> accepted for wallet debit
    const validPayment = await testUser.matchWalletMpin('654321');
    expect(validPayment).toBe(true);

    // 123456 -> rejected for wallet payment
    const invalidPayment = await testUser.matchWalletMpin('123456');
    expect(invalidPayment).toBe(false);
  });

  // TEST 5: Change Security PIN
  test('TEST 5: Changing Security PIN (123456 -> 111111) leaves Wallet MPIN unchanged (654321)', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('123456', salt);
    testUser.walletMpinHash = await bcrypt.hash('654321', salt);

    // Change Security PIN
    testUser.securityPinHash = await bcrypt.hash('111111', salt);

    expect(await testUser.matchSecurityPin('111111')).toBe(true);
    expect(await testUser.matchSecurityPin('123456')).toBe(false);

    // Wallet MPIN must remain 654321
    expect(await testUser.matchWalletMpin('654321')).toBe(true);
  });

  // TEST 6: Change Wallet MPIN
  test('TEST 6: Changing Wallet MPIN (654321 -> 222222) leaves Security PIN unchanged (111111)', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('111111', salt);
    testUser.walletMpinHash = await bcrypt.hash('654321', salt);

    // Change Wallet MPIN
    testUser.walletMpinHash = await bcrypt.hash('222222', salt);

    expect(await testUser.matchWalletMpin('222222')).toBe(true);
    expect(await testUser.matchWalletMpin('654321')).toBe(false);

    // Security PIN must remain 111111
    expect(await testUser.matchSecurityPin('111111')).toBe(true);
  });

  // TEST 7: Reset Security PIN
  test('TEST 7: Resetting Security PIN leaves Wallet MPIN unchanged', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('111111', salt);
    testUser.walletMpinHash = await bcrypt.hash('222222', salt);

    // Reset Security PIN to 333333
    testUser.securityPinHash = await bcrypt.hash('333333', salt);

    expect(await testUser.matchSecurityPin('333333')).toBe(true);
    expect(await testUser.matchWalletMpin('222222')).toBe(true);
  });

  // TEST 8: Reset Wallet MPIN
  test('TEST 8: Resetting Wallet MPIN leaves Security PIN unchanged', async () => {
    const salt = await bcrypt.genSalt(10);
    testUser.securityPinHash = await bcrypt.hash('333333', salt);
    testUser.walletMpinHash = await bcrypt.hash('222222', salt);

    // Reset Wallet MPIN to 444444
    testUser.walletMpinHash = await bcrypt.hash('444444', salt);

    expect(await testUser.matchWalletMpin('444444')).toBe(true);
    expect(await testUser.matchSecurityPin('333333')).toBe(true);
  });
});
