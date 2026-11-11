import 'package:latlong2/latlong.dart';

class DangerZoneEntity {
  final String id;
  final String name;
  final String riskLevel; // 'danger', 'caution', 'safe'
  final double riskScore;
  final String category; // 'mountain_peak', 'cliff', 'river', 'lake', 'waterfall', 'reservoir', 'wildlife', 'landslide', 'general'
  final String? description;
  final List<LatLng> polygonPoints;

  const DangerZoneEntity({
    required this.id,
    required this.name,
    required this.riskLevel,
    required this.riskScore,
    required this.category,
    this.description,
    required this.polygonPoints,
  });

  bool get isDanger => riskLevel.toLowerCase() == 'danger' || riskLevel.toLowerCase() == 'red';
  bool get isCaution => riskLevel.toLowerCase() == 'caution' || riskLevel.toLowerCase() == 'yellow' || riskLevel.toLowerCase() == 'warning';
  bool get isSafe => riskLevel.toLowerCase() == 'safe' || riskLevel.toLowerCase() == 'green' || riskLevel.toLowerCase() == 'blue';

  String get displayCategory {
    switch (category.toLowerCase()) {
      case 'mountain_peak':
        return 'Mountain Peak';
      case 'cliff':
        return 'Steep Cliff';
      case 'river':
        return 'River Rapids';
      case 'lake':
        return 'Deep Lake';
      case 'waterfall':
        return 'Flash Flood Waterfall';
      case 'reservoir':
        return 'Dam Reservoir';
      case 'wildlife':
        return 'Wildlife Corridor';
      case 'landslide':
        return 'Landslide Hazard';
      default:
        return 'Danger Zone';
    }
  }
}
