import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../injection_container.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../alerts/presentation/bloc/alerts_bloc.dart';
import '../../../alerts/presentation/bloc/alerts_event.dart';
import '../../../alerts/presentation/bloc/alerts_state.dart';

import '../../../map/presentation/pages/map_page.dart';
import '../../../sos/presentation/pages/sos_page.dart';
import '../../../blockchain_id/presentation/pages/digital_id_page.dart';
import '../../../poi/presentation/pages/nearby_page.dart';
import '../../../alerts/presentation/pages/alerts_page.dart';
import '../../../ai_assistant/presentation/pages/chat_page.dart';
import '../../../safety_tips/presentation/pages/safety_tips_page.dart';
import '../../../emergency_contacts/presentation/pages/emergency_contacts_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../widgets/gat_safety_card.dart';

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
    // Ensure location tracking and alerts count start when we land on the Home page
    context.read<LocationBloc>().add(StartTracking());
    context.read<AlertsBloc>().add(const LoadAlerts(silent: true));
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // The pages for the bottom navigation bar
  List<Widget> get _pages => [
    _HomeContent(onTabSelected: _switchTab),
    const MapPage(),
    const AlertsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern clean background matching mockup
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationPermissionDenied) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(
                      state.isServiceDisabled ? Icons.location_off_rounded : Icons.location_disabled_rounded,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 10),
                    const Text('Location Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  state.message,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Dismiss'),
                  ),
                  if (state.isServiceDisabled)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Geolocator.openLocationSettings();
                        if (context.mounted) {
                          context.read<LocationBloc>().add(StartTracking());
                        }
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Turn ON GPS'),
                    )
                  else if (state.isPermanentlyDenied)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Geolocator.openAppSettings();
                        if (context.mounted) {
                          context.read<LocationBloc>().add(StartTracking());
                        }
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Open Settings'),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<LocationBloc>().add(StartTracking());
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Allow Location'),
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
              backgroundColor: primaryBlue,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, state) {
                  if (state is AlertsLoaded && state.unreadCount > 0) {
                    return Badge.count(
                      count: state.unreadCount,
                      backgroundColor: const Color(0xFFDC2626),
                      textColor: Colors.white,
                      child: const Icon(Icons.notifications_none_rounded),
                    );
                  }
                  return const Icon(Icons.notifications_none_rounded);
                },
              ),
              activeIcon: BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, state) {
                  if (state is AlertsLoaded && state.unreadCount > 0) {
                    return Badge.count(
                      count: state.unreadCount,
                      backgroundColor: const Color(0xFFDC2626),
                      textColor: Colors.white,
                      child: const Icon(Icons.notifications_rounded),
                    );
                  }
                  return const Icon(Icons.notifications_rounded);
                },
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final void Function(int index)? onTabSelected;

  const _HomeContent({this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header: SafeTour Logo Badge + Hello, User + Bell & Profile Avatar
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                String name = 'Vignesh';
                String initials = 'V';
                if (state is Authenticated) {
                  name = state.user.name;
                  if (name.isNotEmpty) {
                    initials = name.substring(0, 1).toUpperCase();
                  }
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Shield Badge + Brand & Greeting
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SafeTour AI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textDark,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Hello, $name 👋',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Stay safe, keep exploring!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
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
                    const SizedBox(width: 8),

                    // Right: Notification Bell Badge + Profile Avatar Circle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bell with unread count badge
                        IconButton(
                          tooltip: 'Alerts',
                          onPressed: () => onTabSelected?.call(2),
                          icon: BlocBuilder<AlertsBloc, AlertsState>(
                            builder: (context, alertState) {
                              final count = (alertState is AlertsLoaded) ? alertState.unreadCount : 3;
                              return Badge(
                                isLabelVisible: count > 0,
                                label: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: textDark,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Avatar
                        GestureDetector(
                          onTap: () => onTabSelected?.call(3),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // 2. Safe Zone Banner Matching Reference (Syncs with LocationBloc & AlertsBloc)
            BlocBuilder<LocationBloc, LocationState>(
              builder: (context, locationState) {
                return BlocBuilder<AlertsBloc, AlertsState>(
                  builder: (context, alertState) {
                    bool isTracking = locationState is LocationTracking;
                    bool hasDanger = false;
                    String alertMessage = "You're in a safe zone";
                    String subMessage = "Current location is safe";

                    // 1. Direct physical geofence breach detected by GPS tracking
                    if (locationState is LocationTracking && locationState.alerts.isNotEmpty) {
                      hasDanger = true;
                      alertMessage = locationState.alerts.first;
                      subMessage = "Danger zone alert active";
                    }
                    // 2. Critical geofence danger or emergency alert (ignore benign weather updates/advisories)
                    else if (alertState is AlertsLoaded &&
                        alertState.alerts.any((a) =>
                            (a.type == 'geofence' || a.severity == 'critical' || a.type == 'sos') &&
                            a.status == 'active')) {
                      final topDanger = alertState.alerts.firstWhere((a) =>
                          (a.type == 'geofence' || a.severity == 'critical' || a.type == 'sos') &&
                          a.status == 'active');
                      hasDanger = true;
                      alertMessage = topDanger.title;
                      subMessage = (topDanger.locationName != null && topDanger.locationName!.isNotEmpty)
                          ? "Zone: ${topDanger.locationName}"
                          : "Alert in nearby vicinity";
                    }

                    final Color bgColor = hasDanger ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
                    final Color borderColor = hasDanger ? const Color(0xFFFECACA) : const Color(0xFFDCFCE7);
                    final Color titleColor = hasDanger ? const Color(0xFF991B1B) : const Color(0xFF14532D);
                    final Color subtitleColor = hasDanger ? const Color(0xFFDC2626) : const Color(0xFF15803D);
                    final IconData statusIcon = hasDanger ? Icons.warning_rounded : Icons.check_circle_rounded;
                    final Color iconColor = hasDanger ? const Color(0xFFEF4444) : const Color(0xFF16A34A);

                    return GestureDetector(
                      onTap: () => onTabSelected?.call(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: iconColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alertMessage,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    subMessage,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Pill badge: Active + Chevron
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (hasDanger ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isTracking ? (hasDanger ? Colors.red : const Color(0xFF16A34A)) : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTracking ? (hasDanger ? 'DANGER' : 'Active') : 'Off',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasDanger ? const Color(0xFF991B1B) : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, color: iconColor, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            // 3. AI Road Safety GATv2 Card (with circular score gauge)
            const GatSafetyCard(),
            const SizedBox(height: 14),

            // 4. SOS EMERGENCY Button Card
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage()));
              },
              onLongPress: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage(autoTrigger: true)));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Frosted icon container
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOS EMERGENCY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Get help when you need it',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 5. Quick Access Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All quick safety features active on SafeTour AI.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. 3x2 GridView for Quick Access Cards (Matching Reference Exactly)
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.85,
              children: [
                // 1. Digital ID
                _buildQuickCard(
                  title: 'Digital ID',
                  subtitle: 'Your travel ID',
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalIdPage()));
                  },
                ),

                // 2. Nearby Places
                _buildQuickCard(
                  title: 'Nearby',
                  subtitle: 'Explore safely',
                  icon: Icons.place_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  onTap: () async {
                    Position? cachedPos;
                    try {
                      cachedPos = await sl<DeviceLocationService>().getLastKnownPosition();
                    } catch (_) {}

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NearbyPage(
                            userLat: cachedPos?.latitude,
                            userLng: cachedPos?.longitude,
                          ),
                        ),
                      );
                    }
                  },
                ),

                // 3. Safety Map
                _buildQuickCard(
                  title: 'Safety Map',
                  subtitle: 'View risk zones',
                  icon: Icons.map_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  bgColor: const Color(0xFFECFEFF),
                  onTap: () => onTabSelected?.call(1),
                ),

                // 4. Emergency Contacts
                _buildQuickCard(
                  title: 'Emergency',
                  subtitle: 'Call for help',
                  icon: Icons.phone_in_talk_outlined,
                  iconColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsPage()));
                  },
                ),

                // 5. Tourist Info
                _buildQuickCard(
                  title: 'Tourist Info',
                  subtitle: 'Safety guide',
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyTipsPage()));
                  },
                ),

                // 6. Incident Report
                _buildQuickCard(
                  title: 'Incident',
                  subtitle: 'Report issues',
                  icon: Icons.assignment_late_outlined,
                  iconColor: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFF1F2),
                  onTap: () {
                    _showIncidentReportModal(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 70), // Safe padding for bottom bar & FAB
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showIncidentReportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.assignment_late_outlined, color: Color(0xFFE11D48), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Incident Reporting',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Report road hazards, harassment, or unsafe tourist zones directly to emergency dispatch & AI surveillance.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.red),
                ),
                title: const Text('Contact Emergency Guardians', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Call 112 or notify trusted contacts', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsPage()));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Describe Incident to AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Get instant safety instructions and report lodging', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
