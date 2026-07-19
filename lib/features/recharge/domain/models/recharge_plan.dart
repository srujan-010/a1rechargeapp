// lib/features/recharge/domain/models/recharge_plan.dart
import 'package:equatable/equatable.dart';

enum PlanCategory { popular, topup, data, unlimited, sms, special, monthly }

class RechargePlan extends Equatable {
  const RechargePlan({
    required this.id,
    required this.category,
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
  final PlanCategory category;
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
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        category: _parseCategory(json['category'] as String?),
        pricePaise: (json['price'] as num?)?.toInt() ?? 0,
        validity: json['validity'] as String? ?? '',
        description: json['description'] as String? ?? '',
        data: json['data'] as String?,
        sms: json['sms'] as String?,
        voice: json['voice'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        isPopular: json['isPopular'] as bool? ?? false,
        isBestValue: json['isBestValue'] as bool? ?? false,
        talktime: json['talktime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
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

  static PlanCategory _parseCategory(String? raw) => switch (raw) {
        'popular' => PlanCategory.popular,
        'topup' => PlanCategory.topup,
        'data' => PlanCategory.data,
        'unlimited' => PlanCategory.unlimited,
        'sms' => PlanCategory.sms,
        'special' => PlanCategory.special,
        'monthly' => PlanCategory.monthly,
        _ => PlanCategory.popular,
      };

  static List<RechargePlan> fakeList() => [
        const RechargePlan(
          id: 'PLN001', category: PlanCategory.popular,
          pricePaise: 23900, validity: '28 Days',
          description: 'True 5G unlimited + Disney+ Hotstar Mobile',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['5G', 'OTT'], isPopular: true, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN002', category: PlanCategory.unlimited,
          pricePaise: 66900, validity: '84 Days',
          description: 'Unlimited calls + data for 84 days',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['Best Value'], isPopular: false, isBestValue: true,
        ),
        const RechargePlan(
          id: 'PLN003', category: PlanCategory.data,
          pricePaise: 9900, validity: '28 Days',
          description: 'Data add-on pack',
          data: '10 GB', sms: null, voice: null,
          isPopular: false, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN004', category: PlanCategory.topup,
          pricePaise: 10000, validity: 'No Expiry',
          description: 'Talktime recharge',
          talktime: '₹83.16',
          isPopular: false, isBestValue: false,
        ),
        const RechargePlan(
          id: 'PLN005', category: PlanCategory.popular,
          pricePaise: 74900, validity: '84 Days',
          description: '5G unlimited with 6 months Netflix',
          data: '2 GB/day', sms: '100 SMS/day', voice: 'Unlimited',
          tags: ['5G', 'Netflix'], isPopular: true, isBestValue: false,
        ),
      ];

  @override
  List<Object?> get props => [id, pricePaise, validity, category];
}
