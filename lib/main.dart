import 'package:brightbell/theme/app_theme.dart';
import 'package:brightbell/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightbell/screens/home.dart';
import 'package:brightbell/screens/auth/signin.dart';
import 'package:brightbell/screens/auth/onboarding/chat.dart';
import 'package:brightbell/screens/splash.dart';
import 'package:brightbell/utils/notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SplashGate(ready: _initialize(), child: const MyApp()));
}

Future<void> _initialize() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Debug builds use the debug provider; register the token printed in the
  // logs under App Check > Manage debug tokens in the Firebase console.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );
  await NotificationService().init();
}

const _loading = Scaffold(
  body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brightbell',
      theme: buildAppTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading;
          }
          if (snapshot.data != null) {
            return const _OnboardingGate();
          }
          return const SignIn();
        },
      ),
    );
  }
}

/// Shows onboarding until it has been completed, then the home screen.
///
/// Lives under the auth stream (rather than onboarding pushing a new root
/// route) so signing out always returns to the sign-in screen.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  static const _completedKey = 'onboarding_completed';
  bool? _completed;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _completed = prefs.getBool(_completedKey) ?? false);
      }
    });
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_completed) {
      null => _loading,
      true => const Home(),
      false => ChatOnboardingScreen(onComplete: _complete),
    };
  }
}
