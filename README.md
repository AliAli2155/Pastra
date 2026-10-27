# Πάστρα (Pastra)

Yunanların oynadığı **Pastra** kart oyunu — Flutter ile. Android uygulaması,
iPhone için web sürümü (Safari → Ana Ekrana Ekle). Arayüz Yunanca ve İngilizce.

- Bilgisayara karşı **1v1** ve eşli **2v2** (eşin karşında oturur)
- Üç zorluk: Kolay / Orta / Zor (zor bot Monte Carlo + oyun sonunda tam arama yapar, hile yapmaz:
  sadece bir oyuncunun görebildiği bilgiyi kullanır)
- **Yatay** oynanır (okey / uno uygulamaları gibi); telefonda ekran yan döner, web'de dik tutulan
  telefona "çevir" uyarısı çıkar
- Her hamle için süre (varsayılan 15 sn, Ayarlar'dan 10/15/20/30 ya da kapalı); süre bitince senin
  yerine bir kart oynanır
- Bir takımın aldığı kartlar, o turda takımdan ilk alan oyuncunun önünde durur
- Kartı **sürükleyip ortaya bırakarak** oynarsın (sürüklerken alıp almayacağı parlar); istersen
  dokun-dokun da çalışır
- Pastra efekti, tur sonu puan tablosu, hedef puana kadar oyun
- Oyun her hamlede kaydedilir; uygulama kapansa da "Συνέχεια / Continue" ile devam
- İki oyun: **Στοίβα** (varsayılan, Yunan Ξερή usulü: tek yığın, sadece üstteki kart görünür)
  ve **Αθροίσματα** (Kıbrıs usulü toplamalı pastra)
- Ayarlardan: 51/101/151/251 puan, 4 ya da 6 kart dağıtım, vale-vale puanı, vale tek kartı
  alınca pastra sayılsın mı, son kartla pastra
- Online mod sonraki aşama: [docs/ONLINE.md](docs/ONLINE.md)

Kuralların araştırması ve kaynaklar: [docs/ARASTIRMA.md](docs/ARASTIRMA.md)

## Kurulum (Windows)

1. **Flutter SDK** kur: <https://docs.flutter.dev/get-started/install/windows/mobile>
   (Android Studio ile birlikte; ardından `flutter doctor --android-licenses`).
2. Bu klasörde **`setup.bat`** dosyasını çalıştır. Sırasıyla:
   - `flutter create` → `android/` ve `ios/` klasörlerini oluşturur (mevcut dosyalara dokunmaz)
   - `flutter pub get`
   - `dart run tool/post_create.dart` → uygulama adı (Yunanca telefonda "Πάστρα") ve ikonlar
   - `flutter test`
3. Telefonu USB ile bağla (Geliştirici seçenekleri → USB hata ayıklama) ya da emülatör aç:
   ```
   flutter run
   ```
4. Kurulabilir APK:
   ```
   flutter build apk --release
   ```
   Dosya: `build\app\outputs\flutter-apk\app-release.apk` → telefona kopyalayıp kur.

macOS/Linux için aynı adımlar `setup.sh` ile.

## Windows (.exe)

1. Visual Studio 2022 Community'yi kur, kurulumda **"Desktop development with C++"** bileşenini seç
   (`flutter doctor`'daki Visual Studio satırı ✓ olmalı).
2. Bu klasörde **`windows_exe.bat`** çalıştır: `windows/` klasörünü oluşturur, pencere adı ve ikonu
   ayarlar, derler ve **`Pastra-Windows.zip`** dosyasını hazırlar.
3. Zip'i gönder; karşı taraf bir klasöre çıkarıp `pastra.exe`'yi açar. İmzasız uygulama olduğu için
   Windows "bilgisayarınız korundu" derse **Ek bilgi → Yine de çalıştır**.

## iPhone: web sürümü

Windows'ta iOS uygulaması derlenemediği için iPhone'da oyun web sürümüyle çalışır (aynı kod).
Safari'de açıp **Paylaş → Ana Ekrana Ekle** dersen tam ekran, ikonlu bir uygulama gibi açılır;
kayıtlı oyun ve ayarlar telefonda kalır.

1. **Bilgisayarda dene:** `flutter run -d chrome`
2. **iPhone'da dene (aynı Wi-Fi):** `web_telefon.bat` çalıştır, ekrana yazdığı
   `http://192.168.x.x:8080` adresini iPhone Safari'de aç.
3. **Kalıcı yayın (GitHub Pages, ücretsiz):**
   1. [Git for Windows](https://git-scm.com/download/win) kur (varsayılan ayarlar).
   2. GitHub'da **public** bir `pastra` deposu oluştur (README eklemeden).
   3. Bu klasörde **`web_yayinla.bat`** çalıştır: testleri çalıştırır, Actions ayarını
      `.github/workflows/` içine kopyalar, kaydedip GitHub'a gönderir.
   4. Depoda **Settings → Pages → Source: GitHub Actions** seç, sonra **Actions** sekmesinde
      kırmızı çarpılı ilk çalıştırmayı **Re-run all jobs** ile tekrar çalıştır (Pages açılmadan
      başladığı için ilk sefer hata verir).
   5. 3-4 dakika sonra: <https://aliali2155.github.io/Pastra/>
   Sonraki güncellemelerde sadece `web_yayinla.bat`'ı tekrar çalıştırman yeterli.

Web dosyaları `web/` klasöründe: `index.html` (iPhone çentiği/ana ekran çubuğu için güvenli
alan, telefon dik tutulunca "çevir" uyarısı), `flutter_bootstrap.js`, `manifest.json`, ikonlar.

### Bilgisayara Android Studio kurmadan APK

`tool/ci/android-apk.yml` dosyasını `.github/workflows/` klasörüne kopyala ve projeyi GitHub'a
gönder; her `main` push'unda GitHub APK'yı derler. Actions sekmesindeki çalıştırmanın
**Artifacts** kısmından `pastra-apk` indir.

## Proje yapısı

```
lib/
  engine/            saf Dart oyun mantığı (Flutter'a bağımlı değil → online sunucuda da çalışır)
    cards.dart         kart id'leri (0..51), puan değerleri
    rules.dart         ayarlanabilir kurallar
    game_state.dart    serileştirilebilir oyun durumu, tur sonuçları
    pastra_engine.dart dağıtım, alma (eşleme + toplamlar + vale), pastra, puanlama
    pastra_ai.dart     botlar (kolay / orta / zor)
  game/
    game_controller.dart  akış: sıra, bot hamleleri, dağıtım, kayıt
    app_settings.dart     ayarlar + istatistik + kayıtlı oyun (shared_preferences)
    seats.dart            koltuklar (insan / bot / ileride uzak oyuncu)
  l10n/strings.dart  Yunanca + İngilizce metinler
  ui/
    table_layout.dart  her kartın ekrandaki yeri (her yer değişimi animasyonlu)
    screens/           ana menü, oyun masası, ayarlar, kurallar
    widgets/           kart çizimi (suit şekilleri path ile), tur özeti
web/                 web sürümü (iPhone Safari / ana ekran uygulaması)
test/                motor testleri (alma, pastra, puan, binlerce hamlelik bot oyunları) + widget testleri
tool/post_create.dart  uygulama adı + ikonları platform klasörlerine kopyalar
```

## Kurallar (varsayılan: Στοίβα / Ξερή)

Destenin en alttaki kartı (**kapak altı**) açık olarak destenin altında durur; son dağıtımda
dağıtana gider, herkes onda olduğunu bilir. Her oyuncuya 6 kart dağıtılır. Ortaya 4 kart yan yana
açılır, en sağdaki en üstteki sayılır; oraya vale gelirse kapak altına gider ve yeni kart açılır.
İlk kart atılınca hepsi tek yığına toplanır ve bundan sonra sadece en üstteki görünür (alttakileri
aklında tutman gerekir). Attığın kart en üstteki kartla aynı
değerdeyse ya da valeyse **bütün yığını** alırsın, değilse kartın yığının üstüne kapanır. Tek kartlık
yığını aynı kartla almak **pastra = 10 puan**, valeyle valeyi almak 20 puan. Turun en son kartı
pastra sayılmaz.
Tur puanı: en çok kart 3; her As, Papaz, Kız, Vale, 10 için 1; 10♦ +1 (toplam 2); 2♣ 1
(tur başına 25 puan + pastralar). **151**'e ilk ulaşan kazanır.

Ayarlar → Παραλλαγή'dan Kıbrıs usulü toplamalı oyuna (açık masa, 8 → 5+3 gibi toplamlar,
101 puan) geçilebilir.

## Not

Kod, Flutter SDK'ya erişimi olmayan bir ortamda yazıldı: oyun mantığı aynı algoritmanın
TypeScript kopyasıyla binlerce simüle oyunda test edildi ve Dart dosyaları sözdizimi denetiminden
geçti, ama `flutter analyze` / `flutter run` ilk kez senin bilgisayarında çalışacak. Bir hata
çıkarsa mesajı olduğu gibi gönder, düzeltirim.
