import 'dart:convert';
import 'package:flutter/services.dart';

class RegisteredOperator {
  final String name;
  final int code;
  final String service;
  final bool active;

  const RegisteredOperator({
    required this.name,
    required this.code,
    required this.service,
    required this.active,
  });

  factory RegisteredOperator.fromJson(Map<String, dynamic> json) {
    return RegisteredOperator(
      name: json['name'] as String,
      code: json['code'] as int,
      service: json['service'] as String,
      active: json['active'] as bool,
    );
  }
}

class OperatorRegistry {
  static final OperatorRegistry _instance = OperatorRegistry._internal();
  static OperatorRegistry get instance => _instance;

  OperatorRegistry._internal();

  Map<String, List<RegisteredOperator>> _registry = {};

  Future<void> initialize() async {
    try {
      final jsonString = await rootBundle.loadString('assets/operator_registry.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      
      final Map<String, List<RegisteredOperator>> parsedRegistry = {};
      jsonMap.forEach((key, value) {
        if (value is List) {
          parsedRegistry[key] = value.map((e) => RegisteredOperator.fromJson(e as Map<String, dynamic>)).toList();
        }
      });
      
      _registry = parsedRegistry;
    } catch (e) {
      // Handle loading error
      print('Failed to load operator registry: $e');
    }
  }

  List<RegisteredOperator> getOperatorsByService(String service) {
    return _registry[service.toUpperCase()] ?? [];
  }

  RegisteredOperator? getOperatorByName(String name) {
    for (var list in _registry.values) {
      for (var op in list) {
        if (op.name.toLowerCase() == name.toLowerCase()) {
          return op;
        }
      }
    }
    return null;
  }

  RegisteredOperator? getOperatorByCode(int code) {
    for (var list in _registry.values) {
      for (var op in list) {
        if (op.code == code) {
          return op;
        }
      }
    }
    return null;
  }
}
