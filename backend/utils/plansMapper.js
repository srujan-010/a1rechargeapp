/**
 * plansMapper.js
 * 
 * Maps internal A1 Topup operator and circle codes to PlansInfo API codes.
 */

// Removed: operatorMap is now database-driven via ProviderOperator.plansInfoCode

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

// Removed: getPlansInfoOperator is now database-driven
/**
 * Get PlansInfo Circle Code from A1 Topup Circle Code
 * @param {String} internalCode 
 * @returns {String|null}
 */
const getPlansInfoCircle = (internalCode) => {
  return circleMap[internalCode] || null;
};

module.exports = {
  getPlansInfoCircle,
  circleMap
};
