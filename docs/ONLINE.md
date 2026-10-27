# Online mod — sonraki aşama planı

İlk sürüm tamamen çevrimdışı (bilgisayara karşı 1v1 ve 2v2). Kod, online'ı eklerken yeniden
yazmak gerekmeyecek şekilde ayrıldı.

## Şimdiden hazır olanlar

| Parça | Nerede | Online'da ne işe yarar |
|---|---|---|
| Saf Dart oyun motoru (Flutter'a bağımlı değil) | `lib/engine/` | Sunucuda aynen çalışır; kuralları sunucu uygular, hile yapılamaz |
| Tam serileştirilebilir durum | `GameState.toJson / fromJson` | Durum ağ üzerinden gönderilir, oyun kaldığı yerden devam eder |
| Hamle = tek kart id'si | `PastraEngine.applyMove(state, card)` | İstemci sadece `{"type":"play","card":17}` gönderir; ne alınacağını motor hesaplar |
| Oyuncuya özel görünüm | `GameState.redactedFor(seat)` | Her istemciye yalnızca kendi eli gider; rakip eli ve deste `-1` |
| Koltuk türü | `SeatKind.remote` (`lib/game/seats.dart`) | Uzak oyuncular için ayrılmış |

## Önerilen mimari

```
Flutter istemci  ──WebSocket──►  Dart sunucu (shelf + web_socket_channel)
                                   ├─ oda / eşleştirme (4 haneli oda kodu)
                                   ├─ lib/engine'i paket olarak kullanır
                                   └─ her hamleden sonra redactedFor(seat) yayınlar
```

1. `lib/engine/` klasörünü `packages/pastra_engine` adlı ayrı bir Dart paketine taşı
   (uygulama `path:` bağımlılığıyla kullanır, sunucu da aynısını).
2. `server/` altında küçük bir Dart sunucusu: oda oluştur / katıl, koltuk ata, sırayı ve süreyi
   denetle, `applyMove` + `needsDeal` / `roundCardsExhausted` adımlarını sunucuda yürüt.
3. İstemcide `GameController`'a bir `GameTransport` arayüzü ekle: yerel oyunda motoru doğrudan
   çağırır, online'da hamleyi sunucuya yollar ve gelen durumu ekrana basar. Animasyonlar aynı
   kalır çünkü ekran zaten yalnızca durumdan çiziliyor (`TableLayout`).
4. Kopan bağlantı: oyuncu bir jetonla aynı koltuğa geri bağlanır; bu sürede yerine bot oynayabilir
   (`SeatKind.bot`).
5. Barındırma: Dart sunucusu Fly.io / Render / küçük bir VPS üzerinde çalışabilir. Firebase de
   olur ama motoru JavaScript'e çevirmek gerekir; motoru paylaşmak için Dart sunucu daha mantıklı.

## Mesaj taslağı

```json
// istemci → sunucu
{"type": "join", "room": "4821", "name": "Ali"}
{"type": "play", "card": 17}

// sunucu → istemci
{"type": "state", "seat": 0, "state": { ...GameState.redactedFor(0).toJson()... },
 "last": {"seat": 1, "card": 30, "captured": [4, 17], "pastra": 0}}
```
