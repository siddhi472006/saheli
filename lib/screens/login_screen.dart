import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final String language;
  const LoginScreen({super.key, required this.language});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  bool get isHindi => widget.language == 'Hindi';
  String t(String english, String hindi) => isHindi ? hindi : english;

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });

    final user = await DatabaseHelper.instance.loginUser(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId',    user['id']);
      await prefs.setString('userName',  user['name']);
      await prefs.setString('userType',  user['userType']);
      await prefs.setString('language',  widget.language);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userId:   user['id'],
            userName: user['name'],
            userType: user['userType'],
            language: widget.language,
          ),
        ),
      );
    } else {
      setState(() => _error = t(
        'Invalid username or password.',
        'गलत उपयोगकर्ता नाम या पासवर्ड।',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E8C),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 42),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  t('Welcome Back', 'वापस स्वागत है'),
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E8C),
                  ),
                ),
              ),
              Center(
                child: Text(
                  t('Sign in to continue', 'जारी रखने के लिए साइन इन करें'),
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 48),

              Text(t('Username', 'उपयोगकर्ता नाम'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration(
                  hint: t('Enter username', 'उपयोगकर्ता नाम दर्ज करें'),
                  icon: Icons.person_outline,
                ),
              ),

              const SizedBox(height: 20),

              Text(t('Password', 'पासवर्ड'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  hint: t('Enter password', 'पासवर्ड दर्ज करें'),
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(t('Login', 'लॉगिन करें'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(language: widget.language),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: t("Don't have an account? ", "खाता नहीं है? "),
                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                      children: [
                        TextSpan(
                          text: t('Register', 'रजिस्टर करें'),
                          style: const TextStyle(
                            color: Color(0xFFE91E8C),
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFFE91E8C)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 2),
      ),
    );
  }
}