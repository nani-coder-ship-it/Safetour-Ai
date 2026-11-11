import 'package:flutter/material.dart';

class AlertModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String severity;
  final String? locationName;
  final String? safetyTip;
  final bool read;
  final String status;
  final double? distanceKm;
  final DateTime createdAt;

  const AlertModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    this.locationName,
    this.safetyTip,
    required this.read,
    required this.status,
    this.distanceKm,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Safety Alert',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString().toLowerCase() ?? 'geofence',
      severity: json['severity']?.toString().toLowerCase() ?? 'warning',
      locationName: json['locationName']?.toString() ?? json['location']?.toString(),
      safetyTip: json['safetyTip']?.toString(),
      read: json['read'] == true,
      status: json['status']?.toString() ?? 'active',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'locationName': locationName,
      'safetyTip': safetyTip,
      'read': read,
      'status': status,
      'distanceKm': distanceKm,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AlertModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? severity,
    String? locationName,
    String? safetyTip,
    bool? read,
    String? status,
    double? distanceKm,
    DateTime? createdAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      locationName: locationName ?? this.locationName,
      safetyTip: safetyTip ?? this.safetyTip,
      read: read ?? this.read,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626); // Red
      case 'warning':
        return const Color(0xFFEA580C); // Warm Orange
      case 'advisory':
        return const Color(0xFF2563EB); // Royal Blue
      case 'info':
      default:
        return const Color(0xFF059669); // Emerald Green
    }
  }

  Color get severityBackgroundColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFEF2F2);
      case 'warning':
        return const Color(0xFFFFF7ED);
      case 'advisory':
        return const Color(0xFFEFF6FF);
      case 'info':
      default:
        return const Color(0xFFECFDF5);
    }
  }

  IconData get iconData {
    switch (type.toLowerCase()) {
      case 'weather':
        if (severity.toLowerCase() == 'critical') return Icons.thunderstorm_rounded;
        if (severity.toLowerCase() == 'warning') return Icons.cloudy_snowing;
        return Icons.wb_sunny_rounded;
      case 'wildlife':
        return Icons.pets_rounded;
      case 'roadblock':
        return Icons.traffic_rounded;
      case 'sos':
        return Icons.crisis_alert_rounded;
      case 'advisory':
        return Icons.verified_user_rounded;
      case 'geofence':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String get severityLabel {
    if (type.toLowerCase() == 'weather') {
      if (severity.toLowerCase() == 'critical') return 'SEVERE WEATHER';
      if (severity.toLowerCase() == 'warning') return 'WEATHER ALERT';
      return 'WEATHER UPDATE';
    }
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'CRITICAL';
      case 'warning':
        return 'WARNING';
      case 'advisory':
        return 'ADVISORY';
      case 'info':
      default:
        return 'SAFE ZONE';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}';
  }
}
