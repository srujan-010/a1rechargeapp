const { calculateCommission } = require('../utils/commissionEngine');

describe('Commission Engine', () => {

  describe('Mobile Recharge', () => {
    it('calculates 1.00% commission for Airtel mobile recharge', () => {
      const result = calculateCommission('mobile', 'Airtel', 10000); // ₹100
      expect(result.commissionPercentage).toBe(1.00);
      expect(result.commissionAmountPaise).toBe(100); // 1% of 10000 = 100
      expect(result.walletDebitedAmountPaise).toBe(9900); // 10000 - 100
    });

    it('calculates 2.70% commission for Vi mobile recharge', () => {
      const result = calculateCommission('mobile', 'Vi', 20000); // ₹200
      expect(result.commissionPercentage).toBe(2.70);
      expect(result.commissionAmountPaise).toBe(540); // 2.7% of 20000 = 540
      expect(result.walletDebitedAmountPaise).toBe(19460); // 20000 - 540
    });
  });

  describe('DTH Recharge', () => {
    it('calculates 3.20% commission for Tata Play DTH', () => {
      const result = calculateCommission('dth', 'Tata Play', 50000); // ₹500
      expect(result.commissionPercentage).toBe(3.20);
      expect(result.commissionAmountPaise).toBe(1600); // 3.2% of 50000 = 1600
      expect(result.walletDebitedAmountPaise).toBe(48400); // 50000 - 1600
    });

    it('calculates 3.25% commission for Dish TV DTH', () => {
      const result = calculateCommission('dth', 'Dish TV', 30000); // ₹300
      expect(result.commissionPercentage).toBe(3.25);
      expect(result.commissionAmountPaise).toBe(975); // 3.25% of 30000 = 975
      expect(result.walletDebitedAmountPaise).toBe(29025); // 30000 - 975
    });

    it('calculates 3.25% commission for Sun Direct DTH', () => {
      const result = calculateCommission('dth', 'Sun Direct', 10000); // ₹100
      expect(result.commissionPercentage).toBe(3.25);
      expect(result.commissionAmountPaise).toBe(325); // 3.25% of 10000 = 325
      expect(result.walletDebitedAmountPaise).toBe(9675); 
    });
  });

  describe('Electricity (BBPS)', () => {
    it('calculates 0.40% commission for TSSPDCL', () => {
      const result = calculateCommission('bbps', 'TSSPDCL', 100000); // ₹1000
      expect(result.commissionPercentage).toBe(0.40);
      expect(result.commissionAmountPaise).toBe(400); // 0.4% of 100000 = 400
      expect(result.walletDebitedAmountPaise).toBe(99600); 
    });

    it('calculates 0.40% commission for TGSPDCL', () => {
      const result = calculateCommission('bbps', 'TGSPDCL', 200000); // ₹2000
      expect(result.commissionPercentage).toBe(0.40);
      expect(result.commissionAmountPaise).toBe(800); // 0.4% of 200000 = 800
      expect(result.walletDebitedAmountPaise).toBe(199200); 
    });
  });

  describe('Fallback behavior', () => {
    it('returns 0 commission for unconfigured service/operator', () => {
      const result = calculateCommission('postpaid', 'Unknown Operator', 50000);
      expect(result.commissionPercentage).toBe(0);
      expect(result.commissionAmountPaise).toBe(0);
      expect(result.walletDebitedAmountPaise).toBe(50000);
    });

    it('returns 0 commission for mismatching service type and operator', () => {
      // Tata Play exists for DTH, but not for mobile
      const result = calculateCommission('mobile', 'Tata Play', 50000);
      expect(result.commissionPercentage).toBe(0);
      expect(result.commissionAmountPaise).toBe(0);
      expect(result.walletDebitedAmountPaise).toBe(50000);
    });
  });

});
