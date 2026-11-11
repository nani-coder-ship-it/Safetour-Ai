import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../injection_container.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../config/map_config.dart';
import '../../domain/entities/map_marker_entity.dart';
import '../../domain/entities/map_zone_entity.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../poi/domain/entities/poi_entity.dart';
import '../../../poi/domain/usecases/search_places.dart';
import '../../../poi/domain/usecases/get_nearby_pois.dart';
import '../../../geofence/domain/entities/danger_zone_entity.dart';
import '../../../ai_assistant/presentation/pages/chat_page.dart';

class MapPage extends StatefulWidget {
  final PoiEntity? targetPoi;

  const MapPage({super.key, this.targetPoi});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  AnimationController? _cameraAnimationController;

  // Active Map Tile Style URL (Defaults to standard colorful OpenStreetMap)
  String _currentTileUrl = MapConfig.defaultTileUrl;

  /// Smoothly animates the map camera center and zoom level to [destLocation]
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!mounted) return;
    if (destLocation.latitude.isNaN || destLocation.longitude.isNaN || destZoom.isNaN) return;

    _cameraAnimationController?.stop();
    _cameraAnimationController?.dispose();
    _cameraAnimationController = null;

    final camera = _mapController.camera;
    final startLat = camera.center.latitude;
    final startLng = camera.center.longitude;
    final startZoom = camera.zoom;

    if (startLat.isNaN || startLng.isNaN || startZoom.isNaN) {
      _mapController.move(destLocation, destZoom);
      return;
    }

    final latTween = Tween<double>(begin: startLat, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: startLng, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _cameraAnimationController = controller;

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      if (!mounted) return;
      final lat = latTween.evaluate(animation);
      final lng = lngTween.evaluate(animation);
      final currentZoom = zoomTween.evaluate(animation);
      if (!lat.isNaN && !lng.isNaN && !currentZoom.isNaN &&
          lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0) {
        _mapController.move(LatLng(lat, lng), currentZoom);
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
        if (_cameraAnimationController == controller) {
          _cameraAnimationController = null;
        }
      }
    });

    controller.forward();
  }

  // Search & Exploration State
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<PoiEntity> _searchResults = [];
  PoiEntity? _selectedPlace;
  List<PoiEntity> _categoryPois = [];
  String? _activeCategory;

  // Google Maps-Style Live Location Following State
  // True initially (or when user taps My Location), False when user pans/drags map or searches
  bool _isFollowingUser = true;
  bool _hasInitiallyCentered = false;

  // Real-time Geofence Breach Tracker for Fake GPS and Live Movement
  String? _lastAlertedDangerZone;

  void _checkGeofenceBreach(LatLng userPos, List<DangerZoneEntity> zones) {
    if (zones.isEmpty) return;
    DangerZoneEntity? breachedZone;
    for (final zone in zones) {
      if (zone.isDanger && _isPointInsidePolygon(userPos, zone.polygonPoints)) {
        breachedZone = zone;
        break;
      }
    }

    if (breachedZone != null) {
      if (_lastAlertedDangerZone != breachedZone.name) {
        _lastAlertedDangerZone = breachedZone.name;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDangerZoneDetails(breachedZone!);
          }
        });
      }
    } else {
      _lastAlertedDangerZone = null;
    }
  }

  // Current camera center coordinates for the floating badge
  double? _cameraLat;
  double? _cameraLng;

  static const List<Map<String, dynamic>> _quickCategories = [
    {
      'type': 'hotel',
      'label': 'Hotels & Lodges',
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF4F46E5),
    },
    {
      'type': 'tourist_spot',
      'label': 'Attractions',
      'icon': Icons.attractions_rounded,
      'color': Color(0xFFEC4899),
    },
    {
      'type': 'restaurant',
      'label': 'Food & Cafes',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'type': 'hospital',
      'label': 'Hospitals',
      'icon': Icons.local_hospital_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'type': 'police',
      'label': 'Police',
      'icon': Icons.local_police_rounded,
      'color': Color(0xFF3B82F6),
    },
  ];

  @override
  void initState() {
    super.initState();
    context.read<MapBloc>().add(InitializeMap());

    if (widget.targetPoi != null) {
      _selectedPlace = widget.targetPoi;
      _isFollowingUser = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _cameraAnimationController?.dispose();
    super.dispose();
  }

  bool _hasAutoLoadedNearby = false;

  void _autoLoadNearbyPlaces(LatLng pos) {
    if (_hasAutoLoadedNearby) return;
    _hasAutoLoadedNearby = true;
    _fetchCategoryPois('restaurant');
  }

  /// Tap anywhere on the map to inspect any building or spot (like Google Maps)
  Future<void> _onMapTapped(LatLng point) async {
    FocusScope.of(context).unfocus();

    // Check if user tapped inside any active danger zone
    final mapState = context.read<MapBloc>().state;
    if (mapState is MapLoaded && mapState.activeZones.isNotEmpty) {
      for (final zone in mapState.activeZones) {
        if (_isPointInsidePolygon(point, zone.polygonPoints)) {
          _showDangerZoneDetails(zone);
          return;
        }
      }
    }

    final tempId = 'tapped_${point.latitude.toStringAsFixed(5)}_${point.longitude.toStringAsFixed(5)}';

    setState(() {
      _selectedPlace = PoiEntity(
        osmId: tempId,
        name: 'Inspecting place...',
        type: 'place',
        subType: 'Building / Landmark',
        lat: point.latitude,
        lng: point.longitude,
        address: 'Fetching details from OpenStreetMap...',
      );
      _isFollowingUser = false;
    });

    try {
      final dio = sl<DioClient>().dio;
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': point.latitude,
          'lon': point.longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(headers: {
          'User-Agent': 'SafeTourAI-App/1.0 (contact@safetour.ai)',
        }),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final addressMap = (data['address'] as Map<String, dynamic>?) ?? {};

        final rawName = data['name']?.toString() ??
            addressMap['building']?.toString() ??
            addressMap['amenity']?.toString() ??
            addressMap['shop']?.toString() ??
            addressMap['road']?.toString() ??
            addressMap['residential']?.toString() ??
            addressMap['quarter']?.toString() ??
            addressMap['suburb']?.toString() ??
            'Selected Location';

        final displayName = data['display_name']?.toString() ??
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        final placeType = data['type']?.toString() ?? 'place';
        final subType = addressMap['amenity']?.toString() ??
            addressMap['shop']?.toString() ??
            addressMap['quarter']?.toString() ??
            addressMap['suburb']?.toString() ??
            placeType;

        if (mounted && _selectedPlace?.osmId == tempId) {
          setState(() {
            _selectedPlace = PoiEntity(
              osmId: tempId,
              name: rawName.isNotEmpty ? rawName : 'Selected Building',
              type: placeType,
              subType: subType,
              lat: point.latitude,
              lng: point.longitude,
              address: displayName,
            );
          });
        }
      }
    } catch (_) {
      if (mounted && _selectedPlace?.osmId == tempId) {
        setState(() {
          _selectedPlace = PoiEntity(
            osmId: tempId,
            name: 'Selected Building / Location',
            type: 'place',
            subType: 'Point of Interest',
            lat: point.latitude,
            lng: point.longitude,
            address: '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          );
        });
      }
    }
  }

  void _showLayerSwitcherBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Map Style & Layers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildLayerTileOption(
                        label: 'Standard OSM',
                        icon: Icons.map_rounded,
                        url: MapConfig.standardOsmTileUrl,
                        description: 'Vibrant & Clean',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLayerTileOption(
                        label: 'Satellite',
                        icon: Icons.satellite_alt_rounded,
                        url: MapConfig.satelliteTileUrl,
                        description: 'Real Earth Photos',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLayerTileOption(
                        label: 'Humanitarian',
                        icon: Icons.emergency_rounded,
                        url: MapConfig.humanitarianOsmTileUrl,
                        description: 'High Contrast',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLayerTileOption(
                        label: 'MapTiler',
                        icon: Icons.palette_rounded,
                        url: MapConfig.maptilerStreetsUrl,
                        description: 'Vector Pastel',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerTileOption({
    required String label,
    required IconData icon,
    required String url,
    required String description,
  }) {
    final isSelected = _currentTileUrl == url;
    return InkWell(
      onTap: () {
        setState(() {
          _currentTileUrl = url;
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchQueryChanged(String query, double? userLat, double? userLng) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final searchPlaces = sl<SearchPlaces>();
        final results = await searchPlaces(query, lat: userLat, lng: userLng);
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchResults = results;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
        }
      }
    });
  }

  void _selectSearchResult(PoiEntity place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPlace = place;
      _searchResults = [];
      _searchController.text = place.name;
      _isFollowingUser = false; // User navigated to a searched place!
    });

    if (!place.lat.isNaN && !place.lat.isInfinite &&
        !place.lng.isNaN && !place.lng.isInfinite &&
        place.lat >= -90.0 && place.lat <= 90.0 &&
        place.lng >= -180.0 && place.lng <= 180.0) {
      _animatedMapMove(LatLng(place.lat, place.lng), MapConfig.placeFocusZoom);
    }
  }

  Future<void> _fetchCategoryPois(String type) async {
    if (_activeCategory == type) {
      // Toggle off
      setState(() {
        _activeCategory = null;
        _categoryPois = [];
      });
      return;
    }

    setState(() {
      _activeCategory = type;
      _isSearching = true;
    });

    try {
      // Query around current camera center or live location
      final centerLat = _cameraLat ?? 14.4265;
      final centerLng = _cameraLng ?? 79.9565;
      final getNearby = sl<GetNearbyPOIs>();
      final results = await getNearby(
        lat: centerLat,
        lng: centerLng,
        radiusMeters: 4000,
        type: type,
      );

      if (mounted) {
        setState(() {
          _isSearching = false;
          _categoryPois = results;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _recenterOnUser(LatLng? userPosition) {
    if (userPosition == null) return;
    setState(() {
      _isFollowingUser = true;
      _selectedPlace = null;
      _searchController.clear();
      _searchResults = [];
    });

    _animatedMapMove(userPosition, MapConfig.defaultZoom);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Centered on your live location'),
          ],
        ),
        duration: Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  MarkerType _resolveMarkerType(String type) {
    switch (type) {
      case 'hotel':
        return MarkerType.hotel;
      case 'tourist_spot':
        return MarkerType.tourist_spot;
      case 'restaurant':
        return MarkerType.restaurant;
      case 'hospital':
        return MarkerType.hospital;
      case 'police':
        return MarkerType.police;
      case 'atm':
        return MarkerType.atm;
      case 'petrol_pump':
        return MarkerType.petrol_pump;
      case 'bus_stop':
        return MarkerType.bus_stop;
      case 'toilet':
        return MarkerType.toilet;
      default:
        return MarkerType.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapLoaded) {
            // First time initialization camera centering
            if (!_hasInitiallyCentered) {
              _hasInitiallyCentered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.targetPoi != null &&
                    !widget.targetPoi!.lat.isNaN && !widget.targetPoi!.lat.isInfinite &&
                    !widget.targetPoi!.lng.isNaN && !widget.targetPoi!.lng.isInfinite &&
                    widget.targetPoi!.lat >= -90.0 && widget.targetPoi!.lat <= 90.0) {
                  _isFollowingUser = false;
                  _mapController.move(
                    LatLng(widget.targetPoi!.lat, widget.targetPoi!.lng),
                    MapConfig.placeFocusZoom,
                  );
                } else if (state.userPosition != null) {
                  _mapController.move(
                    state.userPosition!,
                    MapConfig.defaultZoom,
                  );
                  _autoLoadNearbyPlaces(state.userPosition!);
                }
              });
            } else if (_isFollowingUser && state.userPosition != null) {
              // ONLY follow user when tracking mode is explicitly ON
              try {
                _mapController.move(
                  state.userPosition!,
                  _mapController.camera.zoom,
                );
              } catch (_) {}
            }
            // Automatic Geofence Danger Zone Breach Detection (Real GPS / Fake GPS)
            if (state.userPosition != null && state.activeZones.isNotEmpty) {
              _checkGeofenceBreach(state.userPosition!, state.activeZones);
            }
          }
        },
        builder: (context, state) {
          if (state is MapLoading || state is MapInitial) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Live Map...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            );
          } else if (state is MapError) {
            return Center(child: Text(state.message));
          } else if (state is MapLoaded) {
            final userPos = state.userPosition;

            // Combine markers:
            // 1. Live User Marker (always present, updates in background)
            final allMarkers = <MapMarkerEntity>[];
            if (userPos != null) {
              allMarkers.add(
                MapMarkerEntity(
                  id: 'user_live',
                  lat: userPos.latitude,
                  lng: userPos.longitude,
                  label: 'You are here',
                  type: MarkerType.user,
                ),
              );
            }

            // 2. Active Category POI markers (if user clicked a category chip)
            for (final poi in _categoryPois) {
              allMarkers.add(
                MapMarkerEntity(
                  id: poi.osmId,
                  lat: poi.lat,
                  lng: poi.lng,
                  label: poi.name,
                  type: _resolveMarkerType(poi.type),
                  subType: poi.subType,
                ),
              );
            }

            // 3. Searched Place or Target POI Marker
            final activeTarget = _selectedPlace ?? widget.targetPoi;
            if (activeTarget != null &&
                !allMarkers.any((m) => m.id == activeTarget.osmId)) {
              allMarkers.add(
                MapMarkerEntity(
                  id: activeTarget.osmId,
                  lat: activeTarget.lat,
                  lng: activeTarget.lng,
                  label: activeTarget.name,
                  type: _resolveMarkerType(activeTarget.type),
                  subType: activeTarget.subType,
                ),
              );
            }

            LatLng initialCenter = const LatLng(20.5937, 78.9629);
            if (activeTarget != null &&
                !activeTarget.lat.isNaN && !activeTarget.lat.isInfinite &&
                !activeTarget.lng.isNaN && !activeTarget.lng.isInfinite &&
                activeTarget.lat >= -90.0 && activeTarget.lat <= 90.0 &&
                activeTarget.lng >= -180.0 && activeTarget.lng <= 180.0) {
              initialCenter = LatLng(activeTarget.lat, activeTarget.lng);
            } else if (userPos != null &&
                !userPos.latitude.isNaN && !userPos.latitude.isInfinite &&
                !userPos.longitude.isNaN && !userPos.longitude.isInfinite &&
                userPos.latitude >= -90.0 && userPos.latitude <= 90.0 &&
                userPos.longitude >= -180.0 && userPos.longitude <= 180.0) {
              initialCenter = userPos;
            } else if (!state.currentCenter.latitude.isNaN &&
                !state.currentCenter.latitude.isInfinite &&
                !state.currentCenter.longitude.isNaN &&
                !state.currentCenter.longitude.isInfinite &&
                state.currentCenter.latitude >= -90.0 && state.currentCenter.latitude <= 90.0 &&
                state.currentCenter.longitude >= -180.0 && state.currentCenter.longitude <= 180.0) {
              initialCenter = state.currentCenter;
            }

            return Stack(
              children: [
                // 1. Interactive OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: activeTarget != null ? MapConfig.placeFocusZoom : MapConfig.defaultZoom,
                    maxZoom: MapConfig.maxZoom,
                    minZoom: MapConfig.minZoom,
                    onMapReady: () {
                      if (activeTarget != null &&
                          !activeTarget.lat.isNaN && !activeTarget.lat.isInfinite &&
                          !activeTarget.lng.isNaN && !activeTarget.lng.isInfinite) {
                        _mapController.move(
                          LatLng(activeTarget.lat, activeTarget.lng),
                          MapConfig.placeFocusZoom,
                        );
                      }
                    },
                    // Tap anywhere on the map or buildings to inspect (like Google Maps)
                    onTap: (tapPosition, point) => _onMapTapped(point),
                    // Detect manual user panning and pinching
                    onPositionChanged: (MapCamera camera, bool hasGesture) {
                      if (!camera.center.latitude.isNaN && !camera.center.latitude.isInfinite) {
                        _cameraLat = camera.center.latitude;
                      }
                      if (!camera.center.longitude.isNaN && !camera.center.longitude.isInfinite) {
                        _cameraLng = camera.center.longitude;
                      }

                      if (hasGesture) {
                        // User touched, dragged or zoomed the map manually!
                        // Immediately disable auto-centering so user can freely explore without interruption!
                        if (_isFollowingUser) {
                          setState(() {
                            _isFollowingUser = false;
                          });
                        }
                      }
                    },
                  ),
                  children: [
                    // 1. Dynamic OpenStreetMap Base Tiles (Standard OSM default, switchable to Satellite)
                    TileLayer(
                      urlTemplate: _currentTileUrl,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      maxZoom: MapConfig.maxZoom,
                      maxNativeZoom: MapConfig.maxNativeZoom,
                      minZoom: MapConfig.minZoom,
                    ),

                    // 2. Vector Geofence Polygons (Safe Zones & Danger Zones)
                    PolygonLayer(
                      polygons: [
                        ..._buildDangerZonePolygons(state.activeZones),
                        ..._buildZonePolygons(state.zones),
                      ],
                    ),

                    // 3. Vector Safe Corridors & Route Polylines (Overlay Foundation)
                    PolylineLayer(polylines: _buildRoutePolylines()),

                    // 4. Interactive Map Markers (Live Location + POIs)
                    MarkerLayer(
                      markers: allMarkers.where((m) =>
                        !m.lat.isNaN && !m.lat.isInfinite &&
                        !m.lng.isNaN && !m.lng.isInfinite &&
                        m.lat >= -90.0 && m.lat <= 90.0 &&
                        m.lng >= -180.0 && m.lng <= 180.0
                      ).map((marker) {
                        if (marker.type == MarkerType.user) {
                          // The Google Maps Blue Live Location Marker
                          return Marker(
                            width: 120.0,
                            height: 120.0,
                            point: LatLng(marker.lat, marker.lng),
                            alignment: Alignment.center,
                            rotate: true,
                            child: _AnimatedUserMarker(marker: marker),
                          );
                        } else {
                          // Custom Destination / Searched Place Pin
                          return Marker(
                            width: 140.0,
                            height: 100.0,
                            point: LatLng(marker.lat, marker.lng),
                            alignment: Alignment.center,
                            rotate: true,
                            child: GestureDetector(
                              onTap: () {
                                final found = _categoryPois.firstWhere(
                                  (p) => p.osmId == marker.id,
                                  orElse: () =>
                                      activeTarget ??
                                      PoiEntity(
                                        osmId: marker.id,
                                        name: marker.label,
                                        type: marker.type.name,
                                        lat: marker.lat,
                                        lng: marker.lng,
                                      ),
                                );
                                setState(() {
                                  _selectedPlace = found;
                                  _isFollowingUser = false;
                                });
                              },
                              child: _PoiMarkerWidget(marker: marker),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ],
                ),

                // 2. Top Google Maps-Style Floating Search Bar & Categories
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Search Card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.search_rounded,
                              color: Colors.black54,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) {
                                  _onSearchQueryChanged(
                                    val,
                                    userPos?.latitude,
                                    userPos?.longitude,
                                  );
                                },
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search places, hotels, landmarks...',
                                  hintStyle: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _isSearching = false;
                                  });
                                },
                              ),
                            // SafeTour AI Assistant button in search bar
                            IconButton(
                              tooltip: 'Ask SafeTour AI',
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.smart_toy_outlined,
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChatPage(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),

                      // Quick Category Pills
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _quickCategories[index];
                            final isSelected = _activeCategory == cat['type'];
                            final color = cat['color'] as Color;

                            return ActionChip(
                              avatar: Icon(
                                cat['icon'] as IconData,
                                size: 16,
                                color: isSelected ? Colors.white : color,
                              ),
                              label: Text(
                                cat['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              backgroundColor: isSelected
                                  ? color
                                  : Colors.white,
                              elevation: 2,
                              pressElevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? color
                                      : Colors.grey.shade200,
                                ),
                              ),
                              onPressed: () {
                                _fetchCategoryPois(cat['type'] as String);
                              },
                            );
                          },
                        ),
                      ),

                      // Search Suggestions Dropdown
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              double? dist;
                              if (userPos != null) {
                                dist = Geolocator.distanceBetween(
                                  userPos.latitude,
                                  userPos.longitude,
                                  place.lat,
                                  place.lng,
                                );
                              }

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  place.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  place.address ??
                                      '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: dist != null
                                    ? Text(
                                        dist < 1000
                                            ? '${dist.round()}m'
                                            : '${(dist / 1000).toStringAsFixed(1)}km',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      )
                                    : null,
                                onTap: () => _selectSearchResult(place),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // 3a. Floating Map Layers Switcher (Google Maps Style)
                Positioned(
                  bottom: _selectedPlace != null ? 244 : 92,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'map_layer_switcher_btn',
                    onPressed: _showLayerSwitcherBottomSheet,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                ),

                // 3b. Floating "My Location" Button (Google Maps Style)
                Positioned(
                  bottom: _selectedPlace != null ? 180 : 28,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'google_maps_my_location_btn',
                    onPressed: () => _recenterOnUser(userPos),
                    backgroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      // Vibrant blue when following/centered; slate grey when user has panned away
                      color: _isFollowingUser
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                      size: 24,
                    ),
                  ),
                ),

                // 4. Floating Selected Place Info Card
                if (_selectedPlace != null)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildPlaceInfoCard(_selectedPlace!, userPos),
                  ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPlaceInfoCard(PoiEntity place, LatLng? userPos) {
    String distanceText = '';
    if (userPos != null) {
      final meters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        place.lat,
        place.lng,
      );
      distanceText = meters < 1000
          ? '${meters.round()} m away'
          : '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: place.subTypeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  place.displaySubType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: place.subTypeColor,
                  ),
                ),
              ),
              const Spacer(),
              if (distanceText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    distanceText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPlace = null;
                  });
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (place.address != null && place.address!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              place.address!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!place.lat.isNaN && !place.lat.isInfinite &&
                        !place.lng.isNaN && !place.lng.isInfinite &&
                        place.lat >= -90.0 && place.lat <= 90.0 &&
                        place.lng >= -180.0 && place.lng <= 180.0) {
                      _animatedMapMove(
                        LatLng(place.lat, place.lng),
                        MapConfig.defaultZoom,
                      );
                    }
                  },
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                  label: const Text('Center on Pin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _recenterOnUser(userPos);
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Back to Me'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds vector polygon overlays for safe and danger zones
  List<Polygon> _buildZonePolygons(List<MapZoneEntity> zones) {
    if (zones.isEmpty) return const [];
    final polygons = <Polygon>[];

    for (final zone in zones) {
      if (zone.points.isEmpty) continue;

      final validPoints = zone.points.where((p) =>
        !p.latitude.isNaN && !p.latitude.isInfinite &&
        !p.longitude.isNaN && !p.longitude.isInfinite &&
        p.latitude >= -90.0 && p.latitude <= 90.0 &&
        p.longitude >= -180.0 && p.longitude <= 180.0
      ).toList();

      if (validPoints.length < 3) continue;

      polygons.add(
        Polygon(
          points: validPoints,
          color: zone.fillColor,
          borderColor: zone.strokeColor,
          borderStrokeWidth: zone.strokeWidth,
        ),
      );
    }

    return polygons;
  }

  /// Builds vector polygon overlays for active geofence danger zones
  List<Polygon> _buildDangerZonePolygons(List<DangerZoneEntity> zones) {
    if (zones.isEmpty) return const [];
    final polygons = <Polygon>[];

    for (final zone in zones) {
      if (zone.polygonPoints.isEmpty) continue;

      final validPoints = zone.polygonPoints.where((p) =>
        !p.latitude.isNaN && !p.latitude.isInfinite &&
        !p.longitude.isNaN && !p.longitude.isInfinite &&
        p.latitude >= -90.0 && p.latitude <= 90.0 &&
        p.longitude >= -180.0 && p.longitude <= 180.0
      ).toList();

      // In flutter_map, LatLngBounds.fromPoints requires at least 3 points to form a polygon bounding box
      if (validPoints.length < 3) continue;

      Color fillColor;
      Color borderColor;

      if (zone.isDanger) {
        // Red fill (~30% opacity), red border
        fillColor = const Color(0x4DDC2626);
        borderColor = const Color(0xFFDC2626);
      } else if (zone.isCaution) {
        // Amber/yellow fill (~30% opacity), amber border
        fillColor = const Color(0x4DF59E0B);
        borderColor = const Color(0xFFD97706);
      } else {
        // Green fill (~30% opacity), green border
        fillColor = const Color(0x4D10B981);
        borderColor = const Color(0xFF059669);
      }

      polygons.add(
        Polygon(
          points: validPoints,
          color: fillColor,
          borderColor: borderColor,
          borderStrokeWidth: 2.5,
        ),
      );
    }

    return polygons;
  }

  /// Ray-casting algorithm to determine if a point is inside a polygon
  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygonPoints) {
    if (polygonPoints.length < 3) return false;
    bool inside = false;
    int j = polygonPoints.length - 1;
    for (int i = 0; i < polygonPoints.length; i++) {
      if ((polygonPoints[i].latitude > point.latitude) != (polygonPoints[j].latitude > point.latitude) &&
          (point.longitude <
              (polygonPoints[j].longitude - polygonPoints[i].longitude) *
                      (point.latitude - polygonPoints[i].latitude) /
                      (polygonPoints[j].latitude - polygonPoints[i].latitude) +
                  polygonPoints[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Displays detailed hazard info popup/bottom sheet when a danger zone is tapped
  void _showDangerZoneDetails(DangerZoneEntity zone) {
    Color themeColor;
    IconData icon;
    String badgeText;

    if (zone.isDanger) {
      themeColor = const Color(0xFFDC2626);
      icon = Icons.warning_rounded;
      badgeText = 'HIGH DANGER ZONE';
      HapticFeedback.heavyImpact();
      SharedPreferences.getInstance().then((prefs) {
        final audioEnabled = prefs.getBool('safetour_pref_geofence_audio') ?? true;
        if (audioEnabled) {
          final player = AudioPlayer();
          player.setVolume(1.0).then((_) {
            player.play(AssetSource('audio/siren.wav'));
            Future.delayed(const Duration(milliseconds: 1800), () {
              player.stop();
              player.dispose();
            });
          }).catchError((_) {});
        }
      });
    } else if (zone.isCaution) {
      themeColor = const Color(0xFFD97706);
      icon = Icons.info_outline_rounded;
      badgeText = 'CAUTION ZONE';
    } else {
      themeColor = const Color(0xFF059669);
      icon = Icons.verified_user_rounded;
      badgeText = 'SAFE ZONE';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: themeColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: themeColor),
                          const SizedBox(width: 6),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        zone.displayCategory,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  zone.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (zone.description != null && zone.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: themeColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            zone.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade900,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.radar_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Monitored by SafeTour AI Geofence Engine',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Understood',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Extensible overlay foundation for future safe route / corridor polylines
  List<Polyline> _buildRoutePolylines() {
    return const [];
  }
}

class _PoiMarkerWidget extends StatelessWidget {
  final MapMarkerEntity marker;

  const _PoiMarkerWidget({required this.marker});

  IconData _getIcon() {
    switch (marker.type) {
      case MarkerType.hotel:
        return Icons.hotel_rounded;
      case MarkerType.tourist_spot:
        return Icons.attractions_rounded;
      case MarkerType.restaurant:
        return Icons.restaurant_rounded;
      case MarkerType.hospital:
        return Icons.local_hospital_rounded;
      case MarkerType.police:
        return Icons.local_police_rounded;
      case MarkerType.atm:
        return Icons.atm_rounded;
      case MarkerType.petrol_pump:
        return Icons.local_gas_station_rounded;
      case MarkerType.bus_stop:
        return Icons.directions_bus_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _getColor() {
    switch (marker.type) {
      case MarkerType.hotel:
        return const Color(0xFF4F46E5);
      case MarkerType.tourist_spot:
        return const Color(0xFFEC4899);
      case MarkerType.restaurant:
        return const Color(0xFFF59E0B);
      case MarkerType.hospital:
        return const Color(0xFFEF4444);
      case MarkerType.police:
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            marker.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(_getIcon(), color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class _AnimatedUserMarker extends StatefulWidget {
  final MapMarkerEntity marker;
  const _AnimatedUserMarker({required this.marker});

  @override
  State<_AnimatedUserMarker> createState() => _AnimatedUserMarkerState();
}

class _AnimatedUserMarkerState extends State<_AnimatedUserMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.marker.label,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: 54 * _animation.value,
                    height: 54 * _animation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF2563EB,
                      ).withOpacity(1.0 - _animation.value),
                    ),
                  );
                },
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
