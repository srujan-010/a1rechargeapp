class DthCustomerInfo {
  final String? customerName;
  final String? status;
  final String? balance;
  final String? nextRechargeDate;
  final String? monthlyPack;
  final Map<String, dynamic> rawData;

  DthCustomerInfo({
    this.customerName,
    this.status,
    this.balance,
    this.nextRechargeDate,
    this.monthlyPack,
    required this.rawData,
  });

  factory DthCustomerInfo.fromJson(Map<String, dynamic> json) {
    // The API might return these fields directly or nested under 'records' or 'data'.
    // We try to extract them dynamically.
    final data = json['records'] ?? json['data'] ?? json['DATA'] ?? json;
    
    return DthCustomerInfo(
      customerName: data['CustomerName']?.toString() ?? data['customerName']?.toString() ?? data['Name']?.toString(),
      status: data['Status']?.toString() ?? data['status']?.toString() ?? data['AccountStatus']?.toString(),
      balance: data['Balance']?.toString() ?? data['balance']?.toString(),
      nextRechargeDate: data['NextRechargeDate']?.toString() ?? data['nextRechargeDate']?.toString(),
      monthlyPack: data['MonthlyRecharge']?.toString() ?? data['monthlyRecharge']?.toString() ?? data['MonthlyPack']?.toString(),
      rawData: data as Map<String, dynamic>,
    );
  }
}
