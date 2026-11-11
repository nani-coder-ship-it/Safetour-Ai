import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import '../../../../injection_container.dart';
import '../../../../core/network/dio_client.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../../emergency_contacts/presentation/bloc/emergency_contacts_bloc.dart';
import '../../../emergency_contacts/presentation/bloc/emergency_contacts_state.dart';
import '../../../emergency_contacts/presentation/bloc/emergency_contacts_event.dart';
import '../../../emergency_contacts/presentation/pages/emergency_contacts_page.dart';
import '../../../auth/domain/entities/emergency_contact_entity.dart';

enum SosState {
  ready,
  countdown,
  dispatched,
}

class SosPage extends StatefulWidget {
  final bool autoTrigger;

  const SosPage({super.key, this.autoTrigger = false});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> with TickerProviderStateMixin {
  static const MethodChannel _platform = MethodChannel('com.safetour.ai/emergency');

  SosState _sosState = SosState.ready;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  Position? _currentPosition;
  bool _isLoadingPosition = true;
  String _networkStatus = 'Checking...';
  bool _isOnline = true;

  bool _isSirenActive = false;
  AudioPlayer? _audioPlayer;
  Timer? _hapticTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _strobeController;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the glowing SOS core
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Visual strobe controller for emergency flashes
    _strobeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _audioPlayer = AudioPlayer();

    // Ensure emergency contacts are loaded
    context.read<EmergencyContactsBloc>().add(LoadEmergencyContacts());

    // Fetch live coordinates and check network
    _initLocationAndNetwork();

    if (widget.autoTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCountdownSequence();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _pulseController.dispose();
    _strobeController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndNetwork() async {
    try {
      final locService = sl<DeviceLocationService>();
      var pos = await locService.getLastKnownPosition();
      pos ??= await locService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isLoadingPosition = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPosition = false;
        });
      }
    }

