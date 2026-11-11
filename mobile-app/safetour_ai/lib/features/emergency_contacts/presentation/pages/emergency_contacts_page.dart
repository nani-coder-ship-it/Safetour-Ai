import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:safetour_ai/features/auth/domain/entities/emergency_contact_entity.dart';
import 'package:safetour_ai/features/emergency_contacts/presentation/bloc/emergency_contacts_bloc.dart';
import 'package:safetour_ai/features/emergency_contacts/presentation/bloc/emergency_contacts_event.dart';
import 'package:safetour_ai/features/emergency_contacts/presentation/bloc/emergency_contacts_state.dart';
import 'package:safetour_ai/features/location/data/services/device_location_service.dart';
import 'package:safetour_ai/injection_container.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage>
    with SingleTickerProviderStateMixin {
  late EmergencyContactsBloc _contactsBloc;
  late DeviceLocationService _locationService;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSirenActive = false;
  Timer? _sirenTimer;
  late AnimationController _pulseController;
  AudioPlayer? _audioPlayer;

  static const List<Color> _avatarColors = [
    Colors.deepPurple,
    Colors.teal,
    Colors.blueAccent,
    Color(0xFFE65100), // Dark Orange
    Color(0xFFC2185B), // Deep Pink
  ];

  @override
  void initState() {
    super.initState();
    _contactsBloc = sl<EmergencyContactsBloc>()..add(LoadEmergencyContacts());
    _locationService = sl<DeviceLocationService>();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _audioPlayer = AudioPlayer();
    _loadLocation();
  }

  @override
  void dispose() {
    _sirenTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _pulseController.dispose();
    _contactsBloc.close();
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

  Future<void> _toggleSiren() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSirenActive = !_isSirenActive;
    });

    if (_isSirenActive) {
      _sirenTimer?.cancel();
      _sirenTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        HapticFeedback.vibrate();
      });

      try {
        await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer?.setVolume(1.0);
        await _audioPlayer?.play(AssetSource('audio/siren.wav'));
      } catch (e) {
        debugPrint('[Emergency Siren] Audio playback error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Panic Siren Activated! Audible alarm & strobe active.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      _sirenTimer?.cancel();
      try {
        await _audioPlayer?.stop();
      } catch (e) {
        debugPrint('[Emergency Siren] Audio stop error: $e');
      }
    }
  }

  void _shareLocationAlert([EmergencyContactEntity? contact]) {
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
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (contact != null) {
                  await const MethodChannel('com.safetour.ai/emergency').invokeMethod('sendSMS', {
                    'number': contact.phone,
                    'message': message,
                  });
                } else {
                  await const MethodChannel('com.safetour.ai/emergency').invokeMethod('shareLocation', {
                    'message': message,
                  });
                }
              } catch (_) {
                Clipboard.setData(ClipboardData(text: message));
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(contact != null
                        ? 'Distress SMS dispatched for ${contact.name}!'
                        : 'Coordinates ready to broadcast!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Dispatch SMS'),
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
              'Number: $number',
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
                        SnackBar(content: Text('Number $number copied to clipboard!')),
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
                    onPressed: () async {
                      try {
                        await const MethodChannel('com.safetour.ai/emergency').invokeMethod('dialNumber', {'number': number});
                      } catch (_) {
                        Clipboard.setData(ClipboardData(text: number));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Dialing $number ($name)...'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
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

  void _callContact(EmergencyContactEntity contact) {
    _callHelpline(contact.name, contact.phone);
  }

  void _showContactDialog({EmergencyContactEntity? existingContact, int? index}) {
    final isEditing = existingContact != null && index != null;
    final nameCtrl = TextEditingController(text: existingContact?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingContact?.phone ?? '');
    String relation = (existingContact?.relation != null && existingContact!.relation.isNotEmpty)
        ? existingContact.relation
        : 'Family';

    const relationsList = ['Family', 'Friend', 'Guide', 'Hotel', 'Colleague', 'Doctor', 'Other'];
    if (!relationsList.contains(relation)) {
      relation = 'Other';
    }

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
              Text(
                isEditing ? 'Edit Emergency Contact' : 'Add Trusted Guardian',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isEditing
                    ? 'Update contact details for emergency dispatches.'
                    : 'This contact will receive SOS alerts with your live coordinates (Max 5).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+919876543210',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: '10 to 15 digits (optional leading +)',
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
                items: relationsList
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
                    final trimmedName = nameCtrl.text.trim();
                    // Clean spaces, hyphens, and parentheses for validation
                    final rawPhone = phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');

                    if (trimmedName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter contact name')),
                      );
                      return;
                    }

                    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                    if (!phoneRegex.hasMatch(rawPhone)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid phone number (10-15 digits, optional +)'),
                        ),
                      );
                      return;
                    }

                    final contact = EmergencyContactEntity(
                      id: existingContact?.id,
                      name: trimmedName,
                      phone: rawPhone,
                      relation: relation,
                    );

                    if (isEditing) {
                      _contactsBloc.add(EditEmergencyContact(index: index, contact: contact));
                    } else {
                      _contactsBloc.add(AddEmergencyContact(contact));
                    }

                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isEditing ? 'Save Changes' : 'Save Guardian',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, int index, EmergencyContactEntity contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 26),
            const SizedBox(width: 8),
            const Text('Remove Contact?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${contact.name}" from your emergency contacts?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _contactsBloc.add(DeleteEmergencyContact(index));
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _contactsBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Guardians & Emergency',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
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
        body: BlocConsumer<EmergencyContactsBloc, EmergencyContactsState>(
          listener: (context, state) {
            if (state is EmergencyContactsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.teal.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state is EmergencyContactsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          builder: (context, state) {
            final contacts = state.contacts;
            final isSaving = state is EmergencyContactsSaving;
            final isLoading = state is EmergencyContactsLoading && contacts.isEmpty;

            return SingleChildScrollView(
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

                  // Top Sync indicator if syncing
                  if (isSaving)
                    const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(Colors.teal),
                      minHeight: 3,
                    ),

                  const SizedBox(height: 20),

                  // Section: Trusted Guardians Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Flexible(
                                child: Text(
                                  'Trusted Guardians',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: contacts.length >= 5
                                      ? Colors.orange.shade100
                                      : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${contacts.length}/5',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: contacts.length >= 5
                                        ? Colors.orange.shade900
                                        : Colors.teal.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: contacts.length >= 5
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Maximum 5 emergency contacts reached.'),
                                    ),
                                  );
                                }
                              : () => _showContactDialog(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: contacts.length >= 5 ? Colors.grey : Colors.teal.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Guardian',
                                  style: TextStyle(
                                    color: contacts.length >= 5 ? Colors.grey : Colors.teal.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Guardians Content
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    )
                  else if (contacts.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.contacts_outlined,
                              size: 40,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Emergency Contacts Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add up to 5 trusted guardians (family, friends, or tour guides) who can be notified instantly during an emergency.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _showContactDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Guardian'),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final avatarColor = _avatarColors[index % _avatarColors.length];
                        final initial = contact.name.trim().isNotEmpty
                            ? contact.name.trim().substring(0, 1).toUpperCase()
                            : '?';

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
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: avatarColor.withOpacity(0.15),
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        color: avatarColor,
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
                                                contact.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (contact.relation.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: avatarColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  contact.relation,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: avatarColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          contact.phone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit Contact',
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                    onPressed: () => _showContactDialog(
                                      existingContact: contact,
                                      index: index,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove Contact',
                                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade400),
                                    onPressed: () => _showDeleteConfirmDialog(context, index, contact),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: Colors.teal.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () => _shareLocationAlert(contact),
                                      icon: const Icon(Icons.share_location_rounded, size: 16, color: Colors.teal),
                                      label: const Text(
                                        'Share GPS',
                                        style: TextStyle(
                                          color: Colors.teal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _callContact(contact),
                                      icon: const Icon(Icons.phone_rounded, size: 16),
                                      label: const Text(
                                        'Call',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

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
                    number: '100',
                    title: 'Police Emergency Dispatch',
                    subtitle: 'Immediate local police assistance and safety patrol',
                    color: Colors.blue.shade800,
                    icon: Icons.local_police_rounded,
                  ),
                  _buildHelplineCard(
                    number: '108',
                    title: 'Medical Ambulance Dispatch',
                    subtitle: 'Immediate medical & trauma paramedic response',
                    color: Colors.teal.shade700,
                    icon: Icons.medical_services_rounded,
                  ),
                  _buildHelplineCard(
                    number: '1091',
                    title: 'Women Safety Helpline',
                    subtitle: 'Dedicated 24/7 emergency dispatch for women travelers',
                    color: Colors.purple.shade600,
                    icon: Icons.shield_moon_rounded,
                  ),
                  _buildHelplineCard(
                    number: '1363',
                    title: 'Tourist Infoline (Govt of India)',
                    subtitle: '24x7 Multi-lingual tourist assistance & guidance',
                    color: Colors.indigo.shade600,
                    icon: Icons.travel_explore_rounded,
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
            );
          },
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
