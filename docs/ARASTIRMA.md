# Pastra (Πάστρα) — araştırma özeti

## Oyunun adı ve kökeni

- Yunancada **πάστρα** "temizlik" demek (*παστρεύω* = temizlemek). Kart oyununda masayı tek hamlede
  boşaltmaya da "πάστρα" denir.
- Yunanca sözlük tanımı: *"πάστρα: κοντσίνα'nın bir varyantı; vale (βαλές) masadaki bütün açık kartları
  toplar."* Yani Pastra, **Κοντσίνα / Κολτσίνα** (toplamalı "balık tutma" oyunu) ile aynı temele sahip,
  farkı valenin masayı süpürmesi.
- Kıbrıs'ta aynı oyun "Ππάστρα" diye oynanıyor ve puanlaması Arap/Levant **Basra** oyunuyla birebir aynı:
  As 1, Vale 1, 2 sinek 2, 10 karo 3, en çok kart 3.
- Türkçe sözlüklerde "pastra" pişti ile eşleştiriliyor. Pişti ve Yunan **Ξερή** *tek yığın* oyunları
  (üst üste atılan kartlar). Uygulamanın varsayılanı artık bu tek yığın oyunu (aşağıda); toplamalı
  Kıbrıs Pastrası ayarlardan seçilebiliyor.

Kart adları (Yunanca): Κούπα ♥ (kupa), Καρό ♦ (karo), **Σπαθί ♣ (sinek)**, **Μπαστούνι ♠ (maça)**;
Άσσος (as), Βαλές (vale), Ντάμα (kız), Ρήγας (papaz). "Καλό δυάρι" = 2 σπαθί (2♣),
"καλό δεκάρι" = 10 καρό (10♦).

## Varsayılan oyun: Στοίβα (Yunan Ξερή usulü)

Kaynak: Pagat "Xeri (Ξερή)" ve GameRules "4 player Xeri".

1. Destenin en alt kartı (**kapak altı**) açık olarak destenin altında kalır; son dağıtımda dağıtana
   (başlayanın bir önceki oyuncusu) gider. Her oyuncuya **6 kart**. Ortaya **4 kart** açılır, en
   sağdaki en üstteki kart sayılır; oraya vale gelirse kapak altına gider ve yerine yeni kart açılır
   (Ali'nin anlattığı yerel kural; Pagat'ta bunun yerine yeniden dağıtım var).
2. Atılan kart en üstteki kartla **aynı değerdeyse** ya da **vale** ise bütün yığını alır; değilse
   yığının üstüne kapanır. Toplama yoktur.
