import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../utils/app_theme.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'countries_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // Language selection dialog
  void _showLanguageDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundColor,
          title: Text(
            AppLocalizations.of(context).selectLanguage,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Turkish
              ListTile(
                title: Text(
                  AppLocalizations.of(context).languageTurkish,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
                leading: const CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://flagcdn.com/w80/tr.png',
                  ),
                ),
                onTap: () {
                  languageProvider.changeLanguage('tr');
                  Navigator.pop(context);
                },
                selected: languageProvider.currentLanguage == 'tr',
                selectedTileColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
              // English
              ListTile(
                title: Text(
                  AppLocalizations.of(context).languageEnglish,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
                leading: const CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://flagcdn.com/w80/gb.png',
                  ),
                ),
                onTap: () {
                  languageProvider.changeLanguage('en');
                  Navigator.pop(context);
                },
                selected: languageProvider.currentLanguage == 'en',
                selectedTileColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
              // Spanish
              ListTile(
                title: Text(
                  AppLocalizations.of(context).languageSpanish,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
                leading: const CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://flagcdn.com/w80/es.png',
                  ),
                ),
                onTap: () {
                  languageProvider.changeLanguage('es');
                  Navigator.pop(context);
                },
                selected: languageProvider.currentLanguage == 'es',
                selectedTileColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ],
          ),
        );
      },
    );
  }

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Remove loading screen after half a second
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/welcomescreen.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Darkening layer
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
          // Content
          _isLoading ? _buildLoadingScreen() : _buildWelcomeContent(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo or app name
          Shimmer.fromColors(
            baseColor: AppTheme.primaryColor,
            highlightColor: Colors.white,
            child: Text(
              AppLocalizations.of(context).appName,
              style: GoogleFonts.montserrat(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Loading indicator
          const CircularProgressIndicator(color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildWelcomeContent() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    String flagUrl = 'https://flagcdn.com/w80/gb.png'; // Default English flag
    
    // Set the correct flag based on selected language
    if (languageProvider.currentLanguage == 'tr') {
      flagUrl = 'https://flagcdn.com/w80/tr.png';
    } else if (languageProvider.currentLanguage == 'es') {
      flagUrl = 'https://flagcdn.com/w80/es.png';
    }
    
    return SafeArea(
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                // Logo
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        AppLocalizations.of(context).appName,
                        style: GoogleFonts.montserrat(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                // Title
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      AppLocalizations.of(context).welcomeTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Subtitle
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      AppLocalizations.of(context).welcomeSubtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const Spacer(),
                // Start button
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to countries screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CountriesScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).startButton,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Website URL and Privacy Notice Container
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Website URL with subtle decoration - clickable
                          GestureDetector(
                            onTap: () {
                              // Open fanla.net website
                              launchUrlString('https://fanla.net', 
                                  mode: LaunchMode.externalApplication);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language, size: 16, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context).websiteUrl,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Privacy notice with subtle styling
                          Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withOpacity(0.2),
                            ),
                            child: Text(
                              AppLocalizations.of(context).privacyNotice,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.white60,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Language selection button in top right corner
          Positioned(
            top: 10,
            right: 10,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: InkWell(
                onTap: () => _showLanguageDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(flagUrl),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
