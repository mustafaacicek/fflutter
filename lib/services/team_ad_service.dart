import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fanlaflutter/models/team_ad.dart';
import 'package:fanlaflutter/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeamAdService {
  final String baseUrl = Constants.apiUrl;
  
  // Önbellek anahtarları
  static const String _teamAdsKey = 'team_ads_';
  static const String _teamAdPositionKey = 'team_ad_position_';
  static const String _lastFetchTimeKey = 'team_ads_last_fetch_';
  static const String _appSessionKey = 'app_session_id';
  
  // Önbellek süresi (24 saat - milisaniye cinsinden)
  static const int _cacheDuration = 24 * 60 * 60 * 1000;
  
  // Uygulama oturum ID'si (her açılışta değişir)
  static String? _currentSessionId;
  
  // Uygulama oturum ID'sini kontrol et ve gerekirse güncelle
  Future<bool> _checkAndUpdateSessionId() async {
    // Eğer oturum ID'si henüz oluşturulmamışsa
    if (_currentSessionId == null) {
      final prefs = await SharedPreferences.getInstance();
      
      // Yeni oturum ID'si oluştur (timestamp kullan)
      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Yeni ID'yi kaydet
      await prefs.setString(_appSessionKey, newSessionId);
      _currentSessionId = newSessionId;
      
      print('New app session started: $newSessionId');
      return true; // Yeni oturum başladı
    }
    
    return false; // Aynı oturum devam ediyor
  }

  /// Belirli bir takımın tüm aktif reklamlarını getirir, önbellek kullanarak
  /// Uygulamanın her açılışında bir kere API'ye istek atar
  Future<List<TeamAd>> getActiveTeamAds(int teamId) async {
    try {
      // Önce uygulama oturum ID'sini kontrol et
      final isNewSession = await _checkAndUpdateSessionId();
      
      // Önbellek kontrolü - sadece yeni oturum değilse önbellekten getir
      if (!isNewSession) {
        final cachedAds = await _getCachedTeamAds(teamId);
        if (cachedAds != null) {
          print('Using cached team ads for team $teamId');
          return cachedAds;
        }
      } else {
        print('New app session detected, fetching fresh ads from API');
      }
      
      // API'den getir (yeni oturum veya önbellekte yok/süresi dolmuş)
      print('Fetching team ads from API for team $teamId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/fan/team-ads/team/$teamId/active'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final ads = data.map((json) => TeamAd.fromJson(json)).toList();
        
        // Önbelleğe kaydet
        await _cacheTeamAds(teamId, ads);
        
        return ads;
      } else {
        print('Error fetching active team ads: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching active team ads: $e');
      return [];
    }
  }

  /// Belirli bir takımın belirli bir pozisyondaki aktif reklamını getirir, önbellek kullanarak
  /// Uygulamanın her açılışında bir kere API'ye istek atar
  /// [forceRefresh] true ise, önbellekteki veriyi kullanmadan doğrudan API'den yeni veri çeker
  Future<TeamAd?> getActiveTeamAdByPosition(int teamId, String position, {bool forceRefresh = false}) async {
    try {
      // Önce uygulama oturum ID'sini kontrol et
      final isNewSession = await _checkAndUpdateSessionId();
      
      // Önbellek kontrolü - sadece yeni oturum değilse ve forceRefresh false ise önbellekten getir
      if (!isNewSession && !forceRefresh) {
        final cachedAd = await _getCachedTeamAdByPosition(teamId, position);
        if (cachedAd != null) {
          print('Using cached team ad for team $teamId and position $position');
          return cachedAd;
        }
      } else if (forceRefresh) {
        print('Force refresh requested, fetching fresh data from API');
      } else {
        print('New app session detected, fetching fresh data from API');
      }
      
      // API'den getir (yeni oturum veya önbellekte yok/süresi dolmuş)
      final url = '$baseUrl/api/fan/team-ads/team/$teamId/active/position/$position';
      print('Fetching ad from URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      );

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        final ad = TeamAd.fromJson(data);
        print('Successfully parsed ad: ${ad.title}, position: ${ad.adPosition}');
        
        // Önbelleğe kaydet
        await _cacheTeamAdByPosition(teamId, position, ad);
        
        return ad;
      } else if (response.statusCode == 404) {
        // Belirtilen pozisyonda aktif reklam bulunamadı
        print('No active ad found for team $teamId and position $position');
        return null;
      } else {
        print('Error fetching active team ad by position: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception fetching active team ad by position: $e');
      return null;
    }
  }
  
  // Önbellek yardımcı metodları
  
  /// Tüm reklamları önbelleğe kaydeder
  Future<void> _cacheTeamAds(int teamId, List<TeamAd> ads) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adsJson = ads.map((ad) => jsonEncode(ad.toJson())).toList();
      await prefs.setStringList(_teamAdsKey + teamId.toString(), adsJson);
      await prefs.setInt(_lastFetchTimeKey + teamId.toString(), DateTime.now().millisecondsSinceEpoch);
      print('Team ads cached for team $teamId');
    } catch (e) {
      print('Error caching team ads: $e');
    }
  }
  
  /// Belirli pozisyondaki reklamı önbelleğe kaydeder
  Future<void> _cacheTeamAdByPosition(int teamId, String position, TeamAd ad) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adJson = jsonEncode(ad.toJson());
      await prefs.setString(_teamAdPositionKey + teamId.toString() + '_' + position, adJson);
      await prefs.setInt(_lastFetchTimeKey + teamId.toString() + '_' + position, 
          DateTime.now().millisecondsSinceEpoch);
      print('Team ad cached for team $teamId and position $position');
    } catch (e) {
      print('Error caching team ad: $e');
    }
  }
  
  /// Önbellekten tüm reklamları getirir, süresi dolmuşsa null döner
  Future<List<TeamAd>?> _getCachedTeamAds(int teamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTime = prefs.getInt(_lastFetchTimeKey + teamId.toString());
      
      // Önbellek süresi kontrolü
      if (lastFetchTime == null || 
          DateTime.now().millisecondsSinceEpoch - lastFetchTime > _cacheDuration) {
        return null; // Önbellek süresi dolmuş veya hiç önbelleklenmemiş
      }
      
      final adsJson = prefs.getStringList(_teamAdsKey + teamId.toString());
      if (adsJson == null || adsJson.isEmpty) {
        return null;
      }
      
      return adsJson
          .map((adJson) => TeamAd.fromJson(jsonDecode(adJson)))
          .toList();
    } catch (e) {
      print('Error getting cached team ads: $e');
      return null;
    }
  }
  
  /// Önbellekten belirli pozisyondaki reklamı getirir, süresi dolmuşsa null döner
  Future<TeamAd?> _getCachedTeamAdByPosition(int teamId, String position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTime = prefs.getInt(_lastFetchTimeKey + teamId.toString() + '_' + position);
      
      // Önbellek süresi kontrolü
      if (lastFetchTime == null || 
          DateTime.now().millisecondsSinceEpoch - lastFetchTime > _cacheDuration) {
        return null; // Önbellek süresi dolmuş veya hiç önbelleklenmemiş
      }
      
      final adJson = prefs.getString(_teamAdPositionKey + teamId.toString() + '_' + position);
      if (adJson == null || adJson.isEmpty) {
        return null;
      }
      
      return TeamAd.fromJson(jsonDecode(adJson));
    } catch (e) {
      print('Error getting cached team ad: $e');
      return null;
    }
  }
}
