// lib/core/utils/operator_normalizer.dart

/// Unified Normalized Operator Representation
class NormalizedOperatorResult {
  final String operatorId;           // Canonical ID e.g. "11" for Jio, "2" for Airtel
  final String operatorName;         // Clean user-facing name e.g. "Jio", "Airtel", "Vi", "BSNL TOPUP"
  final String providerOperatorCode; // PlansAPI code e.g. "11" for Jio, "2" for Airtel, "23" for Vi, "4" for BSNL
  final String a1TopupCode;           // A1Topup provider code e.g. "RC" for Jio, "A" for Airtel, "V" for Vi, "BT" for BSNL
  final String circleName;           // Clean circle name e.g. "Andhra Pradesh"
  final String circleCode;            // Numeric circle code e.g. "49"

  const NormalizedOperatorResult({
    required this.operatorId,
    required this.operatorName,
    required this.providerOperatorCode,
    required this.a1TopupCode,
    required this.circleName,
    required this.circleCode,
  });

  Map<String, dynamic> toJson() => {
        'operatorId': operatorId,
        'operatorName': operatorName,
        'providerOperatorCode': providerOperatorCode,
        'a1TopupCode': a1TopupCode,
        'circleName': circleName,
        'circleCode': circleCode,
      };
}

/// Centralized Operator & Circle Normalizer
class OperatorNormalizer {
  /// Normalize raw operator string / opcode and circle string / circleCode
  /// from detection API or database into authoritative NormalizedOperatorResult.
  static NormalizedOperatorResult? normalize({
    String? rawOperator,
    String? rawOpCode,
    String? rawCircle,
    String? rawCircleCode,
  }) {
    final opStr = (rawOperator ?? '').trim().toUpperCase();
    final opCodeStr = (rawOpCode ?? '').trim().toUpperCase();

    String? normOpName;
    String? normPlanOpCode;
    String? normA1TopupCode;
    String? normOpId;

    // ── 1. RELIANCE JIO ──
    if (opStr.contains('JIO') ||
        opStr.contains('RELIANCE JIO') ||
        opStr.contains('RELIANCE_JIO') ||
        opStr.contains('RELIANCEJIO') ||
        opCodeStr == '11' ||
        opCodeStr == 'RC' ||
        opCodeStr == 'RJ' ||
        opCodeStr == 'JO') {
      normOpName = 'Jio';
      normPlanOpCode = '11';
      normA1TopupCode = 'RC';
      normOpId = '11';
    }
    // ── 2. AIRTEL ──
    else if (opStr.contains('AIRTEL') ||
             opStr.contains('BHARTI') ||
             opCodeStr == '2' ||
             opCodeStr == '13' ||
             opCodeStr == 'AT' ||
             opCodeStr == 'DA' ||
             opCodeStr == 'A') {
      normOpName = 'Airtel';
      normPlanOpCode = '2';
      normA1TopupCode = 'A';
      normOpId = '2';
    }
    // ── 3. VODAFONE IDEA / VI ──
    else if (opStr.contains('VODAFONE') ||
             opStr.contains('IDEA') ||
             opStr.contains('VI') ||
             opCodeStr == '23' ||
             opCodeStr == '6' ||
             opCodeStr == 'V' ||
             opCodeStr == 'I' ||
             opCodeStr == 'VF' ||
             opCodeStr == 'ID') {
      normOpName = 'Vi';
      normPlanOpCode = '23';
      normA1TopupCode = 'V';
      normOpId = '23';
    }
    // ── 4. BSNL SPECIAL / STV ──
    else if ((opStr.contains('BSNL') && (opStr.contains('SPECIAL') || opStr.contains('STV'))) ||
             opCodeStr == '5' ||
             opCodeStr == 'BR') {
      normOpName = 'BSNL SPECIAL';
      normPlanOpCode = '5';
      normA1TopupCode = 'BR';
      normOpId = '5';
    }
    // ── 5. BSNL TOPUP ──
    else if (opStr.contains('BSNL') ||
             opStr.contains('BHARAT SANCHAR') ||
             opCodeStr == '4' ||
             opCodeStr == 'BT' ||
             opCodeStr == 'CG') {
      normOpName = 'BSNL TOPUP';
      normPlanOpCode = '4';
      normA1TopupCode = 'BT';
      normOpId = '4';
    }
    // ── 6. MTNL ──
    else if (opStr.contains('MTNL') || opCodeStr == 'MT' || opCodeStr == 'MTR' || opCodeStr == 'MTT') {
      normOpName = 'MTNL TOPUP';
      normPlanOpCode = 'MT';
      normA1TopupCode = 'MTR';
      normOpId = 'MT';
    }

    // If operator could not be identified, return null (DO NOT FALL BACK TO BSNL!)
    if (normOpName == null) {
      return null;
    }

    // ── CIRCLE NORMALIZATION ──
    final circleInfo = _normalizeCircle(rawCircle, rawCircleCode);

    return NormalizedOperatorResult(
      operatorId: normOpId!,
      operatorName: normOpName,
      providerOperatorCode: normPlanOpCode!,
      a1TopupCode: normA1TopupCode!,
      circleName: circleInfo.circleName,
      circleCode: circleInfo.circleCode,
    );
  }

