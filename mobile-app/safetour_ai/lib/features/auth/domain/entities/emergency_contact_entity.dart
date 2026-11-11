class EmergencyContactEntity {
  final String? id;
  final String name;
  final String phone;
  final String relation;

  const EmergencyContactEntity({
    this.id,
    required this.name,
    required this.phone,
    this.relation = '',
  });

  EmergencyContactEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
  }) {
    return EmergencyContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }
}
