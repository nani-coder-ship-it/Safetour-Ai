import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../../location/presentation/bloc/location_event.dart';

import '../../../map/presentation/pages/map_page.dart';
import '../../../sos/presentation/pages/sos_page.dart';
import '../../../blockchain_id/presentation/pages/digital_id_page.dart';
import '../../../poi/presentation/pages/nearby_page.dart';
import '../../../alerts/presentation/pages/alerts_page.dart';
import '../../../ai_assistant/presentation/pages/chat_page.dart';
import '../../../safety_tips/presentation/pages/safety_tips_page.dart';
import '../../../emergency_contacts/presentation/pages/emergency_contacts_page.dart';

import '../../../profile/presentation/pages/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Ensure location tracking starts when we land on the Home page
    context.read<LocationBloc>().add(StartTracking());
  }

  // The pages for the bottom navigation bar
  List<Widget> get _pages => [
    const _HomeContent(),
    const MapPage(),
    const AlertsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean, light background
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationPermissionDenied) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Location Required'),
                content: Text(state.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
        child: _pages[_currentIndex],
      ),
      floatingActionButton: _currentIndex == 1
          ? null
          : FloatingActionButton(
              tooltip: 'SafeTour AI Assistant',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
              },
              backgroundColor: Colors.blueAccent,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Greeting + Avatar
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                String name = 'Tourist';
                String initials = 'T';
                if (state is Authenticated) {
                  name = state.user.name;
                  if (name.isNotEmpty) {
                    initials = name.substring(0, 1).toUpperCase();
                  }
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Safety Status Banner
            BlocBuilder<LocationBloc, LocationState>(
              builder: (context, state) {
                bool isTracking = state is LocationTracking;
                bool hasAlert = false;
                String alertMessage = "You're in a safe zone";
                
                if (state is LocationTracking) {
                  if (state.alerts.isNotEmpty) {
                    hasAlert = true;
                    alertMessage = state.alerts.first;
                  }
                }

                Color bgColor = hasAlert ? Colors.red.shade50 : Colors.green.shade50;
                Color borderColor = hasAlert ? Colors.red.shade200 : Colors.green.shade200;
                Color textColor = hasAlert ? Colors.red.shade800 : Colors.green.shade800;
                IconData icon = hasAlert ? Icons.warning_rounded : Icons.verified_user;
                Color iconColor = hasAlert ? Colors.red.shade600 : Colors.green.shade600;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alertMessage,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTracking ? (hasAlert ? Colors.red : Colors.green) : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTracking ? 'Active' : 'Off',
                            style: TextStyle(
                              fontSize: 12,
                              color: isTracking ? (hasAlert ? Colors.red.shade800 : Colors.green.shade800) : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // SOS Hero Card
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'SOS EMERGENCY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2x2 Grid for other features
            const Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGridCard(
                  context,
                  title: 'Digital ID',
                  icon: Icons.badge_outlined,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalIdPage()));
                  },
                ),
                _buildGridCard(
                  context,
                  title: 'Nearby',
                  icon: Icons.place_outlined,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyPage()));
                  },
                ),
                _buildGridCard(
                  context,
                  title: 'Guardians',
                  icon: Icons.shield_outlined,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsPage()));
                  },
                ),
                _buildGridCard(
                  context,
                  title: 'Safety Tips',
                  icon: Icons.health_and_safety_outlined,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyTipsPage()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
