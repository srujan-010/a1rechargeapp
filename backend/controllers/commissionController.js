const slabs = [
  // Mobile
  { id: 'SLAB001', serviceType: 'mobile', operatorName: 'Airtel', commissionType: 'percentage', commissionValue: 1.00, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB002', serviceType: 'mobile', operatorName: 'Jio', commissionType: 'percentage', commissionValue: 0.80, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB003', serviceType: 'mobile', operatorName: 'Vi', commissionType: 'percentage', commissionValue: 2.70, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB004', serviceType: 'mobile', operatorName: 'BSNL', commissionType: 'percentage', commissionValue: 2.00, effectiveFrom: new Date().toISOString() },
  // DTH
  { id: 'SLAB005', serviceType: 'dth', operatorName: 'Tata Play', commissionType: 'percentage', commissionValue: 3.20, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB006', serviceType: 'dth', operatorName: 'Dish TV', commissionType: 'percentage', commissionValue: 3.25, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB007', serviceType: 'dth', operatorName: 'Sun Direct', commissionType: 'percentage', commissionValue: 3.25, effectiveFrom: new Date().toISOString() },
  // Electricity
  { id: 'SLAB008', serviceType: 'bbps', operatorName: 'TSSPDCL', commissionType: 'percentage', commissionValue: 0.40, effectiveFrom: new Date().toISOString() },
  { id: 'SLAB009', serviceType: 'bbps', operatorName: 'TGSPDCL', commissionType: 'percentage', commissionValue: 0.40, effectiveFrom: new Date().toISOString() },
];

const getActiveSlabs = (req, res) => {
  res.json({
    success: true,
    data: slabs
  });
};

const getCommissionForOperator = (operatorName) => {
  return slabs.find(s => s.operatorName.toLowerCase() === operatorName.toLowerCase());
};

const getCommissionForOperatorAndService = (serviceType, operatorName) => {
  return slabs.find(s => 
    s.serviceType.toLowerCase() === serviceType.toLowerCase() &&
    s.operatorName.toLowerCase() === operatorName.toLowerCase()
  );
};

module.exports = {
  getActiveSlabs,
  getCommissionForOperator,
  getCommissionForOperatorAndService
};
