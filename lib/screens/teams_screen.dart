import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import 'dart:ui';
import '../providers/api_provider.dart';
import '../models/team.dart';
import '../services/sound_manager.dart';
import '../services/notification_service.dart';
import 'matches_screen.dart';
import '../l10n/app_localizations.dart';

class TeamsScreen extends StatefulWidget {
  final int countryId;
  final String countryName;

  const TeamsScreen({
    Key? key,
    required this.countryId,
    required this.countryName,
  }) : super(key: key);

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  bool _isLoading = true;
  List<Team> _teams = [];
  String? _errorMessage;

  // Önbelleğe alınmış görsellerin ImageProvider'larını saklayacak map
  final Map<String, ImageProvider> _cachedImageProviders = {};

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final response = await apiProvider.getTeamsByCountry(widget.countryId);

    if (mounted) {
      setState(() {
        if (response.success && response.data != null) {
          _teams = response.data!;
          _isLoading = false;
          _errorMessage = null;

          // Takım logolarını önbelleğe al
          _precacheTeamImages(apiProvider);
        } else {
          _isLoading = false;
          _errorMessage =
              response.error ?? AppLocalizations.of(context).errorLoadingTeams;
        }
      });
    }
  }

  // Takım logolarını önbelleğe al
  Future<void> _precacheTeamImages(ApiProvider apiProvider) async {
    for (final team in _teams) {
      if (team.logoUrl.isNotEmpty) {
        try {
          final imageProvider = await apiProvider.getImageProvider(
            team.logoUrl,
          );
          _cachedImageProviders[team.logoUrl] = imageProvider;
          if (mounted) {
            setState(() {}); // UI'ı güncelle
          }
        } catch (e) {
          print('Error precaching image for team ${team.name}: $e');
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
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    apiProvider.getImageProvider(url).then((imageProvider) {
      _cachedImageProviders[url] = imageProvider;
      if (mounted) {
        setState(() {}); // UI'ı güncelle
      }
    });

    // Geçici olarak NetworkImage döndür
    return NetworkImage(url);
  }

  void _onTeamSelected(Team team) async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final soundManager = SoundManager(apiProvider: apiProvider);
    
    // Kullanıcının daha önce bir takım seçip seçmediğini kontrol et
    final int? currentTeamId = await apiProvider.getCurrentTeamId();
    
    if (currentTeamId == null) {
      // İlk takım seçimi - bilgilendirme dialogu göster
      final bool shouldContinue = await _showFirstTeamSelectionDialog(context, team);
      if (!shouldContinue) {
        return; // Kullanıcı iptal ettiyse işlemi sonlandır
      }
    }
    
    // Önce takıma zaten abone olunup olunmadığını kontrol et
    final List<int> subscribedTeamIds = await NotificationService.getSubscribedTeamIds();
    final bool isAlreadySubscribed = subscribedTeamIds.contains(team.id);
  
    // Eğer zaten abone olunmamışsa, bildirim izni sor
    bool shouldSubscribe = false;
  
    if (!isAlreadySubscribed) {
      // Takım bildirimlerine abone olmak isteyip istemediğini sor
      shouldSubscribe = await _showNotificationSubscriptionDialog(context, team);
      
      if (shouldSubscribe) {
        // Seçilen takıma bildirim aboneliği ekle
        await NotificationService.subscribeToTeam(team);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${team.name} takımının bildirimlerini almaya başladınız'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        print("${team.name} takımına bildirim aboneliği eklendi");
      }
    } else {
      print("${team.name} takımına zaten abone olunmuş, bildirim izni sorulmadı");
    }
    
    // Maçlar ekranına git
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MatchesScreen(team: team)),
    );

    // Takım değişikliğini yönet
    soundManager.handleTeamChange(team, context);
  }
  
  // Bildirim aboneliği için dialog
  Future<bool> _showNotificationSubscriptionDialog(BuildContext context, Team team) async {
    bool result = false;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: Text(
            'Takım Bildirimleri',
            style: GoogleFonts.montserrat(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${team.name} takımının maç bildirimleri, haberler ve diğer güncellemeler hakkında bildirim almak ister misiniz?',
                style: GoogleFonts.montserrat(
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(team.logoUrl),
                    backgroundColor: Colors.transparent,
                    radius: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Bildirimleri istediğiniz zaman ayarlar menüsünden değiştirebilirsiniz.',
                      style: GoogleFonts.montserrat(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false;
                Navigator.of(context).pop();
              },
              child: Text(
                'Hayır',
                style: GoogleFonts.montserrat(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () {
                result = true;
                Navigator.of(context).pop();
              },
              child: Text(
                'Evet, Bildirim Al',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    return result;
  }
  
  // İlk takım seçimi için bilgilendirme dialogu
  Future<bool> _showFirstTeamSelectionDialog(BuildContext context, Team team) async {
    final localizations = AppLocalizations.of(context);
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withBlue(220),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Takım logosu
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: team.logoUrl.isNotEmpty
                      ? Image.network(
                          team.logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              alignment: Alignment.center,
                              child: Text(
                                team.name.isNotEmpty ? team.name[0] : '?',
                                style: GoogleFonts.montserrat(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          alignment: Alignment.center,
                          child: Text(
                            team.name.isNotEmpty ? team.name[0] : '?',
                            style: GoogleFonts.montserrat(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                
                // Başlık
                Text(
                  localizations.firstTeamSelectionTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Takım adı
                Text(
                  team.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Bilgilendirme mesajı
                Text(
                  localizations.firstTeamSelectionMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // İptal butonu
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: Text(
                          localizations.firstTeamSelectionCancel,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Devam butonu
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: Text(
                          localizations.firstTeamSelectionContinue,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false; // Dialog kapatılırsa false döndür
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.countryName.toUpperCase(),
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
      body: Stack(
        children: [
          // Arka plan gradyan
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),
          // İçerik
          _isLoading
              ? _buildLoadingIndicator()
              : _errorMessage != null
              ? _buildErrorMessage()
              : _buildTeamsList(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
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
            onPressed: _loadTeams,
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

  Widget _buildTeamsList() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Popüler takımlar başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              AppLocalizations.of(context).popularTeams ?? 'Popüler takımlar',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Popüler takımlar yatay listesi
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _teams.length,
              itemBuilder: (context, index) {
                final team = _teams[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onTeamSelected(team),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          // Takım logosu
                          SizedBox(
                            width: 100,
                            height: 180,
                            child: Image(
                              image: _getImageProvider(team.logoUrl),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.transparent,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Takım bilgileri
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    team.name,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    team.stadiumName ?? 'Stadyum bilgisi yok',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context).explore ??
                                          'KEŞFET',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Öne çıkan takımlar başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              AppLocalizations.of(context).featuredTeams ??
                  'Öne çıkan takımlar',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Öne çıkan takımlar listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              itemCount: _teams.length,
              itemBuilder: (context, index) {
                final team = _teams[index];
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
                      onTap: () => _onTeamSelected(team),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Takım logosu
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
                                image: _getImageProvider(team.logoUrl),
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
                            // Takım adı
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team.name,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    team.stadiumName ?? 'Stadyum bilgisi yok',
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
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  FutureBuilder<List<dynamic>>(
                                    future: Future.wait([
                                      Provider.of<ApiProvider>(
                                        context,
                                        listen: false,
                                      ).getCurrentTeamId(),
                                      Provider.of<ApiProvider>(
                                        context,
                                        listen: false,
                                      ).getStoredSounds(team.id),
                                    ]),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final currentTeamId =
                                            snapshot.data![0] as int?;
                                        final sounds =
                                            snapshot.data![1] as List;

                                        // Eğer bu takım seçiliyse ve sesleri indirilmişse, indikator göster
                                        if (currentTeamId == team.id &&
                                            sounds.isNotEmpty) {
                                          return Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
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
        ],
      ),
    );
  }
}
