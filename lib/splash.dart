import 'package:flutter/material.dart';
import 'app_info.dart';

/// In-app loading screen shown right after the native splash, until the app is
/// ready. Same colour as the native splash so the change is seamless.
/// Colours are fixed (not theme based) on purpose.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06134A),
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset('assets/logo/logo.png',
                  width: 140, height: 140, fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text(appName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Color(0xFFB4EB19)),
            ),
            const SizedBox(height: 14),
            const Text('Loading...',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
