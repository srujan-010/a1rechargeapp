class PlanPricing {
  final String amount;
  final String validity;

  PlanPricing({required this.amount, required this.validity});

  factory PlanPricing.fromJson(Map<String, dynamic> json) {
    String amt = json['Amount']?.toString() ?? json['Price']?.toString() ?? '0';
    amt = amt.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return PlanPricing(
      amount: amt,
      validity: json['Month']?.toString() ?? json['Validity']?.toString() ?? '',
    );
  }
}

class MobilePlan {
  final String id;
  final String? rs; // Amount / Price
  final String? desc; // Benefit / Description
  final String? validity; // Validity
  final String? lastUpdate; // Last update timestamp
  final String? channels; // DTH specific: Channels info
  final String? paidChannels; // DTH specific: Paid Channels info
  final String? hdChannels; // DTH specific: HD Channels info
  final String? language; // DTH specific: Language
  final List<PlanPricing>? pricingOptions; // DTH specific: multiple prices

  MobilePlan({
    required this.id,
    this.rs,
    this.desc,
    this.validity,
    this.lastUpdate,
    this.channels,
    this.paidChannels,
    this.hdChannels,
    this.language,
    this.pricingOptions,
  });

  factory MobilePlan.fromJson(Map<String, dynamic> json) {
    return MobilePlan(
      id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
      rs: json['rs']?.toString() ?? json['RS']?.toString() ?? json['amount']?.toString(),
      desc: json['desc']?.toString() ?? json['DESC']?.toString() ?? json['benefit']?.toString(),
      validity: json['validity']?.toString() ?? json['VALIDITY']?.toString(),
      lastUpdate: json['last_update']?.toString() ?? json['LAST_UPDATE']?.toString(),
      channels: json['channels']?.toString() ?? json['Channels']?.toString(),
      paidChannels: json['paidChannels']?.toString() ?? json['PaidChannels']?.toString(),
      hdChannels: json['hdChannels']?.toString() ?? json['HdChannels']?.toString(),
      language: json['language']?.toString() ?? json['Language']?.toString(),
      pricingOptions: json['PricingList'] != null 
          ? (json['PricingList'] as List).map((p) => PlanPricing.fromJson(p as Map<String, dynamic>)).toList()
          : null,
    );
  }
}
