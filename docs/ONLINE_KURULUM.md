# Online mod — Firebase kurulumu

Online oyun Firebase **Realtime Database** + **Anonymous Auth** kullanır (ücretsiz Spark plan, kredi kartı gerekmez).
Oda kurucusu oyunu yönetir; misafirler sadece hamle gönderir ve kendi görebildikleri durumu alır.

## 1. Firebase projesi
1. https://console.firebase.google.com → **Add project** (ör. `pastra-online`). Analytics gerekmez.
2. **Build → Authentication → Get started → Sign-in method → Anonymous → Enable**.
3. **Build → Realtime Database → Create database** (konum: **United States `us-central1`** — europe-west1 bölgesinde veritabanı hiç yanıt vermedi, us-central1 sorunsuz çalıştı; **locked mode** ile başla).
4. Realtime Database → **Rules** sekmesine repodaki `database.rules.json` dosyasının içeriğini yapıştır → **Publish**.

## 2. Uygulamayı projeye bağla (Mac'te, proje klasöründe)
```bash
flutter pub add firebase_core firebase_auth firebase_database
dart pub global activate flutterfire_cli
npm install -g firebase-tools      # yoksa: brew install node
firebase login
flutterfire configure              # projeyi seç; android + web (+ ios) işaretle
flutter pub get
```
`flutterfire configure`, `lib/firebase_options.dart` dosyasını gerçek değerlerle **üzerine yazar**
(şu anki dosya sadece yer tutucu). Realtime Database'i 3. adımda önceden oluşturduğun için `databaseURL` de dosyaya yazılır.

## 3. Web için GitHub Pages
`flutterfire configure` web uygulamasını da kaydeder, ek ayar gerekmez. Authentication → Settings → **Authorized domains**
listesine `aliali2155.github.io` ekle.

## 4. Deneme
Mac'te `flutter run -d chrome` → **Play online → 1v1** → kodu not al.
İkinci pencerede (gizli sekme veya telefon) **Join** ile kodu gir.

## Bilinen sınırlar (v1)
- Kurucu oyundan çıkarsa oyun biter (misafirlere "kurucu ayrıldı" görünür).
- Kurucu oyunu yönettiği için teknik olarak hile yapabilir (arkadaş oyunları için yeterli).
- Eski odalar veritabanında kalır; Realtime Database konsolundan `rooms` düğümünü ara sıra silebilirsin.
- Açık masalar listesi ve hızlı eşleşme `lobby` düğümünü kullanır. Kurallar dosyası güncellendi:
  `firebase deploy --only database` ile (ya da konsolda Rules sekmesine yapıştırarak) yeniden yayınla.
- Saatli online turnuvalar `cups` düğümünü kullanır (kayıtlar, sonuçlar, kimin ekranda olduğu). Maç odaları `rooms` altında `c...r0m1` gibi isimlerle açılır.
- Sıralama tablosu `leaderboard` düğümünü kullanır (aynı `database.rules.json` dosyasında, `xp` alanı indeksli).
  Herkes sadece kendi satırını yazabilir. Ayarlardan kapatılırsa satır silinir.
  Kurallar yayınlanmazsa odalar yine çalışır, sadece listede görünmez ve hızlı eşleşme masa açıp bekler.
