import 'package:equatable/equatable.dart';

class Circle extends Equatable {
  const Circle({
    required this.id,
    required this.state,
    required this.code,
    this.isActive = true,
  });

  final String id;
  final String state;
  final String code;
  final bool isActive;

  factory Circle.fromJson(Map<String, dynamic> json) => Circle(
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        state: json['state'] as String? ?? '',
        code: json['code'] as String? ?? '',
        isActive: json['status'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state,
        'code': code,
        'status': isActive,
      };

  @override
  List<Object?> get props => [id, state, code, isActive];
}