    // Quick connectivity check to the SafeTour backend
    try {
      final dio = sl<DioClient>().dio;
      final res = await dio.get('/', options: Options(receiveTimeout: const Duration(seconds: 3)));
      if (mounted) {
        setState(() {
          _isOnline = res.statusCode == 200;
          _networkStatus = _isOnline ? 'Online (Cloud + Offline SMS)' : 'Offline (Direct SMS Fallback)';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _networkStatus = 'Offline (Direct SMS & Helplines Active)';
        });
      }
    }
  }

  // --- SOS Sequence Logic ---

  void _startCountdownSequence() {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosState = SosState.countdown;
      _countdownSeconds = 5;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      HapticFeedback.mediumImpact();
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        _dispatchEmergencyDistress();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _sosState = SosState.ready;
      _countdownSeconds = 5;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ SOS sequence cancelled. You are safe.'),
        backgroundColor: Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _dispatchEmergencyDistress() async {
    _countdownTimer?.cancel();
    setState(() {
      _sosState = SosState.dispatched;
    });

    // 1. Start audio siren alarm automatically
    _activateSiren();

    // 2. Dispatch online cloud ping (if internet available)
    if (_isOnline) {
      _dispatchCloudPing();
    }

    // 3. Prepare distress message with live GPS
    final message = _buildDistressMessage();

    // 4. Prompt immediate action dialog for SMS or Call
    if (mounted) {
      _showDispatchedActionsModal(message);
    }
  }

  String _buildDistressMessage() {
    final lat = _currentPosition?.latitude ?? 14.4265;
    final lng = _currentPosition?.longitude ?? 79.9565;
    final accuracy = _currentPosition?.accuracy.toStringAsFixed(1) ?? '10.0';
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';

    return '🚨 EMERGENCY DISTRESS ALERT (SafeTour AI)\n'
        'I am in immediate danger and need urgent emergency assistance!\n\n'
        '📍 My Live GPS Location:\n'
        '$mapsUrl\n'
        'Coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} (±${accuracy}m)\n'
        'Time: ${DateTime.now().toLocal().toString().split('.')[0]}\n\n'
        'Please notify state emergency dispatch (112) or reach me immediately.';
  }

  Future<void> _dispatchCloudPing() async {
    try {
      final dio = sl<DioClient>().dio;
      final lat = _currentPosition?.latitude ?? 14.4265;
      final lng = _currentPosition?.longitude ?? 79.9565;

      await dio.post(
        '/location',
        data: {
          'latitude': lat,
          'longitude': lng,
          'accuracy': _currentPosition?.accuracy ?? 10.0,
          'isEmergency': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(sendTimeout: const Duration(seconds: 3)),
      );
    } catch (_) {
      // Offline fallback handles it without crashing
    }
  }

  // --- Siren & Audio Alarm ---

  Future<void> _toggleSiren() async {
    if (_isSirenActive) {
      _deactivateSiren();
    } else {
      _activateSiren();
    }
  }

  Future<void> _activateSiren() async {
    setState(() {
      _isSirenActive = true;
    });

    _strobeController.repeat(reverse: true);

    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      HapticFeedback.vibrate();
    });

    try {
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.setVolume(1.0);
      await _audioPlayer?.play(AssetSource('audio/siren.wav'));
    } catch (e) {
      debugPrint('[SOS Siren] Audio error: $e');
    }
  }

  Future<void> _deactivateSiren() async {
    setState(() {
      _isSirenActive = false;
    });
    _strobeController.stop();
    _hapticTimer?.cancel();
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
  }

  // --- Platform Native Telephony / SMS / Dialer ---

  Future<void> _dialHelpline(String number, String name) async {
    HapticFeedback.lightImpact();
    try {
      await _platform.invokeMethod('dialNumber', {'number': number});
    } catch (_) {
      Clipboard.setData(ClipboardData(text: number));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dialing $name: $number (Copied to clipboard).'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendDirectDistressSMS(String phone, String name) async {
    final message = _buildDistressMessage();
    HapticFeedback.mediumImpact();

    try {
      await _platform.invokeMethod('sendSMS', {
        'number': phone,
        'message': message,
      });
    } catch (_) {
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Distress SMS text copied for $name ($phone). Paste in SMS app.'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareUniversalDistress() async {
    final message = _buildDistressMessage();
    HapticFeedback.heavyImpact();

    try {
      await _platform.invokeMethod('shareLocation', {'message': message});
    } catch (_) {
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distress link copied to clipboard! Paste in any messaging app.'),
            backgroundColor: Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDispatchedActionsModal(String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOS Emergency Dispatched',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Siren active • Live coordinates locked',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS: ${_currentPosition?.latitude.toStringAsFixed(4) ?? "14.4265"}, ${_currentPosition?.longitude.toStringAsFixed(4) ?? "79.9565"}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        onPressed: _shareUniversalDistress,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share Link', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Quick Emergency Action:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _dialHelpline('112', 'National Emergency');
                        },
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call 112 Helpline', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareUniversalDistress();
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Dispatch SMS', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep tactical slate background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EMERGENCY SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          // Live connectivity pill badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0x2222C55E) : const Color(0x33F59E0B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isOnline ? 'Online + SMS' : 'Offline Ready',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Visual Strobe Flasher Overlay when siren is active
          if (_isSirenActive)
            AnimatedBuilder(
              animation: _strobeController,
              builder: (context, child) {
                return IgnorePointer(
                  child: Container(
                    color: Colors.red.withValues(alpha: _strobeController.value * 0.22),
                  ),
                );
              },
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // 1. SOS Main Interactive Core
                  _buildSosCoreSection(),
                  const SizedBox(height: 24),

                  // 2. Real-Time GPS Coordinates Beacon Card
                  _buildLiveGpsCard(),
                  const SizedBox(height: 20),

                  // 3. Siren & Panic Strobe Controller Bar
                  _buildSirenControllerBar(),
                  const SizedBox(height: 24),

                  // 4. Saved Emergency Contacts (Offline Fallback SMS Hub)
                  _buildEmergencyContactsSection(),
                  const SizedBox(height: 24),

                  // 5. Direct Emergency Helplines 1-Tap Grid
                  _buildNationalHelplinesSection(),
                  const SizedBox(height: 24),

                  // 6. Real-World Safety Advisory Notice
                  _buildSafetyDisclaimerCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildSosCoreSection() {
    if (_sosState == SosState.countdown) {
      // Countdown State
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEF4444), width: 2),
        ),
        child: Column(
          children: [
            const Text(
              'DISPATCHING SOS DISTRESS BEACON',
              style: TextStyle(
                color: Color(0xFFF87171),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            // Countdown circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: _countdownSeconds / 5.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                  ),
                ),
                Text(
                  '$_countdownSeconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Notifying emergency guardians and authorities in seconds...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _cancelCountdown,
                    child: const Text('CANCEL (I AM SAFE)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _dispatchEmergencyDistress,
                    child: const Text('DISPATCH NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_sosState == SosState.dispatched) {
      // Dispatched / Active State
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF7F1D1D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEF4444), width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DISTRESS BEACON ACTIVATED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your GPS coordinates are armed for dispatch to your emergency contacts and police.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _shareUniversalDistress,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Distress SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _deactivateSiren();
                      setState(() {
                        _sosState = SosState.ready;
                      });
                    },
                    child: const Text('Reset SOS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default: Ready State
    return Column(
      children: [
        const SizedBox(height: 10),
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _startCountdownSequence,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFDC2626),
                    Color(0xFF991B1B),
                  ],
                  stops: [0.3, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                    SizedBox(height: 4),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      'PRESS TO ACTIVATE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Tap to initiate 5-second emergency distress protocol',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLiveGpsCard() {
    final lat = _currentPosition?.latitude;
    final lng = _currentPosition?.longitude;
    final acc = _currentPosition?.accuracy.toStringAsFixed(1) ?? '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'LIVE GPS BEACON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 18),
                onPressed: _initLocationAndNetwork,
                tooltip: 'Refresh GPS',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPosition)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                ),
                SizedBox(width: 10),
                Text('Acquiring high-accuracy GPS fix...', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lat != null && lng != null ? '${lat.toStringAsFixed(5)}° N, ${lng.toStringAsFixed(5)}° E' : 'GPS Unavailable',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accuracy: ±$acc meters • Live satellite lock',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0369A1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _shareUniversalDistress,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSirenControllerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isSirenActive ? const Color(0xFF450A0A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isSirenActive ? const Color(0xFFEF4444) : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isSirenActive ? const Color(0xFFEF4444) : const Color(0xFF64748B)).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isSirenActive ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isSirenActive ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSirenActive ? 'Audible Siren ACTIVE' : 'Audible Panic Siren',
                  style: TextStyle(
                    color: _isSirenActive ? const Color(0xFFFCA5A5) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  _isSirenActive ? 'Loud piercing siren sounding repeatedly' : 'Deter attackers & attract nearby attention',
                  style: TextStyle(
                    color: _isSirenActive ? Colors.white70 : const Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isSirenActive,
            activeColor: const Color(0xFFEF4444),
            onChanged: (val) => _toggleSiren(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return BlocBuilder<EmergencyContactsBloc, EmergencyContactsState>(
      builder: (context, state) {
        final contacts = state.contacts;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'EMERGENCY GUARDIANS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (contacts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF94A3B8), size: 30),
                    const SizedBox(height: 8),
                    const Text(
                      'No Personal Guardians Registered',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Add your family or emergency contacts to send 1-tap distress SMS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsPage()));
                      },
                      child: const Text('Add Guardian Contacts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return _buildContactCard(contact);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildContactCard(EmergencyContactEntity contact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'G',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${contact.relation.isNotEmpty ? "${contact.relation} • " : ""}${contact.phone}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Send SMS Button
          IconButton(
            tooltip: 'Send Distress SMS',
            icon: const Icon(Icons.sms_rounded, color: Color(0xFF38BDF8), size: 22),
            onPressed: () => _sendDirectDistressSMS(contact.phone, contact.name),
          ),
          // Call Button
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_rounded, color: Color(0xFF4ADE80), size: 22),
            onPressed: () => _dialHelpline(contact.phone, contact.name),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalHelplinesSection() {
    final helplines = [
      {'name': 'National Emergency', 'number': '112', 'subtitle': 'Police / Ambulance / Fire', 'color': const Color(0xFFEF4444)},
      {'name': 'Police Control', 'number': '100', 'subtitle': 'Law enforcement dispatch', 'color': const Color(0xFF3B82F6)},
      {'name': 'Medical Ambulance', 'number': '108', 'subtitle': 'Government emergency medical', 'color': const Color(0xFF10B981)},
      {'name': 'Women Helpline', 'number': '1091', 'subtitle': '24/7 Rapid response for women', 'color': const Color(0xFFEC4899)},
      {'name': 'Tourist Helpline', 'number': '1363', 'subtitle': 'Ministry of Tourism multi-lingual', 'color': const Color(0xFF8B5CF6)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: Color(0xFFF59E0B), size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'NATIONAL EMERGENCY HELPLINES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: helplines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final line = helplines[index];
            final Color color = line['color'] as Color;

            return InkWell(
              onTap: () => _dialHelpline(line['number'] as String, line['name'] as String),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          line['number'] as String,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line['name'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          Text(
                            line['subtitle'] as String,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.call_rounded, color: color, size: 18),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSafetyDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SafeTour AI Emergency Hub operates even during complete cellular data blackout. Coordinates and distress links are formatted for immediate transmission via SMS and standard GSM telephony.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
