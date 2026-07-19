class BankDetails {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String? branch;
  final String? city;
  final String accountType;
  final String? upiId;
  final String verificationStatus;
  final String? verificationRemarks;
  final String? documentUrl;

  BankDetails({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    this.branch,
    this.city,
    this.accountType = 'Savings',
    this.upiId,
    this.verificationStatus = 'pending',
    this.verificationRemarks,
    this.documentUrl,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      accountHolderName: json['accountHolderName'] ?? '',
      bankName: json['bankName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      ifsc: json['ifsc'] ?? '',
      branch: json['branch'],
      city: json['city'],
      accountType: json['accountType'] ?? 'Savings',
      upiId: json['upiId'],
      verificationStatus: json['verificationStatus'] ?? 'pending',
      verificationRemarks: json['verificationRemarks'],
      documentUrl: json['documentUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifsc': ifsc,
      'branch': branch,
      'city': city,
      'accountType': accountType,
      'upiId': upiId,
      'verificationStatus': verificationStatus,
      'verificationRemarks': verificationRemarks,
      'documentUrl': documentUrl,
    };
  }
}
