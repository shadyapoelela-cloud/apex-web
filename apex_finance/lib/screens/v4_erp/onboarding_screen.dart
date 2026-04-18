/// APEX Onboarding Screen — wrapper for ApexV5OnboardingScreen.
/// Route: /app/onboarding
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/v5/apex_v5_onboarding_journey.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ApexV5OnboardingScreen(
      onDismiss: () => context.go('/app'),
    );
  }
}
