#!/bin/bash

# Firebase plugin'ini downgrade et
cd "$(dirname "$0")"
echo "Firebase Messaging plugin'ini downgrade ediyorum..."

# pubspec.yaml dosyasını düzenle
sed -i 's/firebase_messaging: ^14.9.4/firebase_messaging: ^14.6.0/g' pubspec.yaml
sed -i 's/firebase_core: ^2.24.2/firebase_core: ^2.15.0/g' pubspec.yaml

# Bağımlılıkları güncelle
flutter pub get

echo "Firebase plugin'leri downgrade edildi."
