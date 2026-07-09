import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/language_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaheliApp());
}

class SaheliApp extends StatelessWidget {
  const SaheliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saheli',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const StartupRouter(),
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs    = await SharedPreferences.getInstance();
    final language = prefs.getString('language');
    final userId   = prefs.getInt('userId');

    if (!mounted) return;

    if (language == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageScreen()),
      );
    } else if (userId != null) {
      final user = await DatabaseHelper.instance.getUserById(userId);
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              userId:   user['id'],
              userName: user['name'],
              userType: user['userType'],
              language: language,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen(language: language)),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(language: language)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF0F5),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E8C)),
      ),
    );
  }
}