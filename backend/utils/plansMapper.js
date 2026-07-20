/**
 * plansMapper.js
 * 
 * Maps internal A1 Topup operator and circle codes to PlansInfo API codes.
 */

// A1 Topup Operator Code -> PlansInfo Operator Code
const operatorMap = {
  // Mobile Prepaid
  'A': 'AT',   // Airtel
  'RC': 'RJ',  // RELIANCE - JIO
  'V': 'VF',   // Vodafone
  'I': 'ID',   // Idea
  'BT': 'BS',  // BSNL - TOPUP
  'BR': 'BS',  // BSNL - STV
  'MTT': 'MT', // MTNL - TOPUP
  'MTR': 'MT', // MTNL - Recharge

  // Mobile Postpaid
  'PAT': 'AT', // Airtel Postpaid
  'IP': 'ID',  // Idea Postpaid
  'VP': 'VF',  // Vodafone Postpaid
  'BP': 'BS',  // BSNL Postpaid
  'JPP': 'RJ', // JIO Postpaid

  // DTH
  'TTV': 'TS', // Tata Play (Tata Sky)
  'DTV': 'DT', // Dish TV
  'ATV': 'AD', // Airtel Digital TV
  'VTV': 'VD', // Videocon d2h
  'STV': 'SD', // Sun Direct
};

// A1 Topup Circle Code -> PlansInfo Circle Code
const circleMap = {
  '13': 'AP', // Andhra Pradesh
  '24': 'AS', // Assam
  '17': 'BR', // Bihar / Jharkhand
  '22': 'BR', // Jharkhand -> Bihar
  '7': 'CH',  // Chennai
  '5': 'DL',  // Delhi
  '12': 'GJ', // Gujarat
  '20': 'HR', // Haryana
  '21': 'HP', // Himachal Pradesh
  '25': 'JK', // Jammu And Kashmir
  '9': 'KA',  // Karnataka
  '14': 'KL', // Kerala
  '6': 'KO',  // Kolkata
  '16': 'MP', // Madhya Pradesh / Chhattisgarh
  '27': 'MP', // Chhattisgarh -> MP
  '4': 'MH',  // Maharashtra
  '3': 'MU',  // Mumbai
  '26': 'NE', // North East
  '23': 'OR', // Orissa
  '1': 'PB',  // Punjab
  '18': 'RJ', // Rajasthan
  '8': 'TN',  // Tamil Nadu
  '10': 'UE', // UP East
  '11': 'UW', // UP West
  '2': 'WB',  // West Bengal
};

/**
 * Get PlansInfo Operator Code from A1 Topup Operator Code
 * @param {String} internalCode 
 * @returns {String|null}
 */
const getPlansInfoOperator = (internalCode) => {
  return operatorMap[internalCode] || null;
};

/**
 * Get PlansInfo Circle Code from A1 Topup Circle Code
 * @param {String} internalCode 
 * @returns {String|null}
 */
const getPlansInfoCircle = (internalCode) => {
  return circleMap[internalCode] || null;
};

module.exports = {
  getPlansInfoOperator,
  getPlansInfoCircle,
  operatorMap,
  circleMap
};
