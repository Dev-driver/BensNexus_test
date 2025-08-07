import '../../generale/elementBensGroup.dart';
import 'package:flutter/material.dart';
import '../../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assetes/image/Back_welcome.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // color: Colors.black.withOpacity(0.3), // Assombrir légèrement le fond
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 1: Bienvenue
                  OnboardingPage(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(logo, height: 120),
                          const SizedBox(height: 250),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: RichText(
                              textAlign: TextAlign.left,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  height: 1.4,
                                  fontWeight: FontWeight.w200,
                                ),
                                children: [
                                  const TextSpan(text: 'Bienvenue sur '),
                                  TextSpan(
                                    text: nomApp,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        ', votre outil de visualisation et de contrôle à distance de vos matériels.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Page 2: À propos
                  const OnboardingPage(child: AboutBgaContent()),
                  // Page 3: Démarrer
                  OnboardingPage(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Carte semi-transparente pour le texte
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Pour bien debuter, nous vous demanderons une simple authentification. Veillez vous assurer que vos informations sont correcte',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: 180,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, '/auth');
                              },
                              child: const Text(
                                'Démarrer',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Indicateurs et flèches
              _buildNavigationControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Positioned(
      bottom: 40,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flèche gauche
          _currentPage != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 28),
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  color: Colors.red,
                )
              : const SizedBox(width: 34),

          // Indicateurs ronds
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                height: 9.0,
                width: _currentPage == index ? 18.0 : 9.0,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : const Color.fromARGB(255, 133, 133, 133)
                          .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }),
          ),

          // Flèche droite
          _currentPage != 2
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_outlined, size: 28),
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  color: Colors.red,
                )
              : const SizedBox(width: 34),
        ],
      ),
    );
  }
}

class AboutBgaContent extends StatelessWidget {
  const AboutBgaContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Card(
        color: Colors.black.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'À propos de BGA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cette application a pour vocation, au même titre que le site web de vous permettre de',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                  // fontWeight.normal = FontWeight.w400, le plus standard et le moins gras
                ),
              ),
              const BulletPoint(
                text: 'Suivre votre commande en temps réel',
              ),
              const BulletPoint(text: 'Interagir avec le chauffeur'),
              const BulletPoint(
                text: 'Avoir à portée de main nos offres exceptionnelles',
              ),
              const SizedBox(height: 20),
              const Text(
                'Notre plateforme vous garantit une expérience sécurisée, fluide et une assistance disponible à tout moment pour répondre à vos besoins.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
