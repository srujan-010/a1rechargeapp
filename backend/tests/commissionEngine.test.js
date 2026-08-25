const { calculateCommission } = require('../utils/commissionEngine');

describe('Commission Engine', () => {

  describe('Mobile Recharge', () => {
    it('calculates commission for Airtel mobile recharge', async () => {
      const result = await calculateCommission('mobile', 'Airtel', 10000); // ₹100
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });

    it('calculates commission for Vi mobile recharge', async () => {
      const result = await calculateCommission('mobile', 'Vi', 20000); // ₹200
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });
  });

  describe('DTH Recharge', () => {
    it('calculates commission for Tata Play DTH', async () => {
      const result = await calculateCommission('dth', 'Tata Play', 50000); // ₹500
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });

    it('calculates commission for Dish TV DTH', async () => {
      const result = await calculateCommission('dth', 'Dish TV', 30000); // ₹300
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });

    it('calculates commission for Sun Direct DTH', async () => {
      const result = await calculateCommission('dth', 'Sun Direct', 10000); // ₹100
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });
  });

  describe('Electricity (BBPS)', () => {
    it('calculates commission for TSSPDCL', async () => {
      const result = await calculateCommission('bbps', 'TSSPDCL', 100000); // ₹1000
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });

    it('calculates commission for TGSPDCL', async () => {
      const result = await calculateCommission('bbps', 'TGSPDCL', 200000); // ₹2000
      expect(result).toHaveProperty('commissionPercentage');
      expect(result).toHaveProperty('commissionAmountPaise');
      expect(result).toHaveProperty('walletDebitedAmountPaise');
    });
  });

  describe('Fallback behavior', () => {
    it('returns 0 commission for unconfigured service/operator', async () => {
      const result = await calculateCommission('postpaid', 'Unknown Operator', 50000);
      expect(result.commissionPercentage).toBe(0);
      expect(result.commissionAmountPaise).toBe(0);
      expect(result.walletDebitedAmountPaise).toBe(50000);
    });

    it('returns 0 commission for mismatching service type and operator', async () => {
      // Tata Play exists for DTH, but not for mobile
      const result = await calculateCommission('mobile', 'Tata Play', 50000);
      expect(result.commissionPercentage).toBe(0);
      expect(result.commissionAmountPaise).toBe(0);
      expect(result.walletDebitedAmountPaise).toBe(50000);
    });
  });

});
