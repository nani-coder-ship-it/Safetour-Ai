import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/poi_model.dart';

abstract class PoiRemoteDataSource {
  Future<List<PoiModel>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  });

  Future<List<PoiModel>> searchPlaces(String query, {double? lat, double? lng});
}

class PoiRemoteDataSourceImpl implements PoiRemoteDataSource {
  final DioClient dioClient;

  PoiRemoteDataSourceImpl({required this.dioClient});

  static const String _mapTilerApiKey = 'iE5TZXMQVMOCYyR6DVEu';

  static const Map<String, List<String>> _categoryKeywords = {
    'hotel': ['hotel', 'lodge', 'guest house', 'motel', 'resort'],
    'tourist_spot': ['temple', 'kovil', 'monument', 'attraction', 'park', 'waterfall', 'viewpoint'],
    'restaurant': ['restaurant', 'canteen', 'hotel', 'mess', 'bakery', 'cafe', 'fast food', 'biryani'],
    'hospital': ['hospital', 'clinic'],
    'pharmacy': ['pharmacy', 'chemist'],
    'police': ['police station', 'police'],
    'atm': ['atm', 'bank'],
    'bank': ['bank'],
    'petrol_pump': ['petrol pump', 'gas station'],
    'bus_stop': ['bus stop', 'bus station'],
    'railway_station': ['railway station'],
    'shopping': ['shopping mall', 'retail'],
    'supermarket': ['supermarket', 'grocery'],
    'college': ['college', 'university'],
    'toilet': ['public toilet', 'restroom'],
  };

  bool _isStudentHostel(String name) {
    final n = name.toLowerCase();
    return n.contains('mens hostel') ||
        n.contains("men's hostel") ||
        n.contains('womens hostel') ||
        n.contains("women's hostel") ||
        n.contains('ladies hostel') ||
        n.contains('gents hostel') ||
        n.contains('boys hostel') ||
        n.contains('girls hostel') ||
        n.contains('student hostel') ||
        n.contains('college hostel') ||
        n.contains('university hostel') ||
        n.contains('campus hostel') ||
        n.contains('hall of residence') ||
        n.contains('pg for gents') ||
        n.contains('pg for ladies') ||
        n.contains('pg for boys') ||
        n.contains('pg for girls');
  }

