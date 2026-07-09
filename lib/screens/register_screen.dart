import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String language;
  const RegisterScreen({super.key, required this.language});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController            = TextEditingController();
  final _usernameController        = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _userType       = 'Individual';
  bool   _isLoading      = false;
  bool   _obscurePassword = true;
  bool   _obscureConfirm  = true;
  String? _error;

  bool get isHindi => widget.language == 'Hindi';
  String t(String english, String hindi) => isHindi ? hindi : english;

  Future<void> _register() async {
    final name     = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm  = _confirmPasswordController.text.trim();

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = t('Please fill all fields.', 'कृपया सभी फ़ील्ड भरें।'));
      return;
    }
    if (password != confirm) {
      setState(() => _error = t('Passwords do not match.', 'पासवर्ड मेल नहीं खाते।'));
      return;
    }
    if (password.length < 4) {
      setState(() => _error = t('Password must be at least 4 characters.',
          'पासवर्ड कम से कम 4 अक्षर का होना चाहिए।'));
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final id = await DatabaseHelper.instance.registerUser(
      name:     name,
      username: username,
      password: password,
      userType: _userType,
      language: widget.language,
    );

    setState(() => _isLoading = false);

    if (id == -1) {
      setState(() => _error = t(
        'Username already taken. Try another.',
        'यह उपयोगकर्ता नाम पहले से लिया गया है।',
      ));
    } else {
      // Auto-login after register
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId',       id);
      await prefs.setString('userName',  name);
      await prefs.setString('userType',  _userType);
      await prefs.setString('language',  widget.language);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userId:   id,
            userName: name,
            userType: _userType,
            language: widget.language,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('Create Account', 'खाता बनाएं')),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Text(t('I am a...', 'मैं हूं...'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _userTypeTile(
                  type:     'Individual',
                  label:    t('Individual Woman',   'व्यक्तिगत महिला'),
                  icon:     Icons.person,
                  sublabel: t('Scan for myself',    'खुद के लिए जांच'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _userTypeTile(
                  type:     'HealthWorker',
                  label:    t('ASHA / Health Worker', 'आशा / स्वास्थ्य कार्यकर्ता'),
                  icon:     Icons.local_hospital,
                  sublabel: t('Scan patients',      'मरीजों की जांच'),
                )),
              ]),

              const SizedBox(height: 28),

              _label(t('Full Name', 'पूरा नाम')),
              const SizedBox(height: 8),
              _field(
                controller: _nameController,
                hint: t('Enter your full name', 'अपना पूरा नाम दर्ज करें'),
                icon: Icons.badge_outlined,
              ),

              const SizedBox(height: 18),

              _label(t('Username', 'उपयोगकर्ता नाम')),
              const SizedBox(height: 8),
              _field(
                controller: _usernameController,
                hint: t('Choose a username', 'उपयोगकर्ता नाम चुनें'),
                icon: Icons.alternate_email,
              ),

              const SizedBox(height: 18),

              _label(t('Password', 'पासवर्ड')),
              const SizedBox(height: 8),
              _field(
                controller:    _passwordController,
                hint:          t('Create a password', 'पासवर्ड बनाएं'),
                icon:          Icons.lock_outline,
                obscure:       _obscurePassword,
                toggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),

              const SizedBox(height: 18),

              _label(t('Confirm Password', 'पासवर्ड की पुष्टि करें')),
              const SizedBox(height: 8),
              _field(
                controller:    _confirmPasswordController,
                hint:          t('Repeat your password', 'पासवर्ड दोबारा दर्ज करें'),
                icon:          Icons.lock_outline,
                obscure:       _obscureConfirm,
                toggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
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
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(t('Create Account', 'खाता बनाएं'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller:  controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText:   hint,
        prefixIcon: Icon(icon, color: const Color(0xFFE91E8C)),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled:    true,
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
      ),
    );
  }

  Widget _userTypeTile({
    required String type,
    required String label,
    required IconData icon,
    required String sublabel,
  }) {
    final isSelected = _userType == type;
    return GestureDetector(
      onTap: () => setState(() => _userType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE91E8C).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFE91E8C) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: isSelected ? const Color(0xFFE91E8C) : Colors.grey,
              size: 30),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFE91E8C) : Colors.black87,
              )),
          const SizedBox(height: 4),
          Text(sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? const Color(0xFFE91E8C).withOpacity(0.7)
                    : Colors.black45,
              )),
        ]),
      ),
    );
  }
}