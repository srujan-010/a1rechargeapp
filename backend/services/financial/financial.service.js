const commissionService = require('../commission/commission.service');
const User = require('../../models/User');
const mongoose = require('mongoose');

class FinancialService {
  /**
   * Calculate single authoritative financial structure for a recharge transaction.
   * ALL output financial values are strictly INTEGER PAISE.
   *
   * @param {Object} params
   * @param {string} params.serviceType - 'mobile', 'dth', 'bbps', etc.
   * @param {string} params.operatorCode
   * @param {string} [params.operatorName]
   * @param {number} params.grossAmountPaise - Gross recharge amount in integer paise (e.g. 29500 for ₹295.00)
   * @param {string} [params.userId]
   * @param {string} [params.planType]
   * @param {string} [params.accountType] - 'BUSINESS' or 'PERSONAL' or 'RETAILER'
   * @returns {Promise<Object>} Authoritative financial structure in integer paise
   */
  async calculateRechargeFinancials({
    serviceType = 'mobile',
    operatorCode,
    operatorName = '',
    grossAmountPaise,
    userId,
    planType,
    accountType = 'BUSINESS',
  }) {
    // 1. Sanitize & Enforce integer paise input
    const grossPaise = Math.round(Number(grossAmountPaise) || 0);

    if (!Number.isInteger(grossPaise) || grossPaise <= 0) {
      throw new Error(`Invalid gross amount paise: ${grossAmountPaise}`);
    }

    // 2. Resolve User Account Type if userId provided
    let resolvedAccountType = accountType;
    if (userId && mongoose.Types.ObjectId.isValid(userId)) {
      const userDoc = await User.findById(userId).select('accountType').lean().catch(() => null);
      if (userDoc && userDoc.accountType) {
        resolvedAccountType = userDoc.accountType;
      }
    }

    const targetAccountType = String(resolvedAccountType || 'BUSINESS').trim().toUpperCase() === 'PERSONAL'
      ? 'PERSONAL'
      : 'BUSINESS';

    // 3. Convert grossPaise to rupees ONLY for commission lookup service helper
    const grossRupees = grossPaise / 100;

    // 4. Single authoritative commission calculation lookup
    const commission = await commissionService.calculateCommission(
      operatorCode,
      grossRupees,
      operatorName,
      serviceType,
      {
        retailerId: userId ? String(userId) : 'N/A',
        planType: planType || 'N/A',
        accountType: targetAccountType,
      }
    );

    const isPersonal = targetAccountType === 'PERSONAL';

    // 5. Calculate integer paise amounts deterministically
    const retailerPercent = Number(commission?.retailerCommissionPercentage || 0);
    const personalPercent = Number(commission?.personalCommissionPercentage || 0);
    const providerPercent = Number(commission?.providerCommissionPercentage || 0);
    const companyPercent = Number(commission?.companyProfitPercentage || 0);

    const effectiveCommissionPercent = isPersonal ? personalPercent : retailerPercent;

    // Commission in paise (rounded to nearest integer)
    let commissionAmountPaise = isPersonal
      ? Math.round(Number(commission?.personalDiscountAmount || 0) * 100)
      : Math.round(Number(commission?.retailerCommissionAmount || 0) * 100);

    if (!Number.isFinite(commissionAmountPaise) || commissionAmountPaise < 0) {
      commissionAmountPaise = 0;
    }

    // Provider Commission in paise
    const providerCommissionAmountPaise = Math.round(Number(commission?.providerCommissionAmount || 0) * 100);
    const companyProfitAmountPaise = Math.round(Number(commission?.companyProfitAmount || 0) * 100);

    // Enforce Invariant 2: 0 <= commissionAmountPaise <= grossAmountPaise
    if (commissionAmountPaise > grossPaise) {
      console.warn(`[FINANCIAL] Commission paise (${commissionAmountPaise}) exceeded gross (${grossPaise}). Cap to gross.`);
      commissionAmountPaise = grossPaise;
    }

    // Calculate Net Retailer Payable Amount in paise
    // Enforce Invariant 1: netPayablePaise = grossAmountPaise - commissionAmountPaise
    const netPayablePaise = grossPaise - commissionAmountPaise;

    // Enforce Invariant 3: netPayablePaise >= 0
    if (netPayablePaise < 0) {
      throw new Error(`Invalid net payable calculation: gross (${grossPaise}) - commission (${commissionAmountPaise}) resulted in negative amount`);
    }

    const result = {
      accountType: targetAccountType,
      commissionRecordId: commission?.commissionRecordId || null,
      grossAmountPaise: grossPaise,
      commissionAmountPaise,
      effectiveCommissionPercent,
      providerCommissionPercentage: providerPercent,
      providerCommissionAmountPaise,
      retailerCommissionPercentage: retailerPercent,
      retailerCommissionAmountPaise: isPersonal ? 0 : commissionAmountPaise,
      personalCommissionPercentage: personalPercent,
      personalDiscountAmountPaise: isPersonal ? commissionAmountPaise : 0,
      companyProfitPercentage: companyPercent,
      companyProfitAmountPaise,
      netPayablePaise,
      currency: 'INR',
    };

    console.log('[FINANCIAL CALCULATION COMPLETE]', {
      grossAmountPaise: result.grossAmountPaise,
      commissionAmountPaise: result.commissionAmountPaise,
      netPayablePaise: result.netPayablePaise,
      accountType: result.accountType,
    });

    return result;
  }
}

module.exports = new FinancialService();
