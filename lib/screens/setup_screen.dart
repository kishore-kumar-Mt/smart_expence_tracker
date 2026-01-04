import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'home_screen.dart';
import 'pin_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await BiometricService.instance.hasBiometrics();
    setState(() {
      _canCheckBiometrics = canCheck;
    });
  }

  Future<void> _enableBiometrics() async {
    final success = await BiometricService.instance.authenticate();
    if (success) {
      await AuthService.instance.setBiometricEnabled();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
    }
  }

  void _setupPin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PinScreen(
          title: 'Set App PIN',
          onCompleted: (pin) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PinScreen(
                  title: 'Confirm PIN',
                  isConfirmMode: true,
                  confirmPin: pin,
                  onCompleted: (confirmPin) async {
                    if (pin == confirmPin) {
                      await AuthService.instance.setAppPin(pin);
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PINs do not match')),
                        );
                        // Pop back to Set PIN to retry
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent going back
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.blue),
                const SizedBox(height: 32),
                Text(
                  'Secure Your App',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose an authentication method to protect your data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),
                if (_canCheckBiometrics) ...[
                  ElevatedButton.icon(
                    onPressed: _enableBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Enable Biometrics'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                OutlinedButton.icon(
                  onPressed: _setupPin,
                  icon: const Icon(Icons.dialpad),
                  label: const Text('Set App PIN'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
