import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/themes/color_palette.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/explore_lesotho_logo.dart';
import '../auth/auth_wrapper.dart';
import '../auth/login_screen.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  static const String completedKey = 'onboarding_completed';

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _isCompleted;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCompleted = prefs.getBool(OnboardingGate.completedKey) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted == null) {
      return const _BrandedLoadingScreen();
    }

    return _isCompleted! ? const AuthWrapper() : const WelcomeStartScreen();
  }
}

class WelcomeStartScreen extends StatelessWidget {
  const WelcomeStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _OnboardingScaffold(
        child: Column(
          children: [
            const Spacer(),
            const ExploreLesothoLogo(size: 118),
            const SizedBox(height: 28),
            const Text(
              'Explore Lesotho',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Discover the Mountain Kingdom',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 34),
            _FeaturePill(
              icon: Icons.terrain,
              text: 'Culture, stays, events, vendors, and live insights',
            ),
            const Spacer(),
            _PrimaryOnboardingButton(
              label: 'Start',
              icon: Icons.arrow_forward,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LanguageOnboardingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class LanguageOnboardingScreen extends StatelessWidget {
  const LanguageOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _OnboardingScaffold(
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            final selected = localeProvider.locale.languageCode;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                const ExploreLesothoLogo(size: 76),
                const SizedBox(height: 34),
                const Text(
                  'Choose your language',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Khetha puo eo u batlang ho e sebelisa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 34),
                _LanguageCard(
                  title: 'English',
                  subtitle: 'Use Explore Lesotho in English',
                  selected: selected == 'en',
                  onTap: () => localeProvider.setLocale('en'),
                ),
                const SizedBox(height: 16),
                _LanguageCard(
                  title: 'Sesotho sa Lesotho',
                  subtitle: 'Sebelisa Explore Lesotho ka Sesotho',
                  selected: selected == 'st',
                  onTap: () => localeProvider.setLocale('st'),
                ),
                const Spacer(),
                _PrimaryOnboardingButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOnboardingScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TermsOnboardingScreen extends StatefulWidget {
  const TermsOnboardingScreen({super.key});

  @override
  State<TermsOnboardingScreen> createState() => _TermsOnboardingScreenState();
}

class _TermsOnboardingScreenState extends State<TermsOnboardingScreen> {
  bool _accepted = false;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingGate.completedKey, true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _OnboardingScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            const ExploreLesothoLogo(size: 76),
            const SizedBox(height: 28),
            const Text(
              'Terms & Privacy',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A real app deserves a clear agreement before sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TermsPoint(
                        title: 'Respect local communities',
                        body:
                            'Use the platform to discover Lesotho responsibly and support verified local vendors.',
                      ),
                      _TermsPoint(
                        title: 'Keep information accurate',
                        body:
                            'Bookings, listings, reviews, and vendor details should be honest and up to date.',
                      ),
                      _TermsPoint(
                        title: 'Protect account access',
                        body:
                            'Do not share your password or misuse another user, vendor, or admin account.',
                      ),
                      _TermsPoint(
                        title: 'Privacy matters',
                        body:
                            'Your profile, bookings, messages, and location-related features are handled for app functionality and safety.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              value: _accepted,
              onChanged: (value) {
                setState(() {
                  _accepted = value ?? false;
                });
              },
              activeColor: Colors.white,
              checkColor: ColorPalette.primaryGreen,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I agree to the Terms of Service and Privacy Policy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PrimaryOnboardingButton(
              label: 'Continue to Login',
              icon: Icons.login,
              onPressed: _accepted ? _finish : null,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _BrandedLoadingScreen extends StatelessWidget {
  const _BrandedLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _OnboardingScaffold(
        child: Center(
          child: ExploreLesothoLogo(size: 96),
        ),
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF4CAF50),
            Color(0xFFEAF7EC),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryOnboardingButton extends StatelessWidget {
  const _PrimaryOnboardingButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
          foregroundColor: ColorPalette.darkGreen,
          disabledForegroundColor:
              ColorPalette.darkGreen.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? ColorPalette.darkGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.language,
              color: selected
                  ? ColorPalette.primaryGreen
                  : ColorPalette.textSecondary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsPoint extends StatelessWidget {
  const _TermsPoint({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, color: ColorPalette.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    height: 1.35,
                    color: ColorPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
