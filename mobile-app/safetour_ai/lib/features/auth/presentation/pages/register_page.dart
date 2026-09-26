import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../home/presentation/pages/home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  final Color _blueColor = const Color(0xFF0B4682);
  final Color _darkCardColor = const Color(0xFF181818);
  final Color _inputColor = const Color(0xFF1E1E1E);
  final Color _borderColor = const Color(0xFF333333);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            RegisterRequested(
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blueColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is Authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration Successful!')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '9:41', // Just as a placeholder
                        style: TextStyle(color: Colors.transparent, fontSize: 14), 
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        label: const Text(
                          'Back to login',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom Card Section
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _darkCardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your digital tourist ID starts here',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Full name Field
                            _buildTextField(
                              controller: _nameController,
                              hint: 'Full name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              hint: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Must be at least 6 characters';
                                }
                                if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                                  return 'Must contain at least one lowercase letter';
                                }
                                if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                                  return 'Must contain at least one uppercase letter';
                                }
                                if (!RegExp(r'(?=.*[!@#\$&*~])').hasMatch(value)) {
                                  return 'Must contain a special symbol (!@#\$&*~)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Emergency contact Field
                            _buildTextField(
                              controller: _emergencyContactController,
                              hint: 'Emergency contact',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ', // Static prefix
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter emergency contact';
                                }
                                final phoneRegex = RegExp(r'^\d{10}$');
                                if (!phoneRegex.hasMatch(value.trim())) {
                                  return 'Must be exactly 10 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            
                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blueColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: state is AuthLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Sign up',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? prefixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
        filled: true,
        fillColor: _inputColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
