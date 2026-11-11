import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textMuted = const Color(0xFF64748B);
  final Color _inputBg = const Color(0xFFF8FAFC);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = (screenHeight * 0.38).clamp(260.0, 340.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is Authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login Successful! Welcome back.'),
                backgroundColor: Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Start location tracking automatically
            context.read<LocationBloc>().add(StartTracking());

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Top Mountain Scenic Header
                SizedBox(
                  height: headerHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Mountain illustration canvas
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MountainHeaderPainter(),
                        ),
                      ),
                      // SafeTour AI Logo, Brand Name & Tagline
                      SafeArea(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Brand Shield Logo Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _primaryBlue,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryBlue.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SafeTour AI',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Your safety, every journey.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _textMuted,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. White Sheet Form Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Welcome back" Title
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue your safe journey.',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Email Field
                      _buildInputField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      // Password Field
                      _buildInputField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onTogglePassword: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset link will be sent to your email.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: _primaryBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Log In Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: state is AuthLoading
                              ? null
                              : () {
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text.trim();
                                  if (email.isEmpty || password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter both email and password.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  context.read<AuthBloc>().add(
                                        LoginRequested(
                                          email: email,
                                          password: password,
                                        ),
                                      );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: state is AuthLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider "or continue with"
                      Row(
                        children: [
                          Expanded(child: Divider(color: _borderColor, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: _borderColor, thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Social Button: Continue with Google
                      _buildSocialCard(
                        title: 'Continue with Google',
                        iconWidget: const _GoogleLogoWidget(),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google Sign-In integration ready.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Social Button: Continue with Apple
                      _buildSocialCard(
                        title: 'Continue with Apple',
                        iconWidget: const Icon(Icons.apple, color: Colors.black, size: 22),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Apple Sign-In integration ready.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Footer: Don't have an account? Sign up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                              );
                            },
                            child: Text(
                              'Sign up',
                              style: TextStyle(
                                color: _primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        style: TextStyle(color: _textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSocialCard({
    required String title,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom multi-colored Google logo icon
class _GoogleLogoWidget extends StatelessWidget {
  const _GoogleLogoWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GooglePainter(),
      ),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw Google 4-color arcs
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.butt;

    // Red (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.4, false, paint);

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -1.0, 1.3, false, paint);

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.3, 1.3, false, paint);

    // Blue (right & crossbar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 1.6, 1.1, false, paint);

    // Center crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - 1, center.dy), Offset(center.dx + radius - 1, center.dy), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scenic mountain vector illustration painter matching the reference header
class MountainHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky Gradient Background
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEFF6FF), // soft pale sky
          Color(0xFFDBEAFE),
          Color(0xFFBFDBFE), // gentle blue horizon
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Far Distant Mountains (Soft Light Blue/Grey)
    final farMountainPaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.55);
    final farPath = Path()
      ..moveTo(0, h * 0.65)
      ..lineTo(w * 0.15, h * 0.48)
      ..lineTo(w * 0.35, h * 0.62)
      ..lineTo(w * 0.55, h * 0.38)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.88, h * 0.42)
      ..lineTo(w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(farPath, farMountainPaint);

    // 3. Mid-range Mountains (Medium Blue)
    final midMountainPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.75);
    final midPath = Path()
      ..moveTo(0, h * 0.75)
      ..lineTo(w * 0.18, h * 0.58)
      ..lineTo(w * 0.38, h * 0.70)
      ..lineTo(w * 0.52, h * 0.44)
      ..lineTo(w * 0.68, h * 0.62)
      ..lineTo(w * 0.85, h * 0.48)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(midPath, midMountainPaint);

    // 4. Foreground Dark Mountain Ridge (Deep Royal/Alpine Navy)
    final fgMountainPaint = Paint()..color = const Color(0xFF1E3A8A);
    final fgPath = Path()
      ..moveTo(0, h * 0.78)
      ..lineTo(w * 0.28, h * 0.64)
      ..lineTo(w * 0.50, h * 0.74)
      ..lineTo(w * 0.76, h * 0.48) // High Summit Peak
      ..lineTo(w * 0.82, h * 0.52)
      ..lineTo(w, h * 0.68)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(fgPath, fgMountainPaint);

    // 5. High Cliff & Ridge (Deep Midnight Navy)
    final cliffPaint = Paint()..color = const Color(0xFF0F172A);
    final cliffPath = Path()
      ..moveTo(w * 0.48, h)
      ..lineTo(w * 0.62, h * 0.72)
      ..lineTo(w * 0.76, h * 0.48) // The Peak summit where hiker stands
      ..lineTo(w * 0.88, h * 0.62)
      ..lineTo(w, h * 0.58)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(cliffPath, cliffPaint);

    // 6. Pine Trees on Left Ridge
    final treePaint = Paint()..color = const Color(0xFF0F172A);
    final List<Offset> treeBases = [
      Offset(w * 0.04, h * 0.76),
      Offset(w * 0.08, h * 0.74),
      Offset(w * 0.12, h * 0.71),
      Offset(w * 0.16, h * 0.68),
      Offset(w * 0.20, h * 0.66),
      Offset(w * 0.25, h * 0.65),
      Offset(w * 0.30, h * 0.68),
      Offset(w * 0.35, h * 0.71),
    ];
    for (int i = 0; i < treeBases.length; i++) {
      _drawPineTree(canvas, treeBases[i], 18.0 + (i % 3) * 6, treePaint);
    }

    // 7. Silhouette of Solo Hiker on the Summit Ridge (around w * 0.76, h * 0.48)
    final hikerCenter = Offset(w * 0.76, h * 0.48);
    final hikerPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Hiker Head
    canvas.drawCircle(Offset(hikerCenter.dx, hikerCenter.dy - 26), 3.8, hikerPaint);

    // Hiker Torso & Backpack
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(hikerCenter.dx, hikerCenter.dy - 16), width: 7, height: 12),
      const Radius.circular(2),
    );
    canvas.drawRRect(torsoRect, hikerPaint);

    // Backpack on hiker's back
    final backpackRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(hikerCenter.dx + 4.5, hikerCenter.dy - 16), width: 5.5, height: 10),
      const Radius.circular(2),
    );
    canvas.drawRRect(backpackRect, hikerPaint);

    // Hiker Legs
    final legPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hikerCenter.dx - 2, hikerCenter.dy - 10), Offset(hikerCenter.dx - 4, hikerCenter.dy), legPaint);
    canvas.drawLine(Offset(hikerCenter.dx + 2, hikerCenter.dy - 10), Offset(hikerCenter.dx + 3, hikerCenter.dy), legPaint);

    // Walking staff / Trekking pole held in hand
    final staffPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hikerCenter.dx - 7, hikerCenter.dy - 22), Offset(hikerCenter.dx - 7, hikerCenter.dy + 3), staffPaint);

    // Arm holding staff
    canvas.drawLine(Offset(hikerCenter.dx - 2, hikerCenter.dy - 18), Offset(hikerCenter.dx - 7, hikerCenter.dy - 12), staffPaint);

    // 8. Smooth Bottom Curve Transition into White Card Sheet
    final bottomCurvePaint = Paint()..color = Colors.white;
    final curvePath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..cubicTo(
        w * 0.35, h * 0.88,
        w * 0.65, h * 0.98,
        w, h * 0.91,
      )
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(curvePath, bottomCurvePaint);
  }

  void _drawPineTree(Canvas canvas, Offset base, double height, Paint paint) {
    final double width = height * 0.45;
    final path = Path()
      ..moveTo(base.dx, base.dy - height)
      ..lineTo(base.dx - width * 0.5, base.dy - height * 0.6)
      ..lineTo(base.dx - width * 0.35, base.dy - height * 0.6)
      ..lineTo(base.dx - width * 0.7, base.dy - height * 0.25)
      ..lineTo(base.dx - width * 0.45, base.dy - height * 0.25)
      ..lineTo(base.dx - width * 0.85, base.dy)
      ..lineTo(base.dx + width * 0.85, base.dy)
      ..lineTo(base.dx + width * 0.45, base.dy - height * 0.25)
      ..lineTo(base.dx + width * 0.7, base.dy - height * 0.25)
      ..lineTo(base.dx + width * 0.35, base.dy - height * 0.6)
      ..lineTo(base.dx + width * 0.5, base.dy - height * 0.6)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
