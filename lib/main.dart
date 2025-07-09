import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'utils/notification_helper.dart';
import 'services/notification_service.dart';
import 'screens/welcome_screen.dart';
import 'utils/app_theme.dart';
import 'config/environment.dart';
import 'providers/api_provider.dart';
import 'providers/language_provider.dart';
import 'l10n/app_localizations.dart';

// Firebase için arka plan mesaj işleyici
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background messages
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka plan mesajı alındı: ${message.messageId}");
}

void main() async {
  // Flutter widget binding'i başlat
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlatmayı dene
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase başarıyla başlatıldı");
    
    // Firebase Messaging için arka plan işleyiciyi ayarla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Bildirim yardımcısını başlat
    await NotificationHelper.initialize();
    
    // Önceden abone olunan takımların aboneliklerini geri yükle
    await NotificationService.restoreTeamSubscriptions();
    print("Takım abonelikleri geri yüklendi");
  } catch (e) {
    print("Firebase başlatma hatası: $e");
    // Hata olsa bile uygulamanın çalışmaya devam etmesini sağla
  }
  
  // Set the environment based on your needs
  // Options: Environment.dev, Environment.mobile, Environment.prod, Environment.mock
  EnvironmentConfig.setEnvironment(Environment.mobile);
  
  // Dil sağlayıcısını oluştur
  final languageProvider = LanguageProvider();
  // Kaydedilmiş dil ayarını yükle
  await languageProvider.loadSavedLanguage();

  // Enable network debugging
  // This will print network requests in the console
  // FlutterError.onError = (FlutterErrorDetails details) {
  //   FlutterError.dumpErrorToConsole(details);
  // };

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiProvider>(create: (_) => ApiProvider()),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Bildirim izni kontrolünü biraz geciktirerek yap
    Future.delayed(const Duration(seconds: 2), () {
      NotificationHelper.checkNotificationPermission(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dil sağlayıcısını al
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return MaterialApp(
      title: 'Fanla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Varsayılan olarak koyu tema kullan
      
      // Localization ayarları
      locale: Locale(languageProvider.currentLanguage),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: languageProvider.supportedLocales,
      
      home: const WelcomeScreen(),
    );
  }
}
