import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static const String _subscribedTeamsKey = 'subscribedTeams';
  
  // Test amaçlı bildirim durumunu kontrol et
  static Future<void> checkNotificationStatus() async {
    try {
      print('\n\nBİLDİRİM DURUMU KONTROL EDİLİYOR...');
      
      // FCM token'i al ve logla
      final fcmToken = await _firebaseMessaging.getToken();
      print('MEVCUT FCM TOKEN: $fcmToken');
      
      // Abone olunan takımları al
      final subscribedTeams = await getSubscribedTeamIds();
      print('ABONE OLUNAN TAKIMLAR: $subscribedTeams');
      
      // Bildirim izinlerini kontrol et
      final settings = await _firebaseMessaging.getNotificationSettings();
      print('BİLDİRİM İZİN DURUMU: ${settings.authorizationStatus}');
      
      // Apple Push Notification (APN) token'i al (iOS için)
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      print('APNS TOKEN: $apnsToken');
      
      print('BİLDİRİM DURUMU KONTROLÜ TAMAMLANDI');
    } catch (e) {
      print('BİLDİRİM DURUMU KONTROL HATASI: ${e.toString()}');
    }
  }

  // Takıma abone ol
  static Future<void> subscribeToTeam(Team team) async {
    try {
      // Firebase konsolunda görünen topic formatını kullan
      final String topic = 'team_${team.id}';
      print('TOPIC ABONE OLMA BAŞLANGIÇ: $topic');
      
      // Topic formatını kontrol et ve düzelt
      String formattedTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      
      // Önce mevcut aboneliği kontrol et
      List<int> subscribedTeamIds = await getSubscribedTeamIds();
      bool isAlreadySubscribed = subscribedTeamIds.contains(team.id);
      
      if (isAlreadySubscribed) {
        print('ZATEN ABONE: ${team.name} takımına zaten abone olunmuş');
        // Emin olmak için aboneliği yenile
        await _firebaseMessaging.unsubscribeFromTopic(formattedTopic);
        await _firebaseMessaging.subscribeToTopic(formattedTopic);
        print('ABONE YENİLENDİ: ${team.name} takımına abonelik yenilendi');
      } else {
        // Yeni abonelik ekle
        await _firebaseMessaging.subscribeToTopic(formattedTopic);
        await _saveSubscribedTeam(team.id);
        print('YENİ ABONE: ${team.name} takımına abone olundu');
      }
      
      // FCM token'ı logla
      final fcmToken = await _firebaseMessaging.getToken();
      print('TOPIC: $formattedTopic');
      print('FCM TOKEN: $fcmToken');
      
      // Tüm abone olunan takımları logla
      List<int> allSubscribedTeams = await getSubscribedTeamIds();
      print('TÜM ABONE OLUNAN TAKIMLAR: $allSubscribedTeams');
    } catch (e) {
      print('ABONE OLMA HATASI: ${e.toString()}');
    }
  }

  // Takım aboneliğini kaldır
  static Future<void> unsubscribeFromTeam(Team team) async {
    try {
      // Firebase konsolunda görünen topic formatını kullan
      
      // Topic formatını kontrol et ve düzelt
      String formattedTopic = 'team_${team.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      
      // Önce mevcut aboneliği kontrol et
      List<int> subscribedTeamIds = await getSubscribedTeamIds();
      bool isSubscribed = subscribedTeamIds.contains(team.id);
      
      if (isSubscribed) {
        // Aboneliği kaldır
        await _firebaseMessaging.unsubscribeFromTopic(formattedTopic);
        await _removeSubscribedTeam(team.id);
        print('ABONELIK KALDIRMA BAŞARILI: ${team.name} takımının aboneliği kaldırıldı');
      } else {
        print('ABONELIK YOK: ${team.name} takımına zaten abone değilsiniz');
      }
      
      print('TOPIC: $formattedTopic');
      
      // Tüm abone olunan takımları logla
      List<int> allSubscribedTeams = await getSubscribedTeamIds();
      print('KALAN ABONE OLUNAN TAKIMLAR: $allSubscribedTeams');
    } catch (e) {
      print('ABONELIK KALDIRMA HATASI: ${e.toString()}');
    }
  }

  // Tüm abone olunan takımları kontrol et ve senkronize et
  static Future<void> syncTeamSubscriptions(List<Team> selectedTeams) async {
    // Önce mevcut abonelikleri al
    final List<int> currentSubscriptions = await getSubscribedTeamIds();
    
    // Yeni seçilen takım ID'lerini al
    final List<int> newSelectedIds = selectedTeams.map((team) => team.id).toList();
    
    // Artık abone olunmayacak takımları bul ve aboneliği kaldır
    for (int teamId in currentSubscriptions) {
      if (!newSelectedIds.contains(teamId)) {
        // Bu takım artık seçili değil, aboneliği kaldır
        final teamToUnsubscribe = Team(
          id: teamId,
          name: 'Unknown', // Sadece ID için kullanılıyor
          logoUrl: '',
          countryId: 0,
          countryName: '',
          isActive: true,
        );
        await unsubscribeFromTeam(teamToUnsubscribe);
      }
    }
    
    // Yeni seçilen takımlara abone ol
    for (Team team in selectedTeams) {
      if (!currentSubscriptions.contains(team.id)) {
        // Bu yeni bir takım, abone ol
        await subscribeToTeam(team);
      }
    }
    
    // Tüm seçili takımları kaydet
    await _saveAllSubscribedTeams(newSelectedIds);
  }

  // Abone olunan takım ID'lerini al
  static Future<List<int>> getSubscribedTeamIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? teamIdsStr = prefs.getStringList(_subscribedTeamsKey);
    
    if (teamIdsStr == null || teamIdsStr.isEmpty) {
      return [];
    }
    
    return teamIdsStr.map((idStr) => int.parse(idStr)).toList();
  }

  // Takım ID'sini kaydet
  static Future<void> _saveSubscribedTeam(int teamId) async {
    final List<int> currentIds = await getSubscribedTeamIds();
    
    if (!currentIds.contains(teamId)) {
      currentIds.add(teamId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _subscribedTeamsKey, 
        currentIds.map((id) => id.toString()).toList()
      );
    }
  }

  // Tüm takım ID'lerini kaydet
  static Future<void> _saveAllSubscribedTeams(List<int> teamIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _subscribedTeamsKey, 
      teamIds.map((id) => id.toString()).toList()
    );
  }

  // Takım ID'sini kaldır
  static Future<void> _removeSubscribedTeam(int teamId) async {
    final List<int> currentIds = await getSubscribedTeamIds();
    
    if (currentIds.contains(teamId)) {
      currentIds.remove(teamId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _subscribedTeamsKey, 
        currentIds.map((id) => id.toString()).toList()
      );
    }
  }

  // Uygulama başladığında önceden abone olunan takımlara tekrar abone ol
  static Future<void> restoreTeamSubscriptions() async {
    try {
      print('TAKIMLARIN ABONELİKLERİ YENİDEN YÜKLENİYOR...');
      final List<int> subscribedTeamIds = await getSubscribedTeamIds();
      
      if (subscribedTeamIds.isEmpty) {
        print('ABONE OLUNAN TAKIM BULUNAMADI');
        return;
      }
      
      print('ABONE OLUNAN TAKIMLAR: $subscribedTeamIds');
      
      // Önce tüm abonelikleri temizle ve yeniden oluştur
      // Bu, abonelik sorunlarını çözmek için önemli
      for (int teamId in subscribedTeamIds) {
        final String topic = 'team_$teamId';
        String formattedTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
        
        // Önce aboneliği kaldır
        try {
          await _firebaseMessaging.unsubscribeFromTopic(formattedTopic);
          print('TOPIC ABONELİĞİ SIFIRLANDI: $formattedTopic');
        } catch (e) {
          print('TOPIC ABONELİĞİ SIFIRLAMA HATASI: $e');
        }
      }
      
      // Biraz bekle
      await Future.delayed(Duration(milliseconds: 500));
      
      // FCM token'ı al ve logla
      final fcmToken = await _firebaseMessaging.getToken();
      print('MEVCUT FCM TOKEN: $fcmToken');
      
      // Abonelikleri yeniden oluştur
      for (int teamId in subscribedTeamIds) {
        final String topic = 'team_$teamId';
        String formattedTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
        
        // Yeniden abone ol
        await _firebaseMessaging.subscribeToTopic(formattedTopic);
        print('TOPIC YENİDEN ABONE OLUNDU: $formattedTopic (Takım ID: $teamId)');
      }
      
      print('TÜM TAKIMLARIN ABONELİKLERİ YENİDEN YÜKLENDİ');
    } catch (e) {
      print('ABONELİKLERİ YENİDEN YÜKLEME HATASI: ${e.toString()}');
    }
  }
}