  @override
  Future<List<PoiModel>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'type': type,
        'lat': lat,
        'lng': lng,
        'radius': radiusMeters,
      };

      if (subType != null && subType.isNotEmpty && subType != 'all') {
        queryParams['subType'] = subType;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dioClient.dio.get(
        '/poi/nearby',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((item) => PoiModel.fromJson(item as Map<String, dynamic>, userLat: lat, userLng: lng))
            .toList();
      }
      // If server returned non-200 or unexpected structure, attempt direct client-side fallback
      return await _fetchDirectFallback(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        type: type,
        subType: subType,
        search: search,
      );
    } catch (_) {
      // Local backend unreachable (e.g. phone on mobile data without USB port forwarding)
      // Fallback directly to client-side provider so user always gets live places
      return await _fetchDirectFallback(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        type: type,
        subType: subType,
        search: search,
      );
    }
  }

  Future<List<PoiModel>> _fetchDirectFallback({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  }) async {
    final directDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );

    final queries = search?.trim().isNotEmpty == true
        ? [search!.trim()]
        : (_categoryKeywords[type] ?? [type]);

    final List<PoiModel> pois = [];
    final Set<String> seenIds = {};

    // 1. Try MapTiler Cloud with proximity biasing (fast, authoritative, works directly from device)
    try {
      final topQuery = queries.first;
      final url =
          'https://api.maptiler.com/geocoding/${Uri.encodeComponent(topQuery)}.json?key=$_mapTilerApiKey&proximity=$lng,$lat&limit=15';
      final res = await directDio.get(url);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final features = (res.data['features'] as List<dynamic>?) ?? [];
        for (final feat in features) {
          final coords = feat['geometry']?['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;
          final fLng = (coords[0] as num).toDouble();
          final fLat = (coords[1] as num).toDouble();
          final name = (feat['text'] ?? feat['place_name']?.toString().split(',')[0])?.toString().trim();
          if (name == null || name.isEmpty) continue;
          if (_isStudentHostel(name)) continue;

          final dist = Geolocator.distanceBetween(lat, lng, fLat, fLng);
          if (dist > (radiusMeters < 5000 ? 10000 : radiusMeters * 2)) continue;
          final id = feat['id']?.toString() ?? 'maptiler_${fLat}_$fLng';
          if (seenIds.contains(id)) continue;
          seenIds.add(id);

          pois.add(PoiModel(
            osmId: id,
            name: name,
            type: type,
            subType: subType ?? type,
            address: feat['place_name']?.toString() ?? 'Address unavailable',
            lat: fLat,
            lng: fLng,
            distanceMeters: dist,
          ));
        }
      }
    } catch (_) {}

    // 2. Query OpenStreetMap Nominatim across top category keywords in parallel
    if (pois.length < 5) {
      try {
        final searchRadius = radiusMeters < 5000 ? 8000.0 : radiusMeters.toDouble() * 1.5;
        final delta = searchRadius / 111000.0;
        final viewbox = '${lng - delta},${lat + delta},${lng + delta},${lat - delta}';
        final targetQueries = search?.trim().isNotEmpty == true
            ? [search!.trim()]
            : queries.take(4).toList();

        final futures = targetQueries.map((nomQuery) async {
          try {
            final url =
                'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(nomQuery)}&viewbox=$viewbox&bounded=1&limit=15&addressdetails=1';
            final res = await directDio.get(
              url,
              options: Options(headers: {
                'User-Agent': 'SafeTourAI-Mobile/1.2 (https://safetour.ai; contact@safetour.ai)',
                'Accept-Language': 'en',
              }),
            );
            if (res.statusCode == 200 && res.data is List) {
              for (final item in (res.data as List)) {
                final iLat = double.tryParse(item['lat']?.toString() ?? '');
                final iLng = double.tryParse(item['lon']?.toString() ?? '');
                if (iLat == null || iLng == null) continue;
                final name = (item['name'] ?? item['display_name']?.toString().split(',')[0])?.toString().trim();
                if (name == null || name.isEmpty) continue;
                if (_isStudentHostel(name)) continue;

                // When category is hotel, NEVER accept canteens, restaurants, or generic buildings
                if (type == 'hotel') {
                  final lowerName = name.toLowerCase();
                  final itemClass = (item['class'] ?? '').toString().toLowerCase();
                  final itemType = (item['type'] ?? '').toString().toLowerCase();
                  if (itemClass == 'amenity' ||
                      itemClass == 'building' ||
                      itemType == 'canteen' ||
                      itemType == 'restaurant' ||
                      itemType == 'fast_food' ||
                      lowerName.contains('canteen') ||
                      lowerName.contains('mess') ||
                      lowerName.contains('biriyani')) {
                    continue;
                  }
                }

                // Resolve human-friendly subType
                String resolvedSubType = type;
                if (type == 'hotel') {
                  final it = item['type']?.toString().toLowerCase() ?? '';
                  if (['lodge', 'guest_house', 'motel', 'resort', 'hostel'].contains(it)) {
                    resolvedSubType = it;
                  } else {
                    resolvedSubType = 'hotel';
                  }
                } else if (item['type'] != null && item['type'] != 'yes' && item['type'] != 'building') {
                  resolvedSubType = item['type'].toString();
                }

                final dist = Geolocator.distanceBetween(lat, lng, iLat, iLng);
                final id = '${item['osm_type']}/${item['osm_id']}';
                if (seenIds.contains(id)) continue;
                seenIds.add(id);

                pois.add(PoiModel(
                  osmId: id,
                  name: name,
                  type: type,
                  subType: resolvedSubType,
                  address: item['display_name']?.toString() ?? 'Address unavailable',
                  lat: iLat,
                  lng: iLng,
                  distanceMeters: dist,
                ));
              }
            }
          } catch (_) {}
        });

        await Future.wait(futures);
      } catch (_) {}
    }

    if (pois.isNotEmpty) {
      pois.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      return pois;
    }

    throw NetworkException('Unable to load nearby places. Please check your internet connection.');
  }

  @override
  Future<List<PoiModel>> searchPlaces(String query, {double? lat, double? lng}) async {
    try {
      final queryParams = <String, dynamic>{
        'q': query.trim(),
      };
      if (lat != null && lng != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
      }

      final response = await dioClient.dio.get(
        '/poi/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((item) => PoiModel.fromJson(item as Map<String, dynamic>, userLat: lat, userLng: lng))
            .toList();
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }
}
