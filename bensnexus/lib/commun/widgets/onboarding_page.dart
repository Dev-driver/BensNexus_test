// lib/widgets/onboarding_page.dart
import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  final Widget child;

  const OnboardingPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Center(child: child),
    );
  }
}