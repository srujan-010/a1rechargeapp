// lib/features/recharge/domain/models/recharge_plan.dart
import 'package:equatable/equatable.dart';

class RechargePlan extends Equatable {
  const RechargePlan({
    required this.id,
    required this.categoryName,
    required this.pricePaise,
    required this.validity,
    required this.description,
    this.data,
    this.sms,
    this.voice,
    this.tags = const [],
    this.isPopular = false,
    this.isBestValue = false,
    this.talktime,
  });

  final String id;
  final String categoryName;
  final int pricePaise; // Always in paise
  final String validity; // e.g. "28 Days", "84 Days"
  final String description;
  final String? data;   // e.g. "1.5 GB/day"
  final String? sms;    // e.g. "100 SMS/day"
  final String? voice;  // e.g. "Unlimited Calls"
  final List<String> tags; // "5G", "International", etc.
  final bool isPopular;
  final bool isBestValue;
  final String? talktime; // for topup plans

  factory RechargePlan.fromJson(Map<String, dynamic> json) => RechargePlan(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? json['amount']?.toString() ?? '',
        categoryName: json['category']?.toString() ?? 'Others',
        pricePaise: (json['amount'] != null 
            ? (num.tryParse(json['amount'].toString())?.toInt() ?? 0) * 100 
            : (num.tryParse(json['price']?.toString() ?? '0')?.toInt() ?? 0)),
        validity: json['validity']?.toString() ?? '',
        description: json['description']?.toString() ?? json['benefit']?.toString() ?? '',
        data: json['data']?.toString(),
        sms: json['sms']?.toString(),
        voice: json['voice']?.toString() ?? json['calls']?.toString(),
        tags: _parseTags(json['tags']) ?? _parseTags(json['subscriptions']) ?? [],
        isPopular: json['isPopular'] as bool? ?? false,
        isBestValue: json['isBestValue'] as bool? ?? false,
        talktime: json['talktime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': categoryName,
        'price': pricePaise,
        'validity': validity,
        'description': description,
        'data': data,
        'sms': sms,
        'voice': voice,
        'tags': tags,
        'isPopular': isPopular,
        'isBestValue': isBestValue,
        'talktime': talktime,
      };



  static List<String>? _parseTags(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [raw.toString()];
  }

  static List<RechargePlan> fakeList() => [
        const RechargePlan(
          id: 'PLN001', categoryName: 'Popular',
          pricePaise: 23900, validity: '28 Days',
          description: 'True 5G unlimited + Disney+ Hotstar Mobile',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['5G', 'OTT'], isPopular: true, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN002', categoryName: 'Unlimited',
          pricePaise: 66900, validity: '84 Days',
          description: 'Unlimited calls + data for 84 days',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['Best Value'], isPopular: false, isBestValue: true,
        ),
        const RechargePlan(
          id: 'PLN003', categoryName: 'Data',
          pricePaise: 9900, validity: '28 Days',
          description: 'Data add-on pack',
          data: '10 GB', sms: null, voice: null,
          isPopular: false, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN004', categoryName: 'Top Up',
          pricePaise: 10000, validity: 'No Expiry',
          description: 'Talktime recharge',
          talktime: '₹83.16',
          isPopular: false, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN005', categoryName: 'Popular',
          pricePaise: 74900, validity: '84 Days',
          description: '5G unlimited with 6 months Netflix',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['5G', 'Netflix'], isPopular: true, isBestValue: false,
        ),
      ];

  @override
  List<Object?> get props => [id, pricePaise, validity, categoryName];
}
