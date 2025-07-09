import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import 'teams_screen.dart';
import 'dart:ui';
import '../providers/api_provider.dart';
import '../models/country.dart';
import '../l10n/app_localizations.dart';

class CountriesScreen extends StatefulWidget {
  const CountriesScreen({Key? key}) : super(key: key);

  @override
  State<CountriesScreen> createState() => _CountriesScreenState();
}

class _CountriesScreenState extends State<CountriesScreen> {
  bool _isLoading = true;
  List<Country> _countries = [];
  String? _errorMessage;
  final ApiProvider _apiProvider = ApiProvider();

  // Önbelleğe alınmış görsellerin ImageProvider'larını saklayacak map
  final Map<String, ImageProvider> _cachedImageProviders = {};

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final response = await _apiProvider.getCountries();

    if (mounted) {
      setState(() {
        if (response.success && response.data != null) {
          _countries = response.data!;
          _isLoading = false;
          _errorMessage = null;

          // Ülke logolarını önbelleğe al
          _precacheCountryImages();
        } else {
          _isLoading = false;
          _errorMessage =
              response.error ??
              AppLocalizations.of(context).errorLoadingCountries;
        }
      });
    }
  }

  // Ülke logolarını önbelleğe al
  Future<void> _precacheCountryImages() async {
    for (final country in _countries) {
      if (country.logoUrl.isNotEmpty) {
        try {
          final imageProvider = await _apiProvider.getImageProvider(
            country.logoUrl,
          );
          _cachedImageProviders[country.logoUrl] = imageProvider;
          if (mounted) {
            setState(() {}); // UI'ı güncelle
          }
        } catch (e) {
          print('Error precaching image for country ${country.name}: $e');
        }
      }
    }
  }

  // URL için ImageProvider al (önbellekten veya ağdan)
  ImageProvider _getImageProvider(String url) {
    // Önbellekte varsa kullan
    if (_cachedImageProviders.containsKey(url)) {
      return _cachedImageProviders[url]!;
    }

    // Yoksa ağdan yükle ve arka planda önbelleğe al
    _apiProvider.getImageProvider(url).then((imageProvider) {
      _cachedImageProviders[url] = imageProvider;
      if (mounted) {
        setState(() {}); // UI'ı güncelle
      }
    });

    // Geçici olarak NetworkImage döndür
    return NetworkImage(url);
  }

  void _onCountrySelected(Country country) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TeamsScreen(countryId: country.id, countryName: country.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).appName,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey[800],
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.all(8.0),
        //     child: CircleAvatar(
        //       backgroundColor: Colors.grey[800],
        //       child: IconButton(
        //         icon: const Icon(Icons.search, color: Colors.white, size: 20),
        //         onPressed: () {},
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage != null
          ? _buildErrorMessage()
          : _buildCountriesList(context),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).loading,
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.primaryColor,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).errorGeneric,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? AppLocalizations.of(context).errorUnknown,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCountries,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).retry,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountriesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Text(
            AppLocalizations.of(context).popularCountries,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Ülkeler listesi
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
              child: ListView.builder(
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onCountrySelected(country),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Bayrak (yuvarlak)
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Image(
                                  image: _getImageProvider(country.logoUrl),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.transparent,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Ülke adı
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.name,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).teamCount(country.teamCount),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Çalma butonu
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
