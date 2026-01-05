import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'main_screen.dart';
import 'pin_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAuthenticating = false;
  String _message = 'Locked';

  @override
  void initState() {
    super.initState();
    _checkAuthMethod();
  }

  Future<void> _checkAuthMethod() async {
    if (AuthService.instance.authMethod == AuthMethod.biometric) {
      _authenticateBiometric();
    }
    // If PIN, PinScreen is shown automatically by build()
  }

  Future<void> _authenticateBiometric() async {
    setState(() {
      _isAuthenticating = true;
      _message = 'Authenticating...';
    });

    final isAuthenticated = await BiometricService.instance.authenticate();

    if (isAuthenticated) {
      _navigateToHome();
    } else {
      setState(() {
        _isAuthenticating = false;
        _message = 'Authentication failed. Tap to retry.';
      });
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.authMethod == AuthMethod.pin) {
      return PopScope(
        canPop: false,
        child: PinScreen(
          title: 'Enter PIN',
          onCompleted: (pin) {
            if (AuthService.instance.verifyPin(pin)) {
              _navigateToHome();
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
            }
          },
        ),
      );
    }

    // Biometric UI
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text('Locked', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(_message),
              const SizedBox(height: 30),
              if (!_isAuthenticating)
                ElevatedButton.icon(
                  onPressed: _authenticateBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
