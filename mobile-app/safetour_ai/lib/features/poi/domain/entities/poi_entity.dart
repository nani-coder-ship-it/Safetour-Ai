import 'package:flutter/material.dart';

class PoiEntity {
  final String osmId;
  final String name;
  final String type;
  final String? subType;
  final String? address;
  final String? phone;
  final String? website;
  final double lat;
  final double lng;
  final double? rating;
  final double? distanceMeters;

  const PoiEntity({
    required this.osmId,
    required this.name,
    required this.type,
    this.subType,
    this.address,
    this.phone,
    this.website,
    required this.lat,
    required this.lng,
    this.rating,
    this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m away';
    } else {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)} km away';
    }
  }

  String get displaySubType {
    final s = (subType ?? '').toLowerCase().trim();
    if (s.isEmpty ||
        s == 'building' ||
        s == 'amenity' ||
        s == 'other' ||
        s == 'yes' ||
        s == 'unclassified') {
      switch (type.toLowerCase()) {
        case 'hotel':
          return 'Hotel / Lodge';
        case 'tourist_spot':
          return 'Attraction';
        case 'restaurant':
          return 'Dining';
        case 'hospital':
          return 'Hospital';
        case 'pharmacy':
          return 'Pharmacy';
        case 'police':
          return 'Police Station';
        case 'atm':
          return 'ATM / Bank';
        case 'petrol_pump':
          return 'Fuel Station';
        case 'bus_stop':
          return 'Bus Station';
        case 'railway_station':
          return 'Railway Station';
        default:
          return type
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ');
      }
    }
    switch (s) {
      case 'lodge':
        return 'Lodge';
      case 'guest_house':
        return 'Guest House';
      case 'homestay':
        return 'Homestay';
      case 'hostel':
        return 'Hostel';
      case 'dharamshala':
        return 'Dharamshala';
      case 'choultry':
        return 'Choultry';
      case 'resort':
        return 'Resort';
      case 'motel':
        return 'Motel';
      case 'bed_and_breakfast':
        return 'B&B Stay';
      case 'hotel':
        return 'Hotel';
      case 'temple':
        return 'Temple / Spiritual';
      case 'fort':
        return 'Historic Fort';
      case 'viewpoint':
        return 'Scenic Viewpoint';
      case 'waterfall':
        return 'Waterfall';
      case 'beach':
        return 'Beach Spot';
      case 'museum':
        return 'Museum / Heritage';
      case 'monument':
        return 'Heritage Monument';
      case 'park':
        return 'Park & Garden';
      case 'theme_park':
        return 'Theme Park / Zoo';
      case 'clinic':
        return 'Medical Clinic';
      case 'pharmacy':
        return 'Pharmacy';
      default:
        return s
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  Color get subTypeColor {
    final s = (subType ?? type).toLowerCase();
    switch (s) {
      case 'lodge':
        return const Color(0xFFD97706); // Warm Amber
      case 'guest_house':
        return const Color(0xFF059669); // Emerald Green
      case 'homestay':
        return const Color(0xFF10B981); // Teal
      case 'hostel':
        return const Color(0xFF6366F1); // Indigo
      case 'dharamshala':
      case 'choultry':
        return const Color(0xFFEA580C); // Saffron Orange
      case 'resort':
        return const Color(0xFF8B5CF6); // Purple
      case 'hotel':
        return const Color(0xFF4F46E5); // Deep Indigo
      case 'temple':
        return const Color(0xFFF97316); // Spiritual Saffron
      case 'fort':
        return const Color(0xFF92400E); // Historic Earth Brown
      case 'viewpoint':
        return const Color(0xFF0284C7); // Sky Blue
      case 'waterfall':
      case 'beach':
        return const Color(0xFF06B6D4); // Cyan
      case 'museum':
      case 'monument':
        return const Color(0xFF7C3AED); // Royal Violet
      case 'park':
        return const Color(0xFF16A34A); // Forest Green
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  PoiEntity copyWith({
    String? osmId,
    String? name,
    String? type,
    String? subType,
    String? address,
    String? phone,
    String? website,
    double? lat,
    double? lng,
    double? rating,
    double? distanceMeters,
  }) {
    return PoiEntity(
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      rating: rating ?? this.rating,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  /// Identifies collegiate dormitories or student housing to enforce strict isolation
  bool get isStudentAccommodation {
    final n = name.toLowerCase();
    final addr = (address ?? '').toLowerCase();
    final sub = (subType ?? '').toLowerCase();

    if (sub == 'dormitory' || sub == 'student_accommodation') return true;

    const patterns = [
      'mens hostel', "men's hostel", 'womens hostel', "women's hostel",
      'ladies hostel', 'gents hostel', "gent's hostel",
      'boys hostel', "boy's hostel", 'girls hostel', "girl's hostel",
      'student hostel', 'student accommodation', 'college hostel', 'university hostel',
      'campus hostel', 'scholars hostel', 'hostel block', 'hall of residence',
      'nelson mandela', 'kalam hostel', 'bose hostel', 'tagore hostel',
      'dormitory', 'dorm block', 'student housing', 'college mess', 'student mess',
      'pg for gents', 'pg for ladies', 'pg for boys', 'pg for girls'
    ];

    for (final pattern in patterns) {
      if (n.contains(pattern) || addr.contains(pattern)) {
        return true;
      }
    }

    const eduKeywords = ['college', 'university', 'campus', 'klu', 'institute', 'polytechnic'];
    final hasEdu = eduKeywords.any((e) => n.contains(e) || addr.contains(e));
    if (hasEdu) {
      const residentKeywords = ['hostel', 'dorm', 'residence', 'block', 'hall', 'mess', 'living', 'quarters'];
      if (residentKeywords.any((rk) => n.contains(rk) || addr.contains(rk) || sub.contains('hostel'))) {
        return true;
      }
      if (n.contains('college') || n.contains('university') || n.contains('campus') || n.contains('department')) {
        return true;
      }
    }

    return false;
  }
}
