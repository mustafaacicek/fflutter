import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../models/team.dart';
import '../providers/api_provider.dart';
import '../services/sound_manager.dart';
import '../utils/app_theme.dart';
import 'match_detail_new_screen.dart';
import '../l10n/app_localizations.dart';

class MatchesScreen extends StatefulWidget {
  final Team team;

  const MatchesScreen({super.key, required this.team});

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
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSoundManager();
  }

  void _initSoundManager() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    _soundManager = SoundManager(apiProvider: apiProvider);

    // Ses indirme durumunu başlat
    _soundManager.downloadStatus.value = AppLocalizations.of(
      context,
    ).checkingTeamSounds;

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
          // İndirme durumunu güncelle
          if (!_soundManager.isDownloading.value) {
            _soundManager.downloadStatus.value = AppLocalizations.of(
              context,
            ).allSoundsDownloaded;
          }
        });
      }
    });
  }

  // Timer'ları takip etmek için liste
  final List<Timer> _activeTimers = [];
  
  @override
  void dispose() {
    _tabController.dispose();
    _soundManager.downloadProgress.removeListener(() {});
    _soundManager.isDownloading.removeListener(() {});
    
    // Tüm aktif Timer'ları iptal et
    for (var timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    
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
          _errorMessage =
              allMatchesResponse.error ??
              AppLocalizations.of(context).errorLoadingMatches;
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
          '${widget.team.name} ${AppLocalizations.of(context).matches}',
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
              tabs: [
                Tab(text: AppLocalizations.of(context).allMatches),
                Tab(text: AppLocalizations.of(context).upcomingMatches),
                Tab(text: AppLocalizations.of(context).pastMatches),
              ],
            ),
          ),

          // Arka plan gradyan - yüksekliği sıfıra indirdim
          Container(
            height: 0, // Gradyan yüksekliği sıfır
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
                    physics: const BouncingScrollPhysics(),
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
      padding: const EdgeInsets.only(top: 8.0),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final Match match = matches[index];
          return GestureDetector(
            onTap: () async {
              // Ses dosyalarının durumunu kontrol et
              final soundStatus = await _checkSoundsStatus();
              final bool allDownloaded = soundStatus[0] as bool;

              if (!allDownloaded) {
                // Tüm ses dosyaları indirilmemişse uyarı göster
                if (mounted) {
                  // Dialog gösterilmeden önce periyodik kontrol için timer başlat
                  Timer.periodic(Duration(seconds: 1), (timer) async {
                    // Timer'ı aktif timer listesine ekle
                    _activeTimers.add(timer);
                    // Widget unmount edildiyse timer'ı durdur
                    if (!mounted) {
                      timer.cancel();
                      return;
                    }
                    
                    // Ses durumunu kontrol et
                    final currentStatus = await _checkSoundsStatus();
                    final bool nowAllDownloaded = currentStatus[0] as bool;

                    // Eğer tüm sesler indirildiyse
                    if (nowAllDownloaded && mounted) {
                      // Timer'ı durdur
                      timer.cancel();

                      // Dialog'u kapat
                      Navigator.of(context).pop();

                      // Takım bilgilerini al ve maç detay sayfasına git
                      final apiProvider = Provider.of<ApiProvider>(
                        context,
                        listen: false,
                      );
                      apiProvider.getTeams().then((teamsResponse) {
                        if (teamsResponse.success &&
                            teamsResponse.data != null) {
                          Team? matchTeam;
                          for (var team in teamsResponse.data!) {
                            if (team.id == match.teamId) {
                              matchTeam = team;
                              break;
                            }
                          }

                          if (matchTeam != null) {
                            match.team = matchTeam;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MatchDetailNewScreen(match: match),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Takım bilgileri bulunamadı.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Takım bilgileri alınamadı.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      });
                    }
                  });

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 24,
                        ),
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
                              AppLocalizations.of(context).matchPreparingTitle,
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
                              AppLocalizations.of(
                                context,
                              ).matchPreparingSubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Yükleniyor animasyonu
                            Container(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF5722),
                                ),
                                strokeWidth: 5,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Hazır butonu
                            // Container(
                            //   width: double.infinity,
                            //   height: 50,
                            //   decoration: BoxDecoration(
                            //     gradient: LinearGradient(
                            //       colors: [
                            //         Color(0xFFFF5722),
                            //         Color(0xFFFF9800),
                            //       ],
                            //       begin: Alignment.centerLeft,
                            //       end: Alignment.centerRight,
                            //     ),
                            //     borderRadius: BorderRadius.circular(25),
                            //     boxShadow: [
                            //       BoxShadow(
                            //         color: Color(0xFFFF5722).withOpacity(0.3),
                            //         blurRadius: 10,
                            //         spreadRadius: 0,
                            //         offset: Offset(0, 4),
                            //       ),
                            //     ],
                            //   ),
                            //   child: Material(
                            //     color: Colors.transparent,
                            //     child: InkWell(
                            //       onTap: () {
                            //         Navigator.of(context).pop();

                            //         // Takım bilgilerini al ve maç nesnesine ekle
                            //         final apiProvider = Provider.of<ApiProvider>(
                            //           context,
                            //           listen: false,
                            //         );
                            //         apiProvider.getTeams().then((teamsResponse) {
                            //           if (teamsResponse.success && teamsResponse.data != null) {
                            //             // Maçın takımını bul
                            //             Team? matchTeam;
                            //             for (var team in teamsResponse.data!) {
                            //               if (team.id == match.teamId) {
                            //                 matchTeam = team;
                            //                 break;
                            //               }
                            //             }

                            //             if (matchTeam != null) {
                            //               // Takım bilgilerini maç nesnesine ekle
                            //               match.team = matchTeam;

                            //               // Maç detay sayfasına git
                            //               Navigator.push(
                            //                 context,
                            //                 MaterialPageRoute(
                            //                   builder: (context) =>
                            //                       MatchDetailNewScreen(match: match),
                            //                 ),
                            //               );
                            //             } else {
                            //               ScaffoldMessenger.of(context).showSnackBar(
                            //                 SnackBar(
                            //                   content: Text(AppLocalizations.of(context).teamInfoNotFound),
                            //                   backgroundColor: Colors.red,
                            //                 ),
                            //               );
                            //             }
                            //           } else {
                            //             ScaffoldMessenger.of(context).showSnackBar(
                            //               SnackBar(
                            //                 content: Text('Takım bilgileri alınamadı.'),
                            //                 backgroundColor: Colors.red,
                            //               ),
                            //             );
                            //           }
                            //         });
                            //       },
                            //       borderRadius: BorderRadius.circular(25),
                            //       child: Center(
                            //         child: Text(
                            //           AppLocalizations.of(context).joinStadium,
                            //           style: GoogleFonts.montserrat(
                            //             fontSize: 16,
                            //             fontWeight: FontWeight.w700,
                            //             color: Colors.white,
                            //           ),
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              } else {
                // Tüm sesler indirilmişse başarı popup'ı göster
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 24,
                        ),
                        width: 320,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Başarı ikonu
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green, Color(0xFF4CAF50)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 25),

                            // Başlık
                            Text(
                              AppLocalizations.of(context).matchReadyTitle,
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
                              AppLocalizations.of(context).matchReadySubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  // 2 saniye sonra popup'ı kapat ve maç detay sayfasına git
                  Future.delayed(Duration(seconds: 1), () {
                    Navigator.of(context).pop(); // Popup'ı kapat

                    // Takım bilgilerini al ve maç nesnesine ekle
                    final apiProvider = Provider.of<ApiProvider>(
                      context,
                      listen: false,
                    );
                    apiProvider.getTeams().then((teamsResponse) {
                      if (teamsResponse.success && teamsResponse.data != null) {
                        // Maçın takımını bul
                        Team? matchTeam;
                        for (var team in teamsResponse.data!) {
                          if (team.id == match.teamId) {
                            matchTeam = team;
                            break;
                          }
                        }

                        if (matchTeam != null) {
                          // Takım bilgilerini maç nesnesine ekle
                          match.team = matchTeam;

                          // Maç detay sayfasına git
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MatchDetailNewScreen(match: match),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Takım bilgileri bulunamadı.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Takım bilgileri alınamadı.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    });
                  });
                }
              }
            },
            child: Card(
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
                          match.teamName,
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
                                match.teamName,
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
                            // match.getScoreText(),
                            "vs",
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
                        // Text(
                        //   AppLocalizations.of(
                        //     context,
                        //   ).readyToJoinMatch(downloaded, total),
                        //   style: GoogleFonts.montserrat(
                        //     color: Colors.white,
                        //     fontWeight: FontWeight.bold,
                        //     fontSize: 12,
                        //   ),
                        // ),
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
                          AppLocalizations.of(
                            context,
                          ).someSoundsMissing(downloaded, total),
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
                  // NaN değerini önlemek için kontrol ekliyoruz
                  final safeProgress = progress.isNaN || progress.isInfinite
                      ? 0.0
                      : progress;
                  return LinearProgressIndicator(
                    value: safeProgress,
                    backgroundColor: Colors.white.withAlpha(77),
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
          border: Border.all(color: Colors.grey[600]!, width: 2),
        ),
        child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 30),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Image.network(
        logoUrl,
        width: 60,
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: const Icon(
              Icons.sports_soccer,
              color: Colors.white70,
              size: 30,
            ),
          );
        },
      ),
    );
  }

  // Ses dosyalarının durumunu kontrol et
  Future<List<dynamic>> _checkSoundsStatus() async {
    if (!mounted) return [false, 0, 0]; // Widget unmount edildiyse boş sonuç döndür
    
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
      case 'PLAYING':
        return Colors.green;
      case 'FINISHED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    final BuildContext context = this.context;
    switch (status) {
      case 'PLANNED':
        return AppLocalizations.of(context).matchStatusPlanned;
      case 'PLAYING':
        return AppLocalizations.of(context).matchStatusPlaying;
      case 'FINISHED':
        return AppLocalizations.of(context).matchStatusFinished;
      default:
        return status;
    }
  }
}
