// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'FANLA';

  @override
  String get welcomeTitle => 'Taraftar Deneyimini Yeniden Keşfet';

  @override
  String get welcomeSubtitle =>
      'Maçları takip et, takımının tezahüratlarını dinle ve taraftar deneyimini bir üst seviyeye taşı.';

  @override
  String get startButton => 'BAŞLAT';

  @override
  String get languageSettings => 'Dil Ayarları';

  @override
  String get selectLanguage => 'Dil Seçin';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'İngilizce';

  @override
  String get languageSpanish => 'İspanyolca';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get errorGeneric => 'Bir hata oluştu';

  @override
  String get errorUnknown => 'Bilinmeyen bir hata oluştu';

  @override
  String get errorLoadingCountries => 'Ülkeler yüklenirken hata oluştu';

  @override
  String get errorLoadingTeams => 'Takımlar yüklenirken hata oluştu';

  @override
  String get errorLoadingMatches => 'Maçlar yüklenirken hata oluştu';

  @override
  String get noInternetConnection => 'İnternet bağlantısı yok';

  @override
  String get searchHint => 'Ara...';

  @override
  String get popularCountries => 'Popüler Ülkeler';

  @override
  String get popularTeams => 'Popüler Takımlar';

  @override
  String get featuredTeams => 'Öne Çıkan Takımlar';

  @override
  String get explore => 'KEŞFET';

  @override
  String get matches => 'MAÇLARI';

  @override
  String teamCount(int count) {
    return '$count Takım';
  }

  @override
  String get allMatches => 'Tüm Maçlar';

  @override
  String get upcomingMatches => 'Gelecek';

  @override
  String get pastMatches => 'Geçmiş';

  @override
  String get matchStatusPlanned => 'PLANLI';

  @override
  String get matchStatusPlaying => 'OYNANMAKTA';

  @override
  String get matchStatusFinished => 'TAMAMLANDI';

  @override
  String get lyricsActive => 'Şarkı Sözleri Aktif';

  @override
  String get webSocketConnected => 'WebSocket Bağlı';

  @override
  String get webSocketDisconnected => 'WebSocket Bağlantısı Kesildi';

  @override
  String get checkingTeamSounds => 'Takım verileri kontrol ediliyor...';

  @override
  String get allSoundsDownloaded => 'Tüm veriler indirildi';

  @override
  String downloadingSound(int progress) {
    return 'Veriler indiriliyor: %$progress';
  }

  @override
  String readyToJoinMatch(int downloaded, int total) {
    return 'Maça katılmaya hazırsınız ($downloaded/$total veri)';
  }

  @override
  String someSoundsMissing(int downloaded, int total) {
    return 'Bazı veriler eksik ($downloaded/$total indirildi)';
  }

  @override
  String get downloadingSoundsTitle => 'Veri Dosyaları İndiriliyor';

  @override
  String get matchDetailSoundsNeeded =>
      'Maç detaylarına erişebilmek için tüm veri dosyalarının indirilmesi gerekiyor.';

  @override
  String soundFilesDownloaded(int downloaded, int total) {
    return '$downloaded/$total veri dosyası indirildi';
  }

  @override
  String get ok => 'Tamam';

  @override
  String get stadiumNotAvailable => 'Stadyum bilgisi mevcut değil';

  @override
  String get matchPreparingTitle => 'MAÇA HAZIRLANIYOR';

  @override
  String get matchPreparingSubtitle =>
      'Stadyum atmosferi ve taraftar coşkusu yükleniyor...';

  @override
  String get matchReadyTitle => 'MAÇA HAZIRSINIZ';

  @override
  String get matchReadySubtitle => 'Tribüne Katılıyorsunuz!';

  @override
  String get joinStadium => 'TAMAM';

  @override
  String get teamInfoNotFound => 'Takım bilgileri bulunamadı.';

  @override
  String get advertisement => 'Reklam';

  @override
  String get websiteUrl => 'fanla.net';

  @override
  String get privacyNotice =>
      'Fanla hiçbir kişisel veri toplamaz veya saklamaz.';

  @override
  String get firstTeamSelectionTitle => 'Takım Seçimi';

  @override
  String get firstTeamSelectionMessage =>
      'Bu takıma ücretsiz abone olacaksınız. Takım değiştirmek isterseniz, 5 dakika beklemeniz gerekecektir.';

  @override
  String get firstTeamSelectionContinue => 'Devam Et';

  @override
  String get firstTeamSelectionCancel => 'İptal';

  @override
  String get preparing => 'Hazırlanıyor...';

  @override
  String downloadingLyrics(Object title) {
    return 'Şarkı sözleri indiriliyor: $title';
  }

  @override
  String get downloadingSpecificData => 'Belirli veriler indiriliyor...';
}
