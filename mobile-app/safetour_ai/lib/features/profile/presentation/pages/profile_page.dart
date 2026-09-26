import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../emergency_contacts/presentation/pages/emergency_contacts_page.dart';
import '../../../safety_tips/presentation/pages/safety_tips_page.dart';
import '../../../ai_assistant/presentation/pages/chat_page.dart';
import '../../../auth/presentation/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Safety Preferences Toggle State
  bool _geofenceAlertsEnabled = true;
  bool _liveLocationSharing = true;
  bool _shakeToSos = true;
  bool _voiceMonitoring = false;

  // Medical & Emergency Contact Local State
  String _bloodGroup = 'O+';
  String _emergencyContactName = 'Family Guardian';
  String _emergencyContactPhone = '+91 98765 43210';
  String _allergies = 'None / Healthy';

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _displayName {
    final user = _currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    final email = user?.email ?? '';
    if (email.contains('@')) {
      final prefix = email.split('@')[0];
      return prefix[0].toUpperCase() + prefix.substring(1);
    }
    return 'SafeTour Traveler';
  }

  String get _email => _currentUser?.email ?? 'traveler@safetour.ai';

  String get _travelerId {
    final uid = _currentUser?.uid ?? 'USER12345';
    final short = uid.length >= 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();
    return 'ST-AI#$short';
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final bloodController = TextEditingController(text: _bloodGroup);
    final contactNameController = TextEditingController(text: _emergencyContactName);
    final contactPhoneController = TextEditingController(text: _emergencyContactPhone);
    final allergiesController = TextEditingController(text: _allergies);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Traveler Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Emergency medical data is accessible to certified responders.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: bloodController,
                      decoration: InputDecoration(
                        labelText: 'Blood Group',
                        prefixIcon: const Icon(Icons.bloodtype_outlined, color: Colors.redAccent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: allergiesController,
                      decoration: InputDecoration(
                        labelText: 'Allergies / Conditions',
                        prefixIcon: const Icon(Icons.medical_services_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contactNameController,
                decoration: InputDecoration(
                  labelText: 'Primary Emergency Contact Name',
                  prefixIcon: const Icon(Icons.shield_outlined, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact Phone',
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && _currentUser != null) {
                      try {
                        await _currentUser!.updateDisplayName(newName);
                      } catch (_) {}
                    }
                    setState(() {
                      _bloodGroup = bloodController.text.trim();
                      _emergencyContactName = contactNameController.text.trim();
                      _emergencyContactPhone = contactPhoneController.text.trim();
                      _allergies = allergiesController.text.trim();
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Profile Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrPassModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Digital Tourist Pass',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 100, color: Color(0xFF1E3A8A)),
                  const SizedBox(height: 8),
                  Text(
                    _travelerId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Government Verified SafeTour Traveler',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Show this QR code at verified checkpoints, tourist transit hubs, and authorized emergency response units.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from SafeTour AI? Live geofencing background protection will pause.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutRequested());
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Traveler Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Digital Tourist Pass',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
            onPressed: _showQrPassModal,
          ),
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_outlined, color: Colors.black87),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Traveler Header Card
            _buildTravelerHeaderCard(),

            const SizedBox(height: 18),

            // 2. Holographic Digital Tourist Pass
            _buildTouristPassCard(),

            const SizedBox(height: 20),

            // 3. Travel & Safety Statistics
            _buildSafetyStatsGrid(),

            const SizedBox(height: 20),

            // 4. Emergency & Medical Responder Card
            _buildMedicalEmergencyCard(),

            const SizedBox(height: 20),

            // 5. Safety & Geofencing Settings
            _buildSafetySettingsSection(),

            const SizedBox(height: 20),

            // 6. Connected Safety Hub (Guardians, Tips, AI)
            _buildConnectedServicesSection(),

            const SizedBox(height: 24),

            // 7. Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                label: const Text(
                  'Sign Out from SafeTour AI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 14),
            Center(
              child: Text(
                'SafeTour AI • Version 1.0.1 • Tourist Protection System',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelerHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Monogram / Avatar with Gradient Ring
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'T',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name, Email, and Verified Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 19),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Safe Traveler',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouristPassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: SafeTour Pass Title & View QR Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SafeTour Pass',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showQrPassModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'View QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _travelerId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cryptographically Signed Tourist Safe ID',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // Security Telemetry Bar - Guaranteed responsive with 0 overlap
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'STATUS',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              '100% Protected',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
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
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GEOFENCE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Radar Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF4ADE80), size: 10),
                      SizedBox(width: 3),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            title: 'Safety Score',
            value: '98%',
            icon: Icons.health_and_safety_rounded,
            color: const Color(0xFF16A34A),
            subtitle: 'Optimal Zone',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Safe Zones',
            value: '14 Visited',
            icon: Icons.verified_outlined,
            color: const Color(0xFF2563EB),
            subtitle: 'Zero Incidents',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Emergency',
            value: 'Synced',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFD97706),
            subtitle: '112 / Guardians',
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalEmergencyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_information_rounded, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Emergency & Medical Card',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              InkWell(
                onTap: _showEditProfileDialog,
                child: Text(
                  'Edit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMedicalItem('Blood Group', _bloodGroup, Icons.bloodtype_rounded, Colors.redAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildMedicalItem('Allergies', _allergies, Icons.coronavirus_outlined, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.teal, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _emergencyContactName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _emergencyContactPhone,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Guardian',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetySettingsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety & Alert Controls',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          _buildSettingSwitch(
            title: 'Danger Geofence Audio Alerts',
            subtitle: 'Immediate voice & haptic alert upon approaching red danger zones',
            icon: Icons.notification_important_rounded,
            color: Colors.redAccent,
            value: _geofenceAlertsEnabled,
            onChanged: (val) => setState(() => _geofenceAlertsEnabled = val),
          ),
          const Divider(height: 1),
          _buildSettingSwitch(
            title: 'Live Guardian Location Broadcast',
            subtitle: 'Sync real-time encrypted GPS safety breadcrumbs to trusted contacts',
            icon: Icons.satellite_alt_rounded,
            color: Colors.blueAccent,
            value: _liveLocationSharing,
            onChanged: (val) => setState(() => _liveLocationSharing = val),
          ),
          const Divider(height: 1),
          _buildSettingSwitch(
            title: 'Rapid Shake-to-SOS',
            subtitle: 'Shake device 3 times rapidly to trigger silent distress broadcast',
            icon: Icons.vibration_rounded,
            color: Colors.orange,
            value: _shakeToSos,
            onChanged: (val) => setState(() => _shakeToSos = val),
          ),
          const Divider(height: 1),
          _buildSettingSwitch(
            title: 'AI Audio Threat Detection',
            subtitle: 'Continuous acoustic monitoring for sudden screams or distress calls',
            icon: Icons.mic_none_rounded,
            color: Colors.purple,
            value: _voiceMonitoring,
            onChanged: (val) => setState(() => _voiceMonitoring = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedServicesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety Services & Support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          _buildNavTile(
            title: 'Trusted Guardians & Helplines',
            subtitle: 'Family members & emergency national lines (112, 1363)',
            icon: Icons.shield_rounded,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsPage())),
          ),
          const Divider(height: 1),
          _buildNavTile(
            title: 'Local Safety Tips & Do\'s / Don\'ts',
            subtitle: 'Cultural guidelines, tourist safety advice, local scams',
            icon: Icons.lightbulb_outline_rounded,
            color: Colors.amber.shade800,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyTipsPage())),
          ),
          const Divider(height: 1),
          _buildNavTile(
            title: 'Ask SafeTour AI Copilot',
            subtitle: '24/7 AI multi-lingual tourist assistance & itinerary safety',
            icon: Icons.smart_toy_outlined,
            color: const Color(0xFF2563EB),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