  static ({String circleName, String circleCode}) _normalizeCircle(String? rawCircle, String? rawCircleCode) {
    final circleStr = (rawCircle ?? '').trim().toLowerCase();
    final codeStr = (rawCircleCode ?? '').trim();

    final Map<String, ({String name, String code})> registry = {
      'ap': (name: 'Andhra Pradesh', code: '49'),
      'andhra pradesh': (name: 'Andhra Pradesh', code: '49'),
      '49': (name: 'Andhra Pradesh', code: '49'),

      'assam': (name: 'Assam', code: '56'),
      '56': (name: 'Assam', code: '56'),

      'bihar': (name: 'Bihar & Jharkhand', code: '52'),
      'bihar & jharkhand': (name: 'Bihar & Jharkhand', code: '52'),
      'jharkhand': (name: 'Bihar & Jharkhand', code: '52'),
      '52': (name: 'Bihar & Jharkhand', code: '52'),

      'chennai': (name: 'Chennai', code: '40'),
      '40': (name: 'Chennai', code: '40'),

      'delhi': (name: 'Delhi NCR', code: '10'),
      'delhi ncr': (name: 'Delhi NCR', code: '10'),
      '10': (name: 'Delhi NCR', code: '10'),

      'gujarat': (name: 'Gujarat', code: '98'),
      '98': (name: 'Gujarat', code: '98'),

      'haryana': (name: 'Haryana', code: '96'),
      '96': (name: 'Haryana', code: '96'),

      'hp': (name: 'Himachal Pradesh', code: '03'),
      'himachal pradesh': (name: 'Himachal Pradesh', code: '03'),
      '03': (name: 'Himachal Pradesh', code: '03'),
      '3': (name: 'Himachal Pradesh', code: '03'),

      'j&k': (name: 'Jammu & Kashmir', code: '55'),
      'jammu & kashmir': (name: 'Jammu & Kashmir', code: '55'),
      'jammu and kashmir': (name: 'Jammu & Kashmir', code: '55'),
      '55': (name: 'Jammu & Kashmir', code: '55'),

      'karnataka': (name: 'Karnataka', code: '06'),
      '6': (name: 'Karnataka', code: '06'),
      '06': (name: 'Karnataka', code: '06'),

      'kerala': (name: 'Kerala', code: '95'),
      '95': (name: 'Kerala', code: '95'),

      'kolkata': (name: 'Kolkata', code: '31'),
      'kolkatta': (name: 'Kolkata', code: '31'),
      '31': (name: 'Kolkata', code: '31'),

      'maharashtra': (name: 'Maharashtra', code: '90'),
      'maharashtra & goa': (name: 'Maharashtra', code: '90'),
      'goa': (name: 'Maharashtra', code: '90'),
      '90': (name: 'Maharashtra', code: '90'),

      'mp': (name: 'Madhya Pradesh', code: '93'),
      'madhya pradesh': (name: 'Madhya Pradesh', code: '93'),
      'mp and chattisgarh': (name: 'Madhya Pradesh', code: '93'),
      'chhattisgarh': (name: 'Madhya Pradesh', code: '93'),
      '93': (name: 'Madhya Pradesh', code: '93'),

      'mumbai': (name: 'Mumbai', code: '92'),
      '92': (name: 'Mumbai', code: '92'),

      'nesa': (name: 'North East', code: '16'),
      'north east': (name: 'North East', code: '16'),
      '16': (name: 'North East', code: '16'),

      'orissa': (name: 'Odisha', code: '53'),
      'odisha': (name: 'Odisha', code: '53'),
      '53': (name: 'Odisha', code: '53'),

      'punjab': (name: 'Punjab', code: '02'),
      '2': (name: 'Punjab', code: '02'),
      '02': (name: 'Punjab', code: '02'),

      'rajasthan': (name: 'Rajasthan', code: '70'),
      '70': (name: 'Rajasthan', code: '70'),

      'tamil nadu': (name: 'Tamil Nadu', code: '94'),
      'tamilnadu': (name: 'Tamil Nadu', code: '94'),
      '94': (name: 'Tamil Nadu', code: '94'),

      'up east': (name: 'UP East', code: '54'),
      'up(east)': (name: 'UP East', code: '54'),
      '54': (name: 'UP East', code: '54'),

      'up west': (name: 'UP West', code: '97'),
      'up(west)': (name: 'UP West', code: '97'),
      '97': (name: 'UP West', code: '97'),

      'west bengal': (name: 'West Bengal', code: '51'),
      '51': (name: 'West Bengal', code: '51'),
    };

    if (registry.containsKey(circleStr)) {
      final match = registry[circleStr]!;
      return (circleName: match.name, circleCode: match.code);
    }
    if (registry.containsKey(codeStr)) {
      final match = registry[codeStr]!;
      return (circleName: match.name, circleCode: match.code);
    }

    final fallbackName = (rawCircle != null && rawCircle.trim().isNotEmpty) ? rawCircle.trim() : 'India';
    final fallbackCode = (rawCircleCode != null && rawCircleCode.trim().isNotEmpty) ? rawCircleCode.trim() : '49';
    return (circleName: fallbackName, circleCode: fallbackCode);
  }
}
