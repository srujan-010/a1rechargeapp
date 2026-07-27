import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/models/mobile_plan.dart';

bool isSamePlan(MobilePlan? selected, MobilePlan cardPlan) {
  if (selected == null) return false;
  if (selected.id.isNotEmpty && cardPlan.id.isNotEmpty) {
    return selected.id == cardPlan.id;
  }
  final selRs = double.tryParse(selected.rs ?? '0') ?? 0;
  final cardRs = double.tryParse(cardPlan.rs ?? '0') ?? 0;
  return selRs == cardRs &&
      (selected.validity ?? '') == (cardPlan.validity ?? '') &&
      (selected.desc ?? '') == (cardPlan.desc ?? '');
}

void main() {
  test('Selecting ₹10 highlights ONLY ₹10, selecting ₹500 deselects ₹10 and highlights ONLY ₹500', () {
    final plan10_A = MobilePlan(id: 'P10_A', rs: '10', validity: '1 Day', desc: 'Talktime ₹7.47');
    final plan10_B = MobilePlan(id: 'P10_B', rs: '10', validity: '2 Days', desc: '1GB Data');
    final plan500 = MobilePlan(id: 'P500', rs: '500', validity: '84 Days', desc: '2GB/day + Unlimited');

    MobilePlan? selectedPlan = plan10_A;

    // 1. Selecting ₹10 (Plan A) highlights ONLY ₹10 (Plan A)
    expect(isSamePlan(selectedPlan, plan10_A), isTrue);
    expect(isSamePlan(selectedPlan, plan10_B), isFalse);
    expect(isSamePlan(selectedPlan, plan500), isFalse);

    // 2. Selecting ₹500 deselects ₹10 and highlights ONLY ₹500
    selectedPlan = plan500;
    expect(isSamePlan(selectedPlan, plan10_A), isFalse);
    expect(isSamePlan(selectedPlan, plan10_B), isFalse);
    expect(isSamePlan(selectedPlan, plan500), isTrue);
  });
}
