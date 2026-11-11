import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/network/dio_client.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_user.dart';
import 'features/auth/domain/usecases/register_user.dart';
import 'features/auth/domain/usecases/get_emergency_contacts.dart';
import 'features/auth/domain/usecases/update_emergency_contacts.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/emergency_contacts/presentation/bloc/emergency_contacts_bloc.dart';

import 'features/location/domain/repositories/location_repository.dart';
import 'features/location/domain/usecases/send_location.dart';
import 'features/location/domain/usecases/get_latest_location.dart';
import 'features/location/data/datasources/location_remote_datasource.dart';
import 'features/location/data/repositories/location_repository_impl.dart';
import 'features/location/data/services/device_location_service.dart';
import 'features/location/presentation/bloc/location_bloc.dart';

import 'features/map/presentation/bloc/map_bloc.dart';

import 'features/geofence/domain/repositories/geofence_repository.dart';
import 'features/geofence/domain/usecases/get_active_zones.dart';
import 'features/geofence/data/datasources/geofence_remote_datasource.dart';
import 'features/geofence/data/repositories/geofence_repository_impl.dart';

import 'features/ai_assistant/domain/repositories/chat_repository.dart';
import 'features/ai_assistant/domain/usecases/send_chat_message.dart';
import 'features/ai_assistant/data/datasources/chat_remote_datasource.dart';
import 'features/ai_assistant/data/repositories/chat_repository_impl.dart';
import 'features/ai_assistant/presentation/bloc/chat_bloc.dart';

import 'features/poi/domain/repositories/poi_repository.dart';
import 'features/poi/domain/usecases/get_nearby_pois.dart';
import 'features/poi/domain/usecases/search_places.dart';
import 'features/poi/data/datasources/poi_remote_datasource.dart';
import 'features/poi/data/repositories/poi_repository_impl.dart';
import 'features/poi/presentation/bloc/poi_bloc.dart';

import 'features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'features/alerts/presentation/bloc/alerts_bloc.dart';

import 'features/blockchain_id/data/datasources/digital_id_remote_datasource.dart';
import 'features/blockchain_id/presentation/bloc/digital_id_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ==========================================
  // Core
  // ==========================================
  sl.registerLazySingleton(() => DioClient());

  // ==========================================
  // Features - Auth
  // ==========================================
  // Bloc
  sl.registerFactory(() => AuthBloc(
        loginUser: sl(),
        registerUser: sl(),
      ));

  // Use cases
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => RegisterUser(sl()));

  // Auth Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // --- Location Feature ---
  // Location Bloc
  sl.registerFactory(
    () => LocationBloc(
      locationService: sl(),
      sendLocation: sl(),
    ),
  );

  // Location Use Cases
  sl.registerLazySingleton(() => SendLocation(sl()));
  sl.registerLazySingleton(() => GetLatestLocation(sl()));

  // Location Repository
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(remoteDataSource: sl()),
  );

  // Location Data Sources & Services
  sl.registerLazySingleton<LocationRemoteDataSource>(
    () => LocationRemoteDataSourceImpl(dioClient: sl()),
  );
  sl.registerLazySingleton(() => DeviceLocationService());

  // --- Map Feature ---
  sl.registerFactory(
    () => MapBloc(
      locationService: sl(),
      getActiveZones: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: sl(),
      dioClient: sl(),
    ),
  );

  // ==========================================
  // Features - Map
  // ==========================================

  // ==========================================
  // Features - Geofence
  // ==========================================
  // Use cases
  sl.registerLazySingleton(() => GetActiveZones(sl()));

  // Repository
  sl.registerLazySingleton<GeofenceRepository>(
    () => GeofenceRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<GeofenceRemoteDataSource>(
    () => GeofenceRemoteDataSourceImpl(dioClient: sl()),
  );

  // ==========================================
  // Features - Route
  // ==========================================

  // ==========================================
  // Features - SOS & Emergency Contacts
  // ==========================================
  sl.registerFactory(() => EmergencyContactsBloc(
        getEmergencyContacts: sl(),
        updateEmergencyContacts: sl(),
      ));
  sl.registerLazySingleton(() => GetEmergencyContacts(sl()));
  sl.registerLazySingleton(() => UpdateEmergencyContacts(sl()));

  // ==========================================
  // Features - Blockchain ID
  // ==========================================
  sl.registerFactory(() => DigitalIdBloc(remoteDataSource: sl()));
  sl.registerLazySingleton<DigitalIdRemoteDataSource>(
    () => DigitalIdRemoteDataSourceImpl(dioClient: sl()),
  );

  // ==========================================
  // Features - AI Assistant
  // ==========================================
  sl.registerFactory(() => ChatBloc(sendChatMessage: sl()));
  sl.registerLazySingleton(() => SendChatMessage(sl()));
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(dioClient: sl()),
  );

  // ==========================================
  // Features - POI (Nearby)
  // ==========================================
  sl.registerFactory(() => PoiBloc(
        getNearbyPOIs: sl(),
        locationService: sl(),
      ));
  sl.registerLazySingleton(() => GetNearbyPOIs(sl()));
  sl.registerLazySingleton(() => SearchPlaces(sl()));
  sl.registerLazySingleton<PoiRepository>(
    () => PoiRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<PoiRemoteDataSource>(
    () => PoiRemoteDataSourceImpl(dioClient: sl()),
  );

  // ==========================================
  // Features - Alerts
  // ==========================================
  sl.registerFactory(() => AlertsBloc(remoteDataSource: sl()));
  sl.registerLazySingleton<AlertsRemoteDataSource>(
    () => AlertsRemoteDataSourceImpl(dioClient: sl()),
  );

  // ==========================================
  // External
  // ==========================================
  sl.registerLazySingleton(() => FirebaseAuth.instance);
}
