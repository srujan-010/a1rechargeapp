// lib/features/auth/models/user_profile.dart
// Domain model for the authenticated retailer, mapped from the backend
// GET /auth/me and the login/register envelope (`data.user`).
// All government identifiers arrive pre-masked from the backend.

class BankDetails {
  const BankDetails({
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifsc,
    this.isVerified = false,
  });

  final String? accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;
  final bool isVerified;

  factory BankDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BankDetails();
    return BankDetails(
      accountHolderName: json['accountHolderName'] as String?,
      bankName: json['bankName'] as String?,
      accountNumber: json['accountNumber'] as String?,
      ifsc: json['ifsc'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }
}

class WalletInfo {
  const WalletInfo({this.balancePaise = 0, this.currency = 'INR'});

  final int balancePaise;
  final String currency;

  factory WalletInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WalletInfo();
    return WalletInfo(
      balancePaise: json['balancePaise'] as int? ?? 0,
      currency: (json['currency'] as String?) ?? 'INR',
    );
  }

  double get balanceRupees => balancePaise / 100.0;
}

class KycDocument {
  const KycDocument({required this.type, required this.url});

  final String type;
  final String url;

  factory KycDocument.fromJson(Map<String, dynamic> json) => KycDocument(
        type: (json['type'] as String?) ?? 'other',
        url: (json['url'] as String?) ?? '',
      );
}

class KycInfo {
  const KycInfo({
    this.aadhaarNumber,
    this.panNumber,
    this.gstNumber,
    this.status = 'notStarted',
    this.documents = const [],
    this.submittedAt,
    this.rejectionReason,
  });

  final String? aadhaarNumber;
  final String? panNumber;
  final String? gstNumber;
  final String status;
  final List<KycDocument> documents;
  final DateTime? submittedAt;
  final String? rejectionReason;

  factory KycInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const KycInfo();
    return KycInfo(
      aadhaarNumber: json['aadhaarNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      gstNumber: json['gstNumber'] as String?,
      status: (json['status'] as String?) ?? 'notStarted',
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => KycDocument.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.retailerId,
    required this.name,
    required this.phone,
    this.email,
    this.shopName,
    this.shopAddress,
    this.city,
    this.state,
    this.pincode,
    this.aadhaarNumber,
    this.panNumber,
    this.gstNumber,
    this.kycStatus = 'notStarted',
    this.isOnboarded = false,
    this.isVerified = false,
    this.hasMpin = false,
    this.createdAt,
    this.bank,
    this.wallet,
    this.kyc,
  });

  final String id;
  final String retailerId;
  final String name;
  final String phone;
  final String? email;
  final String? shopName;
  final String? shopAddress;
  final String? city;
  final String? state;
  final String? pincode;
  final String? aadhaarNumber;
  final String? panNumber;
  final String? gstNumber;
  final String kycStatus;
  final bool isOnboarded;
  final bool isVerified;
  final bool hasMpin;
  final DateTime? createdAt;
  final BankDetails? bank;
  final WalletInfo? wallet;
  final KycInfo? kyc;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['_id'] as String?) ?? '',
      retailerId: (json['retailerId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: json['email'] as String?,
      shopName: json['shopName'] as String?,
      shopAddress: json['shopAddress'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      gstNumber: json['gstNumber'] as String?,
      kycStatus: (json['kycStatus'] as String?) ?? 'notStarted',
      isOnboarded: json['isOnboarded'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      hasMpin: json['hasMpin'] as bool? ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      bank: BankDetails.fromJson(json['bank'] as Map<String, dynamic>?),
      wallet: WalletInfo.fromJson(json['wallet'] as Map<String, dynamic>?),
      kyc: KycInfo.fromJson(json['kyc'] as Map<String, dynamic>?),
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? shopName,
    String? shopAddress,
    String? city,
    String? state,
    String? pincode,
  }) {
    return UserProfile(
      id: id,
      retailerId: retailerId,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      aadhaarNumber: aadhaarNumber,
      panNumber: panNumber,
      gstNumber: gstNumber,
      kycStatus: kycStatus,
      isOnboarded: isOnboarded,
      isVerified: isVerified,
      hasMpin: hasMpin,
      createdAt: createdAt,
      bank: bank,
      wallet: wallet,
      kyc: kyc,
    );
  }
}