3. **Ξερή (pastra):** yığında tek kart varken onu aynı değerde kartla almak **10 puan**; valeyle tek
   valeyi almak **20 puan** (varyant: 25). Valeyle tek başka kartı almak ξερή sayılmaz (varyant: sayılır).
   Turun en son kartı pastra sayılmaz (Pagat'taki "no xeri with dealer's last card" varyantı).
4. Eller bitince 6'şar kart yeniden dağıtılır; tur sonunda yığında kalanlar son alan tarafa gider.
5. Puan: en çok kart 3 (26–26'da kimse), her A, K, Q, J, 10 için 1 (toplam 20), 10♦ +1, 2♣ 1
   → tur başına 25 puan + ξερές. Hedef **151** (eşitlikte 251'e kadar uzar).
6. Uygulamada açılıştaki 4 kart yan yana açılır (en sağdaki en üstteki kart), ilk kart atılınca tek
   yığına toplanır; altta kalan kartlar ekranda boş (yüzü görünmeyen) kart olarak çizilir. Botlar da sadece bir oyuncunun
   görebileceği kartları bilir (oynanan her kartı hatırlarlar).

Simülasyon (TypeScript kopyası, 2 kişilik / 4 kişilik): zor bot ortayı %64 / %60, kolayı %98 / %99
oranında yeniyor; oyun ortalama 6 turda 151'e ulaşıyor, turda ~1,5 ξερή çıkıyor.

## Diğer seçenek: Αθροίσματα (Kıbrıs usulü toplamalı pastra)

### Toplamalı oyunun kuralları

1. 52 kartlık deste, joker yok. 2 oyuncu (1v1) ya da 4 oyuncu (2v2, karşılıklı oturan eşler kartlarını
   birleştirir).
2. Her oyuncuya 4 kart (ayarlardan 6), masaya 4 açık kart, yan yana. Masaya vale gelirse desteye
   gömülür, yerine yeni kart açılır.
3. Sırası gelen tek kart atar:
   - **Sayı kartı (A=1 … 10):** masadaki aynı değerdeki kartları ve toplamı o değeri tutan sayı kartı
     gruplarını alır (ör. 8 ile 8, 5+3 ve 6+A+A aynı anda). Alabiliyorsa almak zorunludur ve alabileceği
     en fazla kartı alır.
   - **Kız / Papaz:** yalnızca aynı resmi alır (Q→Q, K→K); toplamaya girmez.
   - **Vale:** masadaki bütün kartları toplar. Boş masaya atılırsa masada kalır.
   - Hiçbir şey alamayan kart masada açık kalır.
4. **Pastra:** vale dışında bir kartla masayı tamamen boşaltmak = **10 puan**.
   Vale ile tek kalmış valeyi almak varsayılanda 10 puan (ayarlardan 0 / 10 / 20).
5. Eller bitince desteden yeniden dağıtılır, masaya kart açılmaz. Deste bitince masada kalan kartlar
   son alan oyuncuya gider (bu pastra sayılmaz).
6. Tur puanı: en çok kart 3 (26-26 eşitlikte kimse almaz), her As 1, her Vale 1, 2♣ 2, 10♦ 3 →
   toplam 16 + pastralar.
7. 101 puana ilk ulaşan kazanır (ayarlardan 51 / 151). İki taraf aynı turda geçip eşitse bir tur daha
   oynanır. Her tur dağıtan değişir.

Ayarlanabilir: hedef puan, dağıtım (4/6 kart), vale süpürmesi pastra sayılsın mı, vale-vale puanı,
son kartla pastra geçerli mi.

## Kaynaklar

- [Pagat — Kontsina](https://www.pagat.com/fishing/kontsina.html)
- [Pagat — Xeri](https://pagat.com/fishing/xeri.html)
- [GameRules — 4 player Xeri](https://gamerules.com/rules/4-player-xeri/)
- [Farsharotu — Rules for the card game Xeri](https://farsharotu.org/rules-for-the-card-game-xeri/)
- [Pagat — Basra](https://www.pagat.com/fishing/basra.html)
- [Wikipedia — Bastra](https://en.wikipedia.org/wiki/Bastra)
- [ΠΑΙΧΝΙΔΙΑ ΜΕ ΤΡΑΠΟΥΛΑ — Κολτσίνα (Κολιτσίνα - Κοντσίνα - Πάστρα)](https://cardgamesgr.blogspot.com/2014/04/blog-post.html) (Kıbrıs yorumu dahil)
- [Ρεμπέτικο Φόρουμ — "πάστρα" maddesi tartışması](https://rembetiko.gr/t/%CF%83%CF%85%CE%B6%CE%AE%CF%84%CE%B7%CF%83%CE%B7-%CE%B3%CE%B9%CE%B1-%CF%84%CE%BF-%CE%BB%CE%AE%CE%BC%CE%BC%CE%B1-%CF%80%CE%AC%CF%83%CF%84%CF%81%CE%B1/49523)
- [Kamini.gr — "πάστρα" kelimesinin anlamı](https://www.kamini.gr/lexi-pastra/)
- [ipy.gr — Κολλιτσίνα](https://ipy.gr/2018/10/11/%CE%BA%CE%BF%CE%BB%CE%B9%CF%84%CF%83%CE%AF%CE%BD%CE%B1/)
- [Gambiter — Yunan kart oyunları](https://gambiter.com/cards/national/greece.html)
