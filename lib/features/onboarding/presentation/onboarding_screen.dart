import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.delivery_dining,
      title: 'Welcome to Jeeb',
      subtitle: 'Get anything delivered from anywhere in your city',
    ),
    _OnboardingPage(
      icon: Icons.mic,
      title: 'Voice Your Request',
      subtitle: 'Simply record what you need — we transcribe and match you with a Jeeber',
    ),
    _OnboardingPage(
      icon: Icons.star,
      title: 'Rate & Earn',
      subtitle: 'Rate your experience and earn rewards. Jeebers earn by delivering.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) => Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    )),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        Navigator.of(context).pushReplacementNamed('/register');
                      }
                    },
                    child: Text(_currentPage < _pages.length - 1 ? 'Next' : 'Get Started'),
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

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 48),
          Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
