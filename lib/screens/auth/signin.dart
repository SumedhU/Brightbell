import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brightbell/utils/auth_utils.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthUtils.signInWithGoogle();
      if (userCredential == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      // Navigation is handled by auth state listener in main.dart
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication Error')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.fitness_center,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 24),
              const Text(
                'Brightbell',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log your workouts simply.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : ElevatedButton(
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.g_mobiledata, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
