import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/network/dio_client.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';

class GatSafetyCard extends StatefulWidget {
  const GatSafetyCard({super.key});

  @override
  State<GatSafetyCard> createState() => _GatSafetyCardState();
}

class _GatSafetyCardState extends State<GatSafetyCard> {
  bool _isLoading = false;
  Map<String, dynamic>? _safetyData;
  String? _errorMessage;
  double? _lastQueriedLat;
  double? _lastQueriedLng;

  @override
  void initState() {
    super.initState();
    _fetchRoadSafety();
  }

  Future<void> _fetchRoadSafety({double? lat, double? lng}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      double? targetLat = lat;
      double? targetLng = lng;

      if (targetLat == null || targetLng == null) {
        try {
          final locationService = sl<DeviceLocationService>();
          var pos = await locationService.getLastKnownPosition();
          if (pos == null) {
            pos = await locationService.getCurrentPosition();
          }
          if (pos != null) {
            targetLat = pos.latitude;
            targetLng = pos.longitude;
          }
        } catch (_) {}
      }

      targetLat ??= 9.5680;
      targetLng ??= 77.6740;

      _lastQueriedLat = targetLat;
      _lastQueriedLng = targetLng;

      final dio = sl<DioClient>().dio;
      final response = await dio.post(
        '/safety/check-location',
        data: {'lat': targetLat, 'lng': targetLng},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            _safetyData = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Unexpected response from AI safety service');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not fetch GAT safety score. Tap to retry.';
        });
      }
    }
  }

  void _showDetailsModal() {
    if (_safetyData == null) return;

    final score = (_safetyData!['safety_score'] as num?)?.toDouble() ?? 75.0;
    final rating = _safetyData!['safety_rating'] as String? ?? 'SAFE';
    final roadType = _safetyData!['road_type'] as String? ?? 'road';
    final length = (_safetyData!['length_meters'] as num?)?.toDouble() ?? 0.0;
    final desc = _safetyData!['description'] as String? ?? '';
    final hazards = _safetyData!['hazards'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'GATv2 Road Safety',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        rating,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Safety Score: ${score.toStringAsFixed(1)} / 100',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Road Class',
                        roadType.toUpperCase(),
                        Icons.traffic_outlined,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        'Length',
                        '${length.toStringAsFixed(0)}m',
                        Icons.straighten_outlined,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Accident Risk',
                        '${hazards['accident_risk'] ?? 20}%',
                        Icons.car_crash_outlined,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        'District Crime',
                        '${hazards['crime_score'] ?? 20}/100',
                        Icons.shield_outlined,
                        Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Flood Hazard',
                        '${hazards['flood_risk'] ?? 20}%',
                        Icons.flood_outlined,
                        Colors.cyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        'Segment ID',
                        '#${_safetyData!['edge_id'] ?? 'N/A'}',
                        Icons.tag_rounded,
                        Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hub_outlined, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Dynamic GATv2 inference based on real OSM road topology & Tamil Nadu accident/crime data.',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analyzing road safety with GATv2 model...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return GestureDetector(
        onTap: _fetchRoadSafety,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.refresh, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final score = (_safetyData?['safety_score'] as num?)?.toDouble() ?? 75.14;
    final rating = _safetyData?['safety_rating'] as String? ?? 'SAFE';
    final roadType = _safetyData?['road_type'] as String? ?? 'motorway_link';

    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationTracking && state.currentLocation != null) {
          final newLat = state.currentLocation!.latitude;
          final newLng = state.currentLocation!.longitude;
          if (_lastQueriedLat == null ||
              _lastQueriedLng == null ||
              (_lastQueriedLat! - newLat).abs() > 0.0003 ||
              (_lastQueriedLng! - newLng).abs() > 0.0003) {
            _fetchRoadSafety(lat: newLat, lng: newLng);
          }
        }
      },
      child: GestureDetector(
        onTap: _showDetailsModal,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular Safety Score Gauge
              SizedBox(
                width: 66,
                height: 66,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 66,
                      height: 66,
                      child: CircularProgressIndicator(
                        value: (score / 100.0).clamp(0.0, 1.0),
                        strokeWidth: 5.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score.round().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const Text(
                          '/100',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Safety Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row: AI ROAD SAFETY + GATv2
                    Row(
                      children: [
                        const Text(
                          'AI ROAD SAFETY',
                          style: TextStyle(
                            color: Color(0xFFBFDBFE),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GATv2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                          tooltip: 'Re-analyze',
                          onPressed: () => _fetchRoadSafety(),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Rating with Checkmark
                    Row(
                      children: [
                        Icon(
                          score >= 70 ? Icons.check_circle_rounded : (score >= 55 ? Icons.info_rounded : Icons.warning_rounded),
                          color: score >= 70 ? const Color(0xFF4ADE80) : (score >= 55 ? const Color(0xFFFBBF24) : const Color(0xFFF87171)),
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          rating == 'VERY_SAFE' || rating == 'SAFE' ? 'Safe' : (rating == 'MODERATE_RISK' ? 'Moderate' : 'Caution'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Nearest Road
                    Text(
                      'Nearest Road: ${roadType.replaceAll('_', ' ').toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Low risk in this area / description
                    Text(
                      score >= 70 ? 'Low risk in this area' : (score >= 55 ? 'Moderate risk in this area' : 'Elevated risk - exercise caution'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
