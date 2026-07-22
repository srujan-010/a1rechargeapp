class OperatorCircleResponse {
  final String operatorName;
  final String circleName;
  final String? operatorCode;
  final String? circleCode;

  OperatorCircleResponse({
    required this.operatorName,
    required this.circleName,
    this.operatorCode,
    this.circleCode,
  });

  factory OperatorCircleResponse.fromJson(Map<String, dynamic> json) {
    return OperatorCircleResponse(
      operatorName: json['operator']?.toString() ?? json['OPERATOR']?.toString() ?? json['Operator']?.toString() ?? json['DthName']?.toString() ?? '',
      circleName: json['circle']?.toString() ?? json['CIRCLE']?.toString() ?? json['Circle']?.toString() ?? '',
      operatorCode: json['operatorCode']?.toString() ?? json['operator_code']?.toString() ?? json['OpCode']?.toString() ?? json['DthOpCode']?.toString(),
      circleCode: json['circleCode']?.toString() ?? json['circle_code']?.toString() ?? json['CircleCode']?.toString(),
    );
  }
}
