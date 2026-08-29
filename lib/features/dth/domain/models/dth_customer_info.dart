class DthCustomerInfo {
  final String? customerName;
  final String? status;
  final String? balance;
  final String? nextRechargeDate;
  final String? monthlyPack;
  final String? vcNumber;
  final String? rmn;
  final String? currentPlan;
  final String? lastRechargeDate;
  final String? address;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final Map<String, dynamic> rawData;

  DthCustomerInfo({
    this.customerName,
    this.status,
    this.balance,
    this.nextRechargeDate,
    this.monthlyPack,
    this.vcNumber,
    this.rmn,
    this.currentPlan,
    this.lastRechargeDate,
    this.address,
    this.city,
    this.district,
    this.state,
    this.pincode,
    required this.rawData,
  });

  factory DthCustomerInfo.fromJson(Map<String, dynamic> json) {
    final data = json['records'] ?? json['data'] ?? json['DATA'] ?? json;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    
    return DthCustomerInfo(
      customerName: _getStr(map, ['CustomerName', 'customerName', 'Name', 'name', 'accountHolderName']),
      status: _getStr(map, ['Status', 'status', 'AccountStatus', 'accountStatus']),
      balance: _getStr(map, ['Balance', 'balance', 'AccountBalance', 'accountBalance']),
      nextRechargeDate: _getStr(map, ['NextRechargeDate', 'nextRechargeDate', 'DueDate', 'dueDate']),
      monthlyPack: _getStr(map, ['MonthlyRecharge', 'monthlyRecharge', 'MonthlyPack', 'monthlyPack', 'MonthlyPlan']),
      vcNumber: _getStr(map, ['VC', 'vc', 'VCNumber', 'vcNumber', 'SubscriberID', 'subscriberId']),
      rmn: _getStr(map, ['RMN', 'rmn', 'RegisteredMobile', 'registeredMobile', 'Mobile', 'mobile']),
      currentPlan: _getStr(map, ['Plan', 'plan', 'CurrentPlan', 'currentPlan', 'PlanName', 'planName', 'Package']),
      lastRechargeDate: _getStr(map, ['LastRechargeDate', 'lastRechargeDate', 'LastRecharge', 'lastRecharge']),
      address: _getStr(map, ['Address', 'address', 'CustomerAddress']),
      city: _getStr(map, ['City', 'city']),
      district: _getStr(map, ['District', 'district']),
      state: _getStr(map, ['State', 'state']),
      pincode: _getStr(map, ['PinCode', 'pincode', 'Pincode', 'pinCode', 'Zip']),
      rawData: map,
    );
  }

  static String? _getStr(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map[k] != null && map[k].toString().trim().isNotEmpty && map[k].toString().trim() != 'null') {
        return map[k].toString().trim();
      }
    }
    return null;
  }
}
