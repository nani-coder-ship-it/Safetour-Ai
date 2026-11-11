import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/map/presentation/bloc/map_bloc.dart';
import 'features/alerts/presentation/bloc/alerts_bloc.dart';
import 'features/alerts/presentation/bloc/alerts_event.dart';
import 'features/emergency_contacts/presentation/bloc/emergency_contacts_bloc.dart';
import 'features/emergency_contacts/presentation/bloc/emergency_contacts_event.dart';

import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[FLUTTER ERROR]: ${details.exception}');
      debugPrint('${details.stack}');
    };

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('[Firebase Init Error]: $e');
    }

    try {
      await di.init();
    } catch (e) {
      debugPrint('[DI Init Error]: $e');
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('[ROOT UNCAUGHT ERROR]: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatus()),
        ),
        BlocProvider<LocationBloc>(
          create: (_) => di.sl<LocationBloc>(),
        ),
        BlocProvider<MapBloc>(
          create: (_) => di.sl<MapBloc>(),
        ),
        BlocProvider<AlertsBloc>(
          create: (_) => di.sl<AlertsBloc>()..add(const LoadAlerts()),
        ),
        BlocProvider<EmergencyContactsBloc>(
          create: (_) => di.sl<EmergencyContactsBloc>()..add(LoadEmergencyContacts()),
        ),
      ],
      child: MaterialApp(
        title: 'SafeTour AI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomePage();
        } else if (state is AuthInitial) {
          // Instant synchronous check if already signed in via Firebase
          if (FirebaseAuth.instance.currentUser != null) {
            return const HomePage();
          }
          return const LoginPage();
        } else if (state is AuthLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B4682),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
