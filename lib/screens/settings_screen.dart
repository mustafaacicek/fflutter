import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import 'team_notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ayarlar', // Sabit değer kullanıldı
          style: TextStyle(
            color: AppTheme.textColorOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: IconThemeData(color: AppTheme.textColorOnPrimary),
      ),
      body: ListView(
        children: [
          // Dil Ayarları
          _buildSectionHeader(localizations.languageSettings),
          _buildLanguageSelector(languageProvider, localizations),
          
          const Divider(height: 32),
          
          // Bildirim Ayarları
          _buildSectionHeader('Bildirim Ayarları'), // Sabit değer kullanıldı
          _buildSettingsItem(
            icon: Icons.sports_soccer,
            title: 'Takım Bildirimleri',
            subtitle: 'Hangi takımların bildirimlerini almak istediğinizi seçin',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeamNotificationsScreen(),
                ),
              );
            },
          ),
          
          const Divider(height: 32),
          
          // Uygulama Hakkında
          _buildSectionHeader('Uygulama Hakkında'), // Sabit değer kullanıldı
          // Bildirim Test Butonu
          _buildSettingsItem(
            icon: Icons.notifications_active,
            title: 'Bildirim Durumunu Test Et',
            subtitle: 'Bildirim aboneliklerini ve FCM durumunu kontrol et',
            onTap: () async {
              // Bildirim durumunu kontrol et
              await NotificationService.checkNotificationStatus();
              
              // Kullanıcıya bilgi ver
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim durumu kontrol edildi. Logları kontrol edin.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'Uygulama Hakkında', // Sabit değer kullanıldı
            subtitle: 'Fanla v1.0.0',
            onTap: () {
              // Uygulama hakkında bilgi göster
              showAboutDialog(
                context: context,
                applicationName: 'Fanla',
                applicationVersion: 'v1.0.0',
                applicationLegalese: ' 2025 Fanla',
                children: [
                  const Text(
                    'Fanla, taraftarların maçları daha interaktif bir şekilde deneyimlemesini sağlayan bir uygulamadır.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    LanguageProvider languageProvider,
    AppLocalizations localizations,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.selectLanguage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                isExpanded: true,
                value: languageProvider.currentLanguage,
                items: languageProvider.supportedLocales.map((locale) {
                  final String languageName = locale.languageCode == 'tr'
                      ? 'Türkçe'
                      : locale.languageCode == 'en'
                          ? 'English'
                          : locale.languageCode;
                  return DropdownMenuItem<String>(
                    value: locale.languageCode,
                    child: Text(languageName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    languageProvider.changeLanguage(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
