class DthCustomerInfo {
  final String? operatorName;
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
  final bool isVerified;
  final Map<String, dynamic> rawData;

  DthCustomerInfo({
    this.operatorName,
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
    this.isVerified = false,
    required this.rawData,
  });

  factory DthCustomerInfo.fromJson(Map<String, dynamic> json) {
    final data = json['DATA'] ?? json['records'] ?? json['data'] ?? json;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    
    // Verified when error code is explicitly "0"
    final err = json['error']?.toString().trim() ?? json['ERROR']?.toString().trim() ?? map['error']?.toString().trim();
    final verified = err == '0';

    final rawName = _getStr(map, ['Name', 'CustomerName', 'customerName', 'name', 'accountHolderName']);

    return DthCustomerInfo(
      operatorName: _getStr(map, ['Operator Name', 'Operator', 'operatorName', 'operator', 'DthName']),
      customerName: _cleanName(rawName),
      status: _getStr(map, ['Status', 'status', 'AccountStatus', 'accountStatus']),
      balance: _getStr(map, ['Balance', 'balance', 'AccountBalance', 'accountBalance']),
      nextRechargeDate: _getStr(map, ['Duedate', 'DTH Due Date', 'Due Date', 'dueDate', 'Next Recharge Date', 'NextRechargeDate', 'nextRechargeDate']),
      monthlyPack: _getStr(map, ['Monthly', 'monthly', 'MonthlyRecharge', 'monthlyRecharge', 'MonthlyPack', 'monthlyPack', 'MonthlyPlan']),
      vcNumber: _getStr(map, ['DTH Customer No', 'dthCustomerNo', 'VC', 'vc', 'VCNumber', 'vcNumber', 'SubscriberID', 'subscriberId']),
      rmn: _getStr(map, ['Mobile No', 'mobileNo', 'Rmn', 'RMN', 'rmn', 'RegisteredMobile', 'registeredMobile', 'Mobile', 'mobile']),
      currentPlan: _getStr(map, ['Plan', 'plan', 'CurrentPlan', 'currentPlan', 'PlanName', 'planName', 'Package']),
      lastRechargeDate: _getStr(map, ['LastRechargeDate', 'lastRechargeDate', 'LastRecharge', 'lastRecharge']),
      address: _getStr(map, ['Address', 'address', 'CustomerAddress']),
      city: _getStr(map, ['City', 'city']),
      district: _getStr(map, ['District', 'district']),
      state: _getStr(map, ['State', 'state']),
      pincode: _getStr(map, ['PIN Code', 'PinCode', 'pincode', 'Pincode', 'pinCode', 'Zip']),
      isVerified: verified,
      rawData: map,
    );
  }

  String? get formattedAddress {
    final parts = <String>[];
    if (address != null && address!.trim().isNotEmpty) parts.add(address!.trim());
    if (city != null && city!.trim().isNotEmpty && !(address?.contains(city!.trim()) ?? false)) parts.add(city!.trim());
    if (district != null && district!.trim().isNotEmpty && !(address?.contains(district!.trim()) ?? false)) parts.add(district!.trim());
    if (state != null && state!.trim().isNotEmpty && !(address?.contains(state!.trim()) ?? false)) parts.add(state!.trim());
    if (pincode != null && pincode!.trim().isNotEmpty && !(address?.contains(pincode!.trim()) ?? false)) parts.add(pincode!.trim());
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  static String? _cleanName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();
    // Fix trailing space before dot e.g. "MR Milind ." -> "MR Milind."
    s = s.replaceAll(RegExp(r'\s+\.$'), '.');
    return s;
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
