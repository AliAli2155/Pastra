# Pastra çip ekonomisi ve para kazanma

Bu belge oyundaki çip/elmas sistemini ve gerçek parayla satışı açmak için gereken adımları anlatır.

## Diğer oyunlarda nasıl?

Okey Plus, Çanak Okey, 101 Okey ve Pişti gibi uygulamalar aynı modeli kullanır:

- **Çip** ana oyun parasıdır. Günlük giriş bonusu, bedava çip, arkadaş daveti ve reklam izleyerek
  kazanılır; paketler halinde satılır (Okey Plus'ta 0,49 $ ile 99,99 $ arası paketler var).
- **Salonlar / masa bahsi:** oyuncu kendi seviyesindeki salona girer ya da kendi bahsini koyar.
- **VIP / bilet / çark** gibi ek satışlar, **turnuvalar** (giriş ücreti + ödül) ve sezonluk temalar.
- **Ödül merkezi:** reklam izleyerek çip.
- Önemli kural: çipler **paraya çevrilemez**. Google Play kurallarına göre para karşılığı ya da
  parayla alınmış oyun parasıyla, gerçek değeri olan bir ödül için oynatmak kumar sayılır ve izin
  gerektirir. Bu yüzden çip bozdurma ve oyuncular arası çip gönderme (karaborsa yaratır) yoktur.

## Pastra'daki sistem (bu sürüm)

| Ne | Değer |
| --- | --- |
| Başlangıç | 2.500 çip, 10 elmas |
| Salonlar | Dostluk 0 · Çaylak 100 · Amatör 500 (sv. 3) · Profesyonel 2.500 (sv. 6) · Usta 10.000 (sv. 10) · VIP 50.000 (sv. 15) |
| Masa | Oyun başlayınca herkes girişi öder; her kazanan 2 × giriş − %10 masa ücreti alır (Çaylak: 100 öde, 180 al). Bahisli masada botlar her zaman "zor" oynar. |
| Günlük bonus | 500 · 750 · 1.000 · 1.500 · 2.000 · 3.000 · 5.000 (+5 elmas) — gün kaçırılırsa 1. güne döner |
| Bedava çip | 3 saatte bir 300 (100'ün altına düşen oyuncuya 1.000) |
| Seviye atlama | 250 × yeni seviye çip + 3 elmas |
| Offline galibiyet | kolay 20 · orta 40 · zor 80 çip |
| Turnuvalar | Hızlı 200, Klasik/Takım 500 giriş; 1 galibiyet = giriş geri, final = 2×, şampiyon = 4× |
| Mağaza | Okyanus masa 40.000 çip · Kraliyet masa 80 elmas · Gün batımı masa 120 elmas · Zümrüt kart arkası 25.000 çip · Yakut 60 elmas · Elmas 100 elmas |
| Elmas → çip | 10 → 5.000 · 50 → 30.000 · 200 → 150.000 |
| Gerçek para paketleri (önerilen fiyat) | Çip: 10K 0,99 $ · 60K 4,99 $ · 150K 9,99 $ · 400K 19,99 $ — Elmas: 50 0,99 $ · 300 4,99 $ · 700 9,99 $ |

Bütün sayılar `lib/game/economy.dart` içinde; değiştirmek için sadece orayı düzenlemek yeterli.

Masa ücreti ve turnuva girişleri çipleri oyundan çeker; bu, çiplerin değerini korur ve oyuncuyu
bonusa/mağazaya döndürür (para kazandıran döngü budur).

## Şu anki sınırlar

1. **Bakiye cihazda tutuluyor** (shared_preferences). Bilgisi olan biri bakiyesini değiştirebilir.
   Gerçek para satışından önce bakiye sunucuya taşınmalı: Firebase **Blaze** planı + **Cloud
   Functions** (satın alma doğrulama, masa sonunda potu dağıtma, günlük bonusu verme). Kurallar
   (`database.rules.json`) bakiyeyi istemcinin yazmasına izin vermemeli.
2. **Satın alma butonları "yakında" diyor.** Web'de mağaza ödemesi yok; Android/iOS uygulaması
   gerekiyor.

## Gerçek parayla satışı açmak için adımlar

1. **Google Play Console** hesabı (tek sefer 25 $) ve/veya **Apple Developer Program** (yıllık 99 $).
   İkisinde de ödeme profili / vergi ve banka bilgileri girilir; Türkiye'den bireysel hesapla
   satış yapılabilir. Mağazalar satıştan %15 (ilk 1 milyon $) / %30 komisyon alır.
2. Mağazalarda ürünleri oluştur (tüketilebilir ürün): `chips_small`, `chips_medium`,
   `chips_large`, `chips_huge`, `diamonds_small`, `diamonds_medium`, `diamonds_large`
   (kimlikler `Economy.chipPacks` / `Economy.diamondPacks` ile aynı).
3. Uygulamaya `in_app_purchase` paketini ekle; mağaza ekranındaki "yakında" mesajını gerçek satın
   almayla değiştir (fiyatı mağazadan gelen yerel fiyatla göster).
4. Satın alma makbuzunu **Cloud Function** ile doğrula, çipi sunucuda ekle.
5. İsteğe bağlı: **AdMob** ödüllü reklam ("video izle, +300 çip") ve geçiş reklamları. Web için
   AdSense oyun içi reklama uygun değil; mobil sürümde AdMob kullanılır.
6. Mağaza beyanları: yaş derecelendirmesinde "simüle kumar" sorusuna doğru cevap ver (çip bahsi
   olan kart oyunları genelde 12+/17+ alır), gizlilik politikası sayfası ekle.

> Not: Ben avukat değilim; satışa başlamadan önce Türkiye'deki vergi (şahıs şirketi / serbest
> meslek) ve tüketici kurallarını bir mali müşavirle konuşmanı öneririm.
