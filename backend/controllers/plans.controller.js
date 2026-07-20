const plansService = require('../services/plans.service');

const _handleError = (error, res, next) => {
  if (error.message.includes('Invalid')) {
    res.status(400);
  } else {
    res.status(500);
  }
  
  const safeMessage = error.message.includes('PlansInfo') 
      ? 'Unable to fetch plans.' 
      : error.message;
      
  next(new Error(safeMessage));
};

// 1. Mobile Prepaid
const getMobilePrepaidPlans = async (req, res, next) => {
  try {
    const { operatorId, circleId, search } = req.query;
    if (!operatorId || !circleId) {
      res.status(400);
      throw new Error('operatorId and circleId are required');
    }
    const plans = await plansService.getMobilePrepaid(operatorId, circleId, search);
    res.status(200).json({ success: true, service: 'mobile', type: 'prepaid', plans });
  } catch (error) {
    _handleError(error, res, next);
  }
};

// 2. Mobile Postpaid
const getMobilePostpaidPlans = async (req, res, next) => {
  try {
    const { operatorId, circleId, search } = req.query;
    if (!operatorId || !circleId) {
      res.status(400);
      throw new Error('operatorId and circleId are required');
    }
    const plans = await plansService.getMobilePostpaid(operatorId, circleId, search);
    res.status(200).json({ success: true, service: 'mobile', type: 'postpaid', plans });
  } catch (error) {
    _handleError(error, res, next);
  }
};

// 3. DTH Packs
const getDthPacks = async (req, res, next) => {
  try {
    const { operatorId, search } = req.query;
    if (!operatorId) {
      res.status(400);
      throw new Error('operatorId is required');
    }
    const plans = await plansService.getDthPacks(operatorId, search);
    res.status(200).json({ success: true, service: 'dth', type: 'packs', plans });
  } catch (error) {
    _handleError(error, res, next);
  }
};

// 4. DTH Pack Details
const getDthPackDetails = async (req, res, next) => {
  try {
    const { operatorId, packId } = req.query;
    if (!operatorId || !packId) {
      res.status(400);
      throw new Error('operatorId and packId are required');
    }
    const plans = await plansService.getDthPackDetails(operatorId, packId);
    res.status(200).json({ success: true, service: 'dth', type: 'pack_details', plans });
  } catch (error) {
    _handleError(error, res, next);
  }
};

// 5. DTH Ala Carte
const getDthAlacarte = async (req, res, next) => {
  try {
    const { operatorId, search } = req.query;
    if (!operatorId) {
      res.status(400);
      throw new Error('operatorId is required');
    }
    const plans = await plansService.getDthAlacarte(operatorId, search);
    res.status(200).json({ success: true, service: 'dth', type: 'alacarte', plans });
  } catch (error) {
    _handleError(error, res, next);
  }
};

module.exports = {
  getMobilePrepaidPlans,
  getMobilePostpaidPlans,
  getDthPacks,
  getDthPackDetails,
  getDthAlacarte
};
