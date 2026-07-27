import 'mobile_plan.dart';

class PlanCategory {
  final String name;
  final List<MobilePlan> plans;

  PlanCategory({
    required this.name,
    required this.plans,
  });

  factory PlanCategory.fromJson(Map<String, dynamic> json) {
    return PlanCategory(
      name: json['name']?.toString() ?? '',
      plans: (json['plans'] as List<dynamic>?)
              ?.map((p) => MobilePlan.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'plans': plans.map((p) => p.toJson()).toList(),
    };
  }
}
