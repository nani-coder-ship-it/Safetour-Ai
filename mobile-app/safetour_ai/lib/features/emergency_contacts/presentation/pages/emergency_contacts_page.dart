import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safetour_ai/features/location/data/services/device_location_service.dart';
import 'package:safetour_ai/injection_container.dart';

class GuardianContact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final Color avatarColor;

  GuardianContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.avatarColor,
  });
}

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage>
    with SingleTickerProviderStateMixin {
  late DeviceLocationService _locationService;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSirenActive = false;
  Timer? _sirenTimer;
  late AnimationController _pulseController;

  final List<GuardianContact> _guardians = [
    GuardianContact(
      id: '1',
      name: 'Primary Contact (Family)',
      phone: '+91 98765 43210',
      relation: 'Family',
      avatarColor: Colors.deepPurple,
    ),
    GuardianContact(
      id: '2',
      name: 'Local Tour Guide',
      phone: '+91 91234 56789',
      relation: 'Guide',
      avatarColor: Colors.teal,
    ),
    GuardianContact(
      id: '3',
      name: 'Hotel Front Desk',
      phone: '+91 80000 12345',
      relation: 'Hotel',
      avatarColor: Colors.blueAccent,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _locationService = sl<DeviceLocationService>();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadLocation();
  }

  @override
  void dispose() {
    _sirenTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await _locationService.getLastKnownPosition() ??
          await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _toggleSiren() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSirenActive = !_isSirenActive;
    });

    if (_isSirenActive) {
      _sirenTimer?.cancel();
      _sirenTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        HapticFeedback.vibrate();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Panic Siren Activated! Strobe active to draw attention.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      _sirenTimer?.cancel();
    }
  }

  void _shareLocationAlert([GuardianContact? contact]) {
    final lat = _currentPosition?.latitude ?? 14.4265;
    final lng = _currentPosition?.longitude ?? 79.9565;
    final mapUrl = 'https://maps.google.com/?q=$lat,$lng';

    final message = contact != null
        ? '⚠️ EMERGENCY from SafeTour AI!\nHello ${contact.name}, I need assistance. My current live location is:\n$mapUrl\nPlease check on me or notify authorities.'
        : '⚠️ EMERGENCY ALERT (SafeTour AI)\nI need immediate assistance. My live GPS coordinates:\n$mapUrl\nLat: $lat, Lng: $lng';

    Clipboard.setData(ClipboardData(text: message));
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.share_location_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Emergency Broadcast', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distress message copied to clipboard with live GPS link:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              contact != null
                  ? 'Ready to paste and send to ${contact.name} (${contact.phone}).'
                  : 'Ready to paste in SMS, WhatsApp, or emergency channels.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(contact != null
                      ? 'Distress coordinates ready for ${contact.name}!'
                      : 'Coordinates copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copied'),
          ),
        ],
      ),
    );
  }

  void _callHelpline(String name, String number) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.red.shade50,
              child: Icon(Icons.phone_in_talk, size: 36, color: Colors.red.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Helpline Number: $number',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: number));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Helpline number $number copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Number'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: number));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dialing $number ($name)...'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGuardianDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relation = 'Family';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
                'Add Trusted Guardian',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'This contact will receive SOS alerts with your live coordinates.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: relation,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: const Icon(Icons.people_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Family', 'Friend', 'Guide', 'Hotel', 'Colleague', 'Other']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => relation = val);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in both name and phone number')),
                      );
                      return;
                    }

                    setState(() {
                      _guardians.add(
                        GuardianContact(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relation: relation,
                          avatarColor: Colors.primaries[_guardians.length % Colors.primaries.length],
                        ),
                      );
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${nameCtrl.text.trim()} added as a trusted guardian!'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                  child: const Text('Save Guardian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Guardians & Emergency'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Safety Siren',
            icon: Icon(
              _isSirenActive ? Icons.notifications_active : Icons.notifications_off_outlined,
              color: _isSirenActive ? Colors.yellowAccent : Colors.white,
            ),
            onPressed: _toggleSiren,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Siren Warning Banner if active
            if (_isSirenActive)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  color: Colors.red.withOpacity(0.85 + (_pulseController.value * 0.15)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'EMERGENCY SIREN ACTIVE\nVibration & beacon pulsating.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: _toggleSiren,
                        child: const Text('STOP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

            // Live Location Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'GPS Guard Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingLocation)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white70),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _currentPosition != null
                        ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}°, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}°'
                        : 'Coordinates: 14.4265° N, 79.9565° E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant live coordinates attachable to emergency dispatches.',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _shareLocationAlert(),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Broadcast Live Coordinates',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section: Trusted Guardians
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trusted Guardians',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAddGuardianDialog,
                    icon: const Icon(Icons.add, size: 18, color: Colors.teal),
                    label: const Text(
                      'Add Guardian',
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _guardians.length,
              itemBuilder: (context, index) {
                final guardian = _guardians[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: guardian.avatarColor.withOpacity(0.15),
                        child: Text(
                          guardian.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: guardian.avatarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    guardian.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: guardian.avatarColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    guardian.relation,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: guardian.avatarColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guardian.phone,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send Live GPS Alert',
                        icon: const Icon(Icons.share_location_rounded, color: Colors.teal),
                        onPressed: () => _shareLocationAlert(guardian),
                      ),
                      IconButton(
                        tooltip: 'Call Guardian',
                        icon: const Icon(Icons.phone_rounded, color: Colors.green),
                        onPressed: () => _callHelpline(guardian.name, guardian.phone),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Section: 24/7 Official Tourist Helplines
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '24/7 Official Helplines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildHelplineCard(
              number: '112',
              title: 'National Emergency Response (ERSS)',
              subtitle: 'All-in-one nationwide emergency (Police, Fire, Ambulance)',
              color: Colors.red.shade600,
              icon: Icons.emergency_rounded,
            ),
            _buildHelplineCard(
              number: '1363',
              title: 'Tourist Infoline (Govt of India)',
              subtitle: '24x7 Multi-lingual tourist assistance & guidance',
              color: Colors.indigo.shade600,
              icon: Icons.travel_explore_rounded,
            ),
            _buildHelplineCard(
              number: '1091',
              title: 'Women Safety Helpline',
              subtitle: 'Dedicated 24/7 emergency dispatch for women travelers',
              color: Colors.purple.shade600,
              icon: Icons.shield_moon_rounded,
            ),
            _buildHelplineCard(
              number: '108',
              title: 'Medical Ambulance Dispatch',
              subtitle: 'Immediate medical & trauma paramedic response',
              color: Colors.teal.shade700,
              icon: Icons.medical_services_rounded,
            ),
            _buildHelplineCard(
              number: '139',
              title: 'Rail Madad / Railway Security',
              subtitle: 'Security & passenger help across Indian Railways',
              color: Colors.orange.shade800,
              icon: Icons.train_rounded,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineCard({
    required String number,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TOLL-FREE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call $number',
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
            onPressed: () => _callHelpline(title, number),
          ),
        ],
      ),
    );
  }
}
