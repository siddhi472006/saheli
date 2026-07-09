import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English';

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selectedLanguage);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(language: _selectedLanguage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    final sw = MediaQuery.of(context).size.width;
    final pad = sw * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: sh * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: sh * 0.03),

              // Logo
              Container(
                width: sw * 0.24,
                height: sw * 0.24,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C),
                  borderRadius: BorderRadius.circular(sw * 0.07),
                ),
                child: Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: sw * 0.13,
                ),
              ),

              SizedBox(height: sh * 0.025),

              Text(
                'Saheli / सहेली',
                style: TextStyle(
                  fontSize: sw * 0.08,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE91E8C),
                ),
              ),

              SizedBox(height: sh * 0.008),

              // Tagline English
              Text(
                'Your health companion for a stronger tomorrow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sw * 0.034,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),

              SizedBox(height: sh * 0.006),

              // Tagline Hindi
              Text(
                'एक स्वस्थ कल के लिए, आपकी सच्ची सहेली',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sw * 0.034,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),

              SizedBox(height: sh * 0.05),

              Text(
                'Choose your language\nभाषा चुनें',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sw * 0.045,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: sh * 0.025),

              _languageTile(
                language: 'English',
                label: 'English',
                sublabel: 'Continue in English',
                sw: sw,
              ),

              SizedBox(height: sh * 0.018),

              _languageTile(
                language: 'Hindi',
                label: 'हिंदी',
                sublabel: 'हिंदी में जारी रखें',
                sw: sw,
              ),

              SizedBox(height: sh * 0.045),

              SizedBox(
                width: double.infinity,
                height: sh * 0.07,
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedLanguage == 'English'
                        ? 'Continue →'
                        : 'आगे बढ़ें →',
                    style: TextStyle(
                      fontSize: sw * 0.046,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: sh * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageTile({
    required String language,
    required String label,
    required String sublabel,
    required double sw,
  }) {
    final isSelected = _selectedLanguage == language;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = language),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.05,
          vertical: sw * 0.045,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE91E8C).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE91E8C)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Language icon instead of flag
            Container(
              width: sw * 0.11,
              height: sw * 0.11,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE91E8C).withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(sw * 0.03),
              ),
              child: Center(
                child: Text(
                  language == 'English' ? 'A' : 'अ',
                  style: TextStyle(
                    fontSize: sw * 0.055,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFFE91E8C)
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),

            SizedBox(width: sw * 0.04),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: sw * 0.045,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFFE91E8C)
                        : Colors.black87,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: sw * 0.032,
                    color: isSelected
                        ? const Color(0xFFE91E8C).withOpacity(0.7)
                        : Colors.black54,
                  ),
                ),
              ],
            ),

            const Spacer(),

            if (isSelected)
              Icon(
                Icons.check_circle,
                color: const Color(0xFFE91E8C),
                size: sw * 0.065,
              ),
          ],
        ),
      ),
    );
  }
}