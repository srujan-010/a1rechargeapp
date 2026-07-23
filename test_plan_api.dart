import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://planapi.in/api';
  const memberId = '7315';
  const password = 'A1recharge';
  const mobile = '9100329521'; // Dummy number for testing

  print('==================================================');
  print('STEP 1: OperatorFetchNew Raw Response');
  
  final fetchUrl = Uri.parse('$baseUrl/Mobile/OperatorFetchNew?ApiUserID=$memberId&ApiPassword=$password&Mobileno=$mobile');
  final fetchResponse = await http.get(fetchUrl);
  print(fetchResponse.body);

  print('==================================================');
  print('STEP 2: Parsed Values');
  
  final decoded = jsonDecode(fetchResponse.body);
  print('Operator Name: ${decoded['operator'] ?? decoded['OPERATOR']}');
  print('Operator Code: ${decoded['operatorCode'] ?? decoded['operator_code']}');
  print('Circle Name: ${decoded['circle'] ?? decoded['CIRCLE']}');
  print('Circle Code: ${decoded['circleCode'] ?? decoded['circle_code']}');

  // Let's assume we want to call NewMobilePlans
  final opCode = decoded['operatorCode'] ?? decoded['operator_code'] ?? '2';
  final circleCode = decoded['circleCode'] ?? decoded['circle_code'] ?? '49';

  print('==================================================');
  print('STEP 3: Before calling NewMobilePlans');
  print('operatorcode = $opCode');
  print('cricle = $circleCode');
  final plansUrl = Uri.parse('$baseUrl/Mobile/NewMobilePlans?apimember_id=$memberId&api_password=$password&operatorcode=$opCode&cricle=$circleCode');
  print('API URL = $plansUrl');

  print('==================================================');
  print('STEP 7: Raw response from NewMobilePlans');
  final plansResponse = await http.get(plansUrl);
  print(plansResponse.body);
}
