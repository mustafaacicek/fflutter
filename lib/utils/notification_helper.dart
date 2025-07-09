import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationHelper {
  static Future<void> initialize() async {
    try {
      print('BİLDİRİM SERVİSİ BAŞLATILIYOR...');
      
      // Önce mevcut izin durumunu kontrol et
      final initialSettings = await FirebaseMessaging.instance.getNotificationSettings();
      print("MEVCUT BİLDİRİM İZİN DURUMU: ${initialSettings.authorizationStatus}");
      
      // Firebase Messaging izinlerini iste
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true, // Kritik bildirimlere izin ver
        provisional: false,
        sound: true,
      );
      
      print("YENİ BİLDİRİM İZİN DURUMU: ${settings.authorizationStatus}");
      
      // İzin durumunu kontrol et
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("BİLDİRİM İZİNLERİ TAM OLARAK VERİLDİ");
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print("GEÇİCİ BİLDİRİM İZİNLERİ VERİLDİ");
      } else {
        print("BİLDİRİM İZİNLERİ VERİLMEDİ VEYA REDDEDDİLDİ");
      }
      
      // FCM token'i al
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print("FCM TOKEN: $fcmToken");
      
      // Bildirim kanalını ayarla (Android için)
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Ön plan mesajlarını dinle
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("\n\nÖN PLANDA BİLDİRİM ALINDI:");
        print("BAŞLIK: ${message.notification?.title}");
        print("İÇERİK: ${message.notification?.body}");
        print("DATA: ${message.data}");
        
        // Topic bilgisini kontrol et
        if (message.from != null) {
          print("TOPIC/FROM: ${message.from}");
        }
        
        // Burada yerel bildirim gösterebilir veya özel bir diyalog açabilirsiniz
      });
      
      // Uygulama kapalıyken bildirime tıklandığında
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print("\n\nUYGULAMA KAPALIYKEN BİLDİRİME TIKLANDI:");
          print("BAŞLIK: ${message.notification?.title}");
          print("İÇERİK: ${message.notification?.body}");
          print("DATA: ${message.data}");
          
          // Topic bilgisini kontrol et
          if (message.from != null) {
            print("TOPIC/FROM: ${message.from}");
          }
          
          // Burada bildirime özel bir işlem yapabilirsiniz
        }
      });
      
      // Uygulama arka plandayken bildirime tıklandığında
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("\n\nARKA PLANDAYKEN BİLDİRİME TIKLANDI:");
        print("BAŞLIK: ${message.notification?.title}");
        print("İÇERİK: ${message.notification?.body}");
        print("DATA: ${message.data}");
        
        // Topic bilgisini kontrol et
        if (message.from != null) {
          print("TOPIC/FROM: ${message.from}");
        }
        
        // Burada bildirime özel bir işlem yapabilirsiniz
      });
      
      print('BİLDİRİM SERVİSİ BAŞARIYLA BAŞLATILDI');
    } catch (e) {
      print('BİLDİRİM SERVİSİ BAŞLATMA HATASI: ${e.toString()}');
    }
  }
  
  // Test amaçlı bildirim izni kontrolü
  static Future<void> checkNotificationPermission(BuildContext context) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
        settings.authorizationStatus == AuthorizationStatus.denied) {
      // Kullanıcıya bildirim izni vermesi için bir diyalog göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Bildirim İzni'),
          content: const Text(
              'Fanla uygulaması size önemli bildirimler göndermek istiyor. Bildirimlere izin vermek için "İzin Ver" butonuna tıklayın.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                FirebaseMessaging.instance.requestPermission();
              },
              child: const Text('İzin Ver'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Daha Sonra'),
            ),
          ],
        ),
      );
    }
  }
}
