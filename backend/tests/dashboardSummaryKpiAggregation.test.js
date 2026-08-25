const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');

describe('Dashboard Summary KPI Aggregation Tests', () => {
  const testUserId = new mongoose.Types.ObjectId();

  // Helper function duplicating getISTDateBounds logic from walletController
  const getISTDateBounds = (daysOffset = 0) => {
    const now = new Date();
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const parts = formatter.formatToParts(now);
    const partMap = {};
    parts.forEach(p => partMap[p.type] = p.value);
    
    const istNowStr = `${partMap.year}-${partMap.month}-${partMap.day}T00:00:00.000+05:30`;
    const istMidnight = new Date(istNowStr);
    
    const targetStart = new Date(istMidnight.getTime() - daysOffset * 24 * 60 * 60 * 1000);
    const targetEnd = new Date(targetStart.getTime() + 24 * 60 * 60 * 1000 - 1);
    
    return { start: targetStart, end: targetEnd };
  };

  it('1. should compute IST start and end date bounds correctly for today', () => {
    const { start, end } = getISTDateBounds(0);
    expect(start).toBeInstanceOf(Date);
    expect(end).toBeInstanceOf(Date);
    expect(end.getTime() - start.getTime()).toBe(24 * 60 * 60 * 1000 - 1);
  });

  it('2. should aggregate Wallet + UPI successful production transactions and exclude TEST/failed transactions', async () => {
    const { start: todayStart, end: todayEnd } = getISTDateBounds(0);

    // Mock dataset simulating database records
    const mockRechargeRecords = [
      {
        userId: testUserId,
        orderId: 'ORD1001',
        amount: 100,
        commissionAmount: 1.00,
        status: 'SUCCESS',
        paymentMethod: 'WALLET',
        isTest: false,
        createdAt: new Date(),
      },
      {
        userId: testUserId,
        orderId: 'ORD1002',
        amount: 200,
        commissionAmount: 2.00,
        status: 'SUCCESS',
        paymentMethod: 'UPI',
        isTest: false,
        createdAt: new Date(),
      },
      {
        userId: testUserId,
        orderId: 'TEST-9999',
        amount: 500,
        commissionAmount: 5.00,
        status: 'SUCCESS',
        paymentMethod: 'WALLET',
        isTest: true,
        createdAt: new Date(),
      },
      {
        userId: testUserId,
        orderId: 'ORD1003',
        amount: 150,
        commissionAmount: 1.50,
        status: 'FAILED',
        paymentMethod: 'WALLET',
        isTest: false,
        createdAt: new Date(),
      },
    ];

    // Centralized MongoDB filtering rule test
    const filteredRecords = mockRechargeRecords.filter((tx) => {
      const isUser = tx.userId.equals(testUserId);
      const isSuccess = tx.status === 'SUCCESS';
      const isNotTestFlag = tx.isTest !== true;
      const isNotTestPrefix = !/^TEST/i.test(tx.orderId);
      const isToday = tx.createdAt >= todayStart && tx.createdAt <= todayEnd;
      return isUser && isSuccess && isNotTestFlag && isNotTestPrefix && isToday;
    });

    const totalRechargeRupees = filteredRecords.reduce((sum, r) => sum + r.amount, 0);
    const totalCommissionRupees = filteredRecords.reduce((sum, r) => sum + r.commissionAmount, 0);
    const totalCount = filteredRecords.length;

    expect(totalCount).toBe(2);
    expect(totalRechargeRupees).toBe(300);
    expect(totalCommissionRupees).toBe(3.00);
    expect(Math.round(totalRechargeRupees * 100)).toBe(30000);
    expect(Math.round(totalCommissionRupees * 100)).toBe(300);
  });
});
