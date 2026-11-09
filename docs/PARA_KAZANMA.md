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
| Mağaza | 21 masa ve 21 kart arkası; nadirlik: sıradan (20–45 bin çip) · nadir (50–90 bin çip / 60–100 elmas) · epik (110–220 elmas / 250 bin çip) · efsane (350–400 elmas). Olimpos masa + kart arkası sadece Efsane paketinde, VIP altın masa + VIP taç kart arkası sadece VIP ile. Desenler: masalarda yıldız/damar/baklava/dalga, kart arkalarında puantiye/çizgi/ışın/dalga/meandros |
| Elmas → çip | 10 → 5.000 · 50 → 30.000 · 200 → 150.000 |
| Gerçek para paketleri (önerilen fiyat) | Çip: 4K 0,49 $ · 10K 0,99 $ · 60K 4,99 $ · 150K 9,99 $ · 400K 19,99 $ · 1,2M 49,99 $ · 3M 99,99 $ — Elmas: 50 0,99 $ · 300 4,99 $ · 700 9,99 $ · 1.600 19,99 $ · 4.500 49,99 $ |
| VIP (sunucu açılınca) | 7 gün 2,99 $ (+20 elmas) · 30 gün 9,99 $ (+100 elmas, en avantajlı) · 90 gün 24,99 $ (+350 elmas). Avantajlar: günlük bonus ×2, bedava çip ×2 ve 2 saatte bir, kazanılan oyunda +%20 çip, VIP masa ve kart arkası, altın VIP rozeti |
| Teklif paketleri (sunucu açılınca) | Başlangıç 1,99 $ (25K çip, 50 elmas, Yeşim masa; oyuncu başına bir kez) · Koleksiyoncu 9,99 $ (4 nadir kart arkası, 100 elmas) · Kraliyet 14,99 $ (150K çip, 300 elmas, Yaldızlı oniks masa, Anka kuşu kart arkası) · Efsane 39,99 $ (500K çip, 1.000 elmas, Olimpos masa + kart arkası, 30 gün VIP) |

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
