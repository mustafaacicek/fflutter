import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../models/team.dart';
import '../providers/api_provider.dart';
import '../services/sound_manager.dart';
import '../utils/app_theme.dart';
import 'match_detail_screen.dart';
import '../l10n/app_localizations.dart';

class MatchesScreen extends StatefulWidget {
  final Team team;

  const MatchesScreen({Key? key, required this.team}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<Match> _allMatches = [];
  List<Match> _upcomingMatches = [];
  List<Match> _pastMatches = [];

  // Sound management
  late SoundManager _soundManager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMatches();
    _initSoundManager();
  }

  void _initSoundManager() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    _soundManager = SoundManager(apiProvider: apiProvider);

    // Initialize download status with localized string
    _soundManager.downloadStatus.value = AppLocalizations.of(context).checkingTeamSounds;

    // Önce seçilen takımın ses durumunu kontrol et
    final soundStatus = await _checkSoundsStatus();
    final bool allDownloaded = soundStatus[0] as bool;
    final int total = soundStatus[1] as int;
    final int downloaded = soundStatus[2] as int;
    
    // Eğer tüm sesler indirilmemişse, şık indirme dialogunu göster ve sesleri indir
    if (!allDownloaded && total > 0) {
      // İndirme dialogunu göster
      _showDownloadDialog(total, downloaded);
      
      // Start sound download process with localization context
      await _soundManager.syncTeamSounds(widget.team.id, context: context);
    }

    // Check if team changed and handle sound downloads
    await _soundManager.handleTeamChange(widget.team, context);

    // İndirme durumunu başlat
    if (mounted) {
      setState(() {});
    }

