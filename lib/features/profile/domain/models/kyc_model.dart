class KycModel {
  final String? fullName;
  final String? dob;
  final String? address;
  final String? aadhaarNumber;
  final String? panNumber;
  final String? gstNumber;
  final String? shopName;
  final String? businessType;

  final String? aadhaarFront;
  final String? aadhaarBack;
  final String? panImage;
  final String? shopPhoto;
  final String? selfie;

  final String status;
  final String? remarks;
  final String? submittedAt;
  final String? approvedAt;
  final String? rejectedAt;

  KycModel({
    this.fullName,
    this.dob,
    this.address,
    this.aadhaarNumber,
    this.panNumber,
    this.gstNumber,
    this.shopName,
    this.businessType,
    this.aadhaarFront,
    this.aadhaarBack,
    this.panImage,
    this.shopPhoto,
    this.selfie,
    this.status = 'notStarted',
    this.remarks,
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
  });

  factory KycModel.fromJson(Map<String, dynamic> json) {
    return KycModel(
      fullName: json['fullName'],
      dob: json['dob'],
      address: json['address'],
      aadhaarNumber: json['aadhaarNumber'],
      panNumber: json['panNumber'],
      gstNumber: json['gstNumber'],
      shopName: json['shopName'],
      businessType: json['businessType'],
      aadhaarFront: json['aadhaarFront'],
      aadhaarBack: json['aadhaarBack'],
      panImage: json['panImage'],
      shopPhoto: json['shopPhoto'],
      selfie: json['selfie'],
      status: json['status'] ?? 'notStarted',
      remarks: json['remarks'],
      submittedAt: json['submittedAt'],
      approvedAt: json['approvedAt'],
      rejectedAt: json['rejectedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fullName != null) 'fullName': fullName,
      if (dob != null) 'dob': dob,
      if (address != null) 'address': address,
      if (aadhaarNumber != null && !aadhaarNumber!.contains('XXXX')) 'aadhaarNumber': aadhaarNumber,
      if (panNumber != null && !panNumber!.contains('*') && !panNumber!.contains('X')) 'panNumber': panNumber,
      if (gstNumber != null) 'gstNumber': gstNumber,
      if (shopName != null) 'shopName': shopName,
      if (businessType != null) 'businessType': businessType,
      if (aadhaarFront != null) 'aadhaarFront': aadhaarFront,
      if (aadhaarBack != null) 'aadhaarBack': aadhaarBack,
      if (panImage != null) 'panImage': panImage,
      if (shopPhoto != null) 'shopPhoto': shopPhoto,
      if (selfie != null) 'selfie': selfie,
    };
  }
}