    // Listen for download status changes
    _soundManager.isDownloading.addListener(() {
      if (mounted) {
        setState(() {
          // Update download status with localized string
          if (!_soundManager.isDownloading.value) {
            _soundManager.downloadStatus.value = AppLocalizations.of(context).allSoundsDownloaded;
          }
        });
      }
    });
  }
  
  // Şık indirme dialog'u
  Future<void> _showDownloadDialog(int total, int downloaded) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animasyonlu stadyum ikonu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF5722),
                        Color(0xFFFF9800),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF5722).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.stadium,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 25),
                
                // Başlık
                Text(
                  'MAÇA HAZIRLANIYOR',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Alt başlık
                Text(
                  'Stadyum atmosferi ve taraftar coşkusu yükleniyor...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                
                // İlerleme çubuğu
                ValueListenableBuilder<double>(
                  valueListenable: _soundManager.downloadProgress,
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: MediaQuery.of(context).size.width * progress,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFFF9800),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFF5722).withOpacity(0.5),
                                      blurRadius: 6,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Yükleniyor...',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                
                // Hazır butonu
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF5722),
                        Color(0xFFFF9800),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF5722).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(25),
                      child: Center(
                        child: Text(
                          'HAZIR',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _soundManager.downloadProgress.removeListener(() {});
    _soundManager.isDownloading.removeListener(() {});
    super.dispose();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);

      // Fetch all matches
      final allMatchesResponse = await apiProvider.getMatchesByTeam(
        widget.team.id,
      );
      if (allMatchesResponse.success && allMatchesResponse.data != null) {
        setState(() {
          _allMatches = allMatchesResponse.data!;
        });
      } else {
        setState(() {
          _errorMessage = allMatchesResponse.error ?? 'Failed to load matches';
        });
        return; // Stop if we can't load the main matches
      }

      // Fetch upcoming matches
      final upcomingMatchesResponse = await apiProvider
          .getUpcomingMatchesByTeam(widget.team.id);
      if (upcomingMatchesResponse.success &&
          upcomingMatchesResponse.data != null) {
        setState(() {
          _upcomingMatches = upcomingMatchesResponse.data!;
        });
      }

      // Fetch past matches
      final pastMatchesResponse = await apiProvider.getPastMatchesByTeam(
        widget.team.id,
      );
      if (pastMatchesResponse.success && pastMatchesResponse.data != null) {
        setState(() {
          _pastMatches = pastMatchesResponse.data!;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar:
          false, // AppBar'ın arkasına içerik uzanmasını engelle
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          '${widget.team.name} MAÇLARI',
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
      ),
      body: Column(
        children: [
          // İndirme durumu göstergesi
          _buildDownloadStatusIndicator(),

          // Tab bar
          Container(
            color: AppTheme.backgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.montserrat(),
              tabs: const [
                Tab(text: 'Tümü'),
                Tab(text: 'Gelecek'),
                Tab(text: 'Geçmiş'),
              ],
            ),
          ),

          // Arka plan gradyan
          Container(
            height: 100, // Gradyan yüksekliği
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),

          // İçerik - Expanded ile kalan tüm alanı kaplar
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _errorMessage != null
                ? Center(
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
                          'Bir hata oluştu',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchMatches,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchList(_allMatches),
                      _buildMatchList(_upcomingMatches),
                      _buildMatchList(_pastMatches),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList(List<Match> matches) {
    if (matches.isEmpty) {
      return Center(
        child: Text(
          'Maç bulunamadı',
          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0), // Üstte biraz boşluk ekle
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16), // Alt kısımda padding ekle
        physics: const BouncingScrollPhysics(), // Daha iyi kaydırma efekti
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatchDetailScreen(match: match),
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              color: Colors.grey[900], // Daha koyu kart rengi
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          widget.team.name,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(match.status),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _getStatusText(match.status),
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(match.teamLogo),
                              const SizedBox(height: 8),
                              Text(
                                widget.team.name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            match.getScoreText(),
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(match.getOpponentLogo()),
                              const SizedBox(height: 8),
                              Text(
                                match.getOpponentName(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          match.getFormattedMatchDate(),
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadStatusIndicator() {
    return ValueListenableBuilder<String>(
      valueListenable: _soundManager.downloadStatus,
      builder: (context, status, child) {
        // İndirme tamamlandıysa veya indirme durumu yoksa
        if (!_soundManager.isDownloading.value) {
          // Ses dosyalarının durumunu kontrol et
          return FutureBuilder<List<dynamic>>(
            future: _checkSoundsStatus(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final bool allDownloaded = snapshot.data![0] as bool;
                final int total = snapshot.data![1] as int;
                final int downloaded = snapshot.data![2] as int;

                if (allDownloaded) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    color: Colors.green.shade700,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Maça katılmaya hazırsınız ($downloaded/$total ses)',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Bazı sesler indirilmemiş
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    color: Colors.orange.shade700,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bazı sesler eksik ($downloaded/$total indirildi)',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }

              // Veri yoksa boş göster
              return const SizedBox(height: 0); // Yüksekliği sıfıra indirdim
            },
          );
        }

        // İndirme devam ediyorsa
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: AppTheme.primaryColor.withOpacity(0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: _soundManager.downloadProgress,
                    builder: (context, progress, child) {
                      return Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<double>(
                valueListenable: _soundManager.downloadProgress,
                builder: (context, progress, child) {
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 3, // Biraz daha kalın
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamLogo(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[600]!, width: 2),
        ),
        child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 30),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(
          logoUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Colors.white70,
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }

  // Ses dosyalarının durumunu kontrol et
  Future<List<dynamic>> _checkSoundsStatus() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final sounds = await apiProvider.getStoredSounds(widget.team.id);

    int total = sounds.length;
    int downloaded = 0;

    for (var sound in sounds) {
      if (sound.isDownloaded) {
        downloaded++;
      }
    }

    bool allDownloaded = (total > 0) && (downloaded == total);

    return [allDownloaded, total, downloaded];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PLANNED':
        return Colors.blue;
      case 'PLAYINGS':
        return Colors.green;
      case 'FINISHED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PLANNED':
        return 'PLANLI';
      case 'PLAYINGS':
        return 'OYNANIYOR';
      case 'FINISHED':
        return 'BİTTİ';
      default:
        return status;
    }
  }
}
