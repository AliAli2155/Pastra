# Generates lib/l10n/social_strings.dart (invites, friends, quick chat,
# rematch, name prompt, training, hints, game review, highlights) in 12 languages.
import re, sys
T = {}
T['en'] = """
shareInvite=Share invite
copyLink=Copy link
linkCopied=Link copied
inviteText=Play Pastra with me! Room {code}: {link}
inviteFriends=Invite friends
friends=Friends
friendsHint=People you played online with
favorites=Favourites
recent=Recently played
noFriends=Play online: the people you meet show up here. Star them to keep them as friends.
inviteSent=Invite sent to {name}
invitedYou={name} invites you to a table
join=Join
invite=Invite
today=Today
yesterday=Yesterday
daysAgo={n} days ago
gamesTogether={n} games together
quickChat=Quick chat
msg_hi=Hi!
msg_gl=Good luck!
msg_nice=Nice hand!
msg_wow=Wow!
msg_hurry=Hurry up!
msg_oops=Oops!
msg_thanks=Thanks!
msg_gg=Good game!
rematch=Rematch
rematchWait=Waiting for the host…
rematchVotes=Rematch ({n} want)
rematchReady=A rematch table is ready
yourName=What's your name?
nameHint=Your name at the table
nameWhy=Other players and the leaderboard will see it.
save=Save
later=Later
training=Training
trainingHint=Learn step by step against an easy computer, with hints
hint=Hint
hintText=Tip: the glowing card is a good play
analysis=Game review
noMisses=Great game: no missed chances!
missedPastra=Pastra with {card} (+{n})
missedCapture={card} would have taken {n} cards
playedInstead=You played {card}
missedCount={n} missed chances
highlights=Highlights
favTable=Favourite table
bestGamePastras=Most pastras in a game
"""
T['tr'] = """
shareInvite=Daveti paylaş
copyLink=Linki kopyala
linkCopied=Link kopyalandı
inviteText=Benimle Pastra oyna! Oda {code}: {link}
inviteFriends=Arkadaş davet et
friends=Arkadaşlar
friendsHint=Online oynadığın kişiler
favorites=Favoriler
recent=Son oynadıkların
noFriends=Online oyna: tanıştığın oyuncular burada çıkar. Yıldızla, arkadaş olarak kalsınlar.
inviteSent={name} davet edildi
invitedYou={name} seni masaya davet ediyor
join=Katıl
invite=Davet et
today=Bugün
yesterday=Dün
daysAgo={n} gün önce
gamesTogether=Birlikte {n} oyun
quickChat=Hızlı mesaj
msg_hi=Selam!
msg_gl=Bol şans!
msg_nice=Güzel el!
msg_wow=Vay be!
msg_hurry=Acele et!
msg_oops=Eyvah!
msg_thanks=Teşekkürler!
msg_gg=İyi oyundu!
rematch=Rövanş
rematchWait=Oda sahibi bekleniyor…
rematchVotes=Rövanş ({n} istiyor)
rematchReady=Rövanş masası hazır
yourName=Adın ne?
nameHint=Masadaki adın
nameWhy=Diğer oyuncular ve sıralama bu adı görür.
save=Kaydet
later=Sonra
training=Eğitim
trainingHint=Kolay bilgisayara karşı adım adım öğren, ipuçlarıyla
hint=İpucu
hintText=İpucu: parlayan kart iyi bir hamle
analysis=Oyun analizi
noMisses=Harika oyun: kaçırılan fırsat yok!
missedPastra={card} ile pastra (+{n})
missedCapture={card} ile {n} kart alabilirdin
playedInstead={card} oynadın
missedCount={n} kaçırılan fırsat
highlights=Öne çıkanlar
favTable=Favori masa
bestGamePastras=Bir oyunda en çok pastra
"""
T['el'] = """
shareInvite=Κοινοποίηση πρόσκλησης
copyLink=Αντιγραφή συνδέσμου
linkCopied=Ο σύνδεσμος αντιγράφηκε
inviteText=Παίξε Πάστρα μαζί μου! Δωμάτιο {code}: {link}
inviteFriends=Πρόσκληση φίλων
friends=Φίλοι
friendsHint=Άτομα με τα οποία έπαιξες online
favorites=Αγαπημένοι
recent=Πρόσφατα παιχνίδια
noFriends=Παίξε online: όσοι γνωρίσεις εμφανίζονται εδώ. Βάλε αστέρι για να τους κρατήσεις ως φίλους.
inviteSent=Στάλθηκε πρόσκληση στον/στην {name}
invitedYou=Ο/Η {name} σε καλεί σε τραπέζι
join=Συμμετοχή
invite=Πρόσκληση
today=Σήμερα
yesterday=Χθες
daysAgo=Πριν από {n} μέρες
gamesTogether={n} παιχνίδια μαζί
quickChat=Γρήγορο μήνυμα
msg_hi=Γεια!
msg_gl=Καλή τύχη!
msg_nice=Ωραίο χέρι!
msg_wow=Ουάου!
msg_hurry=Βιάσου!
msg_oops=Ωχ!
msg_thanks=Ευχαριστώ!
msg_gg=Καλό παιχνίδι!
rematch=Ρεβάνς
rematchWait=Αναμονή για τον οικοδεσπότη…
rematchVotes=Ρεβάνς ({n} θέλουν)
rematchReady=Το τραπέζι της ρεβάνς είναι έτοιμο
yourName=Πώς σε λένε;
nameHint=Το όνομά σου στο τραπέζι
nameWhy=Θα το βλέπουν οι άλλοι παίκτες και η κατάταξη.
save=Αποθήκευση
later=Αργότερα
training=Εκπαίδευση
trainingHint=Μάθε βήμα βήμα με εύκολο υπολογιστή και συμβουλές
hint=Συμβουλή
hintText=Συμβουλή: το φύλλο που λάμπει είναι καλή κίνηση
analysis=Ανάλυση παιχνιδιού
noMisses=Υπέροχο παιχνίδι: καμία χαμένη ευκαιρία!
missedPastra=Πάστρα με {card} (+{n})
missedCapture=Με {card} θα έπαιρνες {n} φύλλα
playedInstead=Έπαιξες {card}
missedCount={n} χαμένες ευκαιρίες
highlights=Κορυφαία
favTable=Αγαπημένο τραπέζι
bestGamePastras=Περισσότερες πάστρες σε ένα παιχνίδι
"""
T['de'] = """
shareInvite=Einladung teilen
copyLink=Link kopieren
linkCopied=Link kopiert
inviteText=Spiel Pastra mit mir! Raum {code}: {link}
inviteFriends=Freunde einladen
friends=Freunde
friendsHint=Leute, mit denen du online gespielt hast
favorites=Favoriten
recent=Zuletzt gespielt
noFriends=Spiel online: Wen du triffst, erscheint hier. Markiere sie mit einem Stern, um sie als Freunde zu behalten.
inviteSent=Einladung an {name} gesendet
invitedYou={name} lädt dich an einen Tisch ein
join=Beitreten
invite=Einladen
today=Heute
yesterday=Gestern
daysAgo=Vor {n} Tagen
gamesTogether={n} Partien zusammen
quickChat=Schnellnachricht
msg_hi=Hallo!
msg_gl=Viel Glück!
msg_nice=Schöne Hand!
msg_wow=Wow!
msg_hurry=Beeil dich!
msg_oops=Hoppla!
msg_thanks=Danke!
msg_gg=Gutes Spiel!
rematch=Revanche
rematchWait=Warte auf den Gastgeber…
rematchVotes=Revanche ({n} wollen)
rematchReady=Der Revanche-Tisch ist bereit
yourName=Wie heißt du?
nameHint=Dein Name am Tisch
nameWhy=Andere Spieler und die Rangliste sehen ihn.
save=Speichern
later=Später
training=Training
trainingHint=Lerne Schritt für Schritt gegen einen leichten Computer, mit Tipps
hint=Tipp
hintText=Tipp: die leuchtende Karte ist ein guter Zug
analysis=Spielanalyse
noMisses=Super Spiel: keine Chance verpasst!
missedPastra=Pastra mit {card} (+{n})
missedCapture=Mit {card} hättest du {n} Karten genommen
playedInstead=Du hast {card} gespielt
missedCount={n} verpasste Chancen
highlights=Höhepunkte
favTable=Lieblingstisch
bestGamePastras=Meiste Pastras in einer Partie
"""
T['fr'] = """
shareInvite=Partager l'invitation
copyLink=Copier le lien
linkCopied=Lien copié
inviteText=Joue à la Pastra avec moi ! Salle {code} : {link}
inviteFriends=Inviter des amis
friends=Amis
friendsHint=Les joueurs rencontrés en ligne
favorites=Favoris
recent=Joué récemment
noFriends=Joue en ligne : les joueurs rencontrés apparaissent ici. Mets-leur une étoile pour les garder comme amis.
inviteSent=Invitation envoyée à {name}
invitedYou={name} t'invite à une table
join=Rejoindre
invite=Inviter
today=Aujourd'hui
yesterday=Hier
daysAgo=Il y a {n} jours
gamesTogether={n} parties ensemble
quickChat=Message rapide
msg_hi=Salut !
msg_gl=Bonne chance !
msg_nice=Joli coup !
msg_wow=Waouh !
msg_hurry=Dépêche-toi !
msg_oops=Oups !
msg_thanks=Merci !
msg_gg=Bien joué !
rematch=Revanche
rematchWait=En attente de l'hôte…
rematchVotes=Revanche ({n} veulent)
rematchReady=La table de revanche est prête
yourName=Comment t'appelles-tu ?
nameHint=Ton nom à la table
nameWhy=Les autres joueurs et le classement le verront.
save=Enregistrer
later=Plus tard
training=Entraînement
trainingHint=Apprends pas à pas contre un ordinateur facile, avec des conseils
hint=Conseil
hintText=Conseil : la carte qui brille est un bon coup
analysis=Analyse de la partie
noMisses=Super partie : aucune occasion manquée !
missedPastra=Pastra avec {card} (+{n})
missedCapture={card} aurait pris {n} cartes
playedInstead=Tu as joué {card}
missedCount={n} occasions manquées
highlights=Points forts
favTable=Table préférée
bestGamePastras=Plus de pastras en une partie
"""
T['es'] = """
shareInvite=Compartir invitación
copyLink=Copiar enlace
linkCopied=Enlace copiado
inviteText=¡Juega a la Pastra conmigo! Sala {code}: {link}
inviteFriends=Invitar amigos
friends=Amigos
friendsHint=Gente con la que jugaste online
favorites=Favoritos
recent=Jugado recientemente
noFriends=Juega online: la gente que conozcas aparece aquí. Márcalos con una estrella para guardarlos como amigos.
inviteSent=Invitación enviada a {name}
invitedYou={name} te invita a una mesa
join=Unirse
invite=Invitar
today=Hoy
yesterday=Ayer
daysAgo=Hace {n} días
gamesTogether={n} partidas juntos
quickChat=Mensaje rápido
msg_hi=¡Hola!
msg_gl=¡Buena suerte!
msg_nice=¡Buena mano!
msg_wow=¡Guau!
msg_hurry=¡Date prisa!
msg_oops=¡Uy!
msg_thanks=¡Gracias!
msg_gg=¡Buena partida!
rematch=Revancha
rematchWait=Esperando al anfitrión…
rematchVotes=Revancha ({n} quieren)
rematchReady=La mesa de la revancha está lista
yourName=¿Cómo te llamas?
nameHint=Tu nombre en la mesa
nameWhy=Lo verán los demás jugadores y la clasificación.
save=Guardar
later=Más tarde
training=Entrenamiento
trainingHint=Aprende paso a paso contra un ordenador fácil, con pistas
hint=Pista
hintText=Pista: la carta que brilla es una buena jugada
analysis=Análisis de la partida
noMisses=¡Gran partida: ninguna ocasión perdida!
missedPastra=Pastra con {card} (+{n})
missedCapture={card} habría tomado {n} cartas
playedInstead=Jugaste {card}
missedCount={n} ocasiones perdidas
highlights=Lo más destacado
favTable=Mesa favorita
bestGamePastras=Más pastras en una partida
"""
T['it'] = """
shareInvite=Condividi invito
copyLink=Copia link
linkCopied=Link copiato
inviteText=Gioca a Pastra con me! Stanza {code}: {link}
inviteFriends=Invita amici
friends=Amici
friendsHint=Le persone con cui hai giocato online
favorites=Preferiti
recent=Giocato di recente
noFriends=Gioca online: le persone che incontri compaiono qui. Mettile tra i preferiti per tenerle come amici.
inviteSent=Invito inviato a {name}
invitedYou={name} ti invita a un tavolo
join=Entra
invite=Invita
today=Oggi
yesterday=Ieri
daysAgo={n} giorni fa
gamesTogether={n} partite insieme
quickChat=Messaggio rapido
msg_hi=Ciao!
msg_gl=Buona fortuna!
msg_nice=Bella mano!
msg_wow=Wow!
msg_hurry=Sbrigati!
msg_oops=Ops!
msg_thanks=Grazie!
msg_gg=Bella partita!
rematch=Rivincita
rematchWait=In attesa dell'host…
rematchVotes=Rivincita ({n} vogliono)
rematchReady=Il tavolo della rivincita è pronto
yourName=Come ti chiami?
nameHint=Il tuo nome al tavolo
nameWhy=Lo vedranno gli altri giocatori e la classifica.
save=Salva
later=Più tardi
training=Allenamento
trainingHint=Impara passo dopo passo contro un computer facile, con suggerimenti
hint=Suggerimento
hintText=Suggerimento: la carta che brilla è una buona mossa
analysis=Analisi della partita
noMisses=Ottima partita: nessuna occasione persa!
missedPastra=Pastra con {card} (+{n})
missedCapture=Con {card} avresti preso {n} carte
playedInstead=Hai giocato {card}
missedCount={n} occasioni perse
highlights=In evidenza
favTable=Tavolo preferito
bestGamePastras=Più pastre in una partita
"""
T['pt'] = """
shareInvite=Partilhar convite
copyLink=Copiar link
linkCopied=Link copiado
inviteText=Joga Pastra comigo! Sala {code}: {link}
inviteFriends=Convidar amigos
friends=Amigos
friendsHint=Pessoas com quem jogaste online
favorites=Favoritos
recent=Jogado recentemente
noFriends=Joga online: as pessoas que conheceres aparecem aqui. Marca-as com uma estrela para as guardares como amigos.
inviteSent=Convite enviado a {name}
invitedYou={name} convida-te para uma mesa
join=Entrar
invite=Convidar
today=Hoje
yesterday=Ontem
daysAgo=Há {n} dias
gamesTogether={n} jogos juntos
quickChat=Mensagem rápida
msg_hi=Olá!
msg_gl=Boa sorte!
msg_nice=Bela mão!
msg_wow=Uau!
msg_hurry=Despacha-te!
msg_oops=Ups!
msg_thanks=Obrigado!
msg_gg=Bom jogo!
rematch=Desforra
rematchWait=À espera do anfitrião…
rematchVotes=Desforra ({n} querem)
rematchReady=A mesa da desforra está pronta
yourName=Como te chamas?
nameHint=O teu nome na mesa
nameWhy=Os outros jogadores e a classificação vão vê-lo.
save=Guardar
later=Mais tarde
training=Treino
trainingHint=Aprende passo a passo contra um computador fácil, com dicas
hint=Dica
hintText=Dica: a carta que brilha é uma boa jogada
analysis=Análise do jogo
noMisses=Ótimo jogo: nenhuma oportunidade perdida!
missedPastra=Pastra com {card} (+{n})
missedCapture=Com {card} terias levado {n} cartas
playedInstead=Jogaste {card}
missedCount={n} oportunidades perdidas
highlights=Destaques
favTable=Mesa favorita
bestGamePastras=Mais pastras num jogo
"""
T['ru'] = """
shareInvite=Поделиться приглашением
copyLink=Скопировать ссылку
linkCopied=Ссылка скопирована
inviteText=Сыграй со мной в Пастру! Комната {code}: {link}
inviteFriends=Пригласить друзей
friends=Друзья
friendsHint=Те, с кем ты играл онлайн
favorites=Избранные
recent=Недавние игры
noFriends=Играй онлайн: здесь появятся игроки, с которыми ты встретился. Отметь их звёздочкой, чтобы сохранить в друзьях.
inviteSent=Приглашение отправлено: {name}
invitedYou={name} приглашает тебя за стол
join=Войти
invite=Пригласить
today=Сегодня
yesterday=Вчера
daysAgo={n} дн. назад
gamesTogether=Игр вместе: {n}
quickChat=Быстрое сообщение
msg_hi=Привет!
msg_gl=Удачи!
msg_nice=Хороший ход!
msg_wow=Ого!
msg_hurry=Поторопись!
msg_oops=Упс!
msg_thanks=Спасибо!
msg_gg=Хорошая игра!
rematch=Реванш
rematchWait=Ждём хозяина стола…
rematchVotes=Реванш (хотят: {n})
rematchReady=Стол для реванша готов
yourName=Как тебя зовут?
nameHint=Твоё имя за столом
nameWhy=Его увидят другие игроки и рейтинг.
save=Сохранить
later=Позже
training=Обучение
trainingHint=Учись шаг за шагом против лёгкого компьютера, с подсказками
hint=Подсказка
hintText=Подсказка: светящаяся карта — хороший ход
analysis=Разбор партии
noMisses=Отличная игра: ни одного упущенного шанса!
missedPastra=Пастра картой {card} (+{n})
missedCapture=Картой {card} можно было взять {n} карт
playedInstead=Ты сыграл {card}
missedCount=Упущенных шансов: {n}
highlights=Главное
favTable=Любимый стол
bestGamePastras=Больше всего пастр за игру
"""
T['bg'] = """
shareInvite=Сподели поканата
copyLink=Копирай връзката
linkCopied=Връзката е копирана
inviteText=Играй Пастра с мен! Стая {code}: {link}
inviteFriends=Покани приятели
friends=Приятели
friendsHint=Хора, с които си играл онлайн
favorites=Любими
recent=Скорошни игри
noFriends=Играй онлайн: хората, които срещнеш, се появяват тук. Отбележи ги със звезда, за да ги запазиш като приятели.
inviteSent=Поканата е изпратена на {name}
invitedYou={name} те кани на маса
join=Влез
invite=Покани
today=Днес
yesterday=Вчера
daysAgo=Преди {n} дни
gamesTogether={n} игри заедно
quickChat=Бързо съобщение
msg_hi=Здравей!
msg_gl=Успех!
msg_nice=Хубава ръка!
msg_wow=Уау!
msg_hurry=Побързай!
msg_oops=Опа!
msg_thanks=Благодаря!
msg_gg=Добра игра!
rematch=Реванш
rematchWait=Чака се домакинът…
rematchVotes=Реванш ({n} искат)
rematchReady=Масата за реванш е готова
yourName=Как се казваш?
nameHint=Името ти на масата
nameWhy=Ще го виждат другите играчи и класирането.
save=Запази
later=По-късно
training=Обучение
trainingHint=Учи стъпка по стъпка срещу лесен компютър, с подсказки
hint=Подсказка
hintText=Подсказка: светещата карта е добър ход
analysis=Анализ на играта
noMisses=Страхотна игра: нито един пропуснат шанс!
missedPastra=Пастра с {card} (+{n})
missedCapture=С {card} щеше да вземеш {n} карти
playedInstead=Изигра {card}
missedCount={n} пропуснати шанса
highlights=Акценти
favTable=Любима маса
bestGamePastras=Най-много пастри в една игра
"""
T['ar'] = """
shareInvite=مشاركة الدعوة
copyLink=نسخ الرابط
linkCopied=تم نسخ الرابط
inviteText=العب باسترا معي! الغرفة {code}: {link}
inviteFriends=دعوة الأصدقاء
friends=الأصدقاء
friendsHint=أشخاص لعبت معهم عبر الإنترنت
favorites=المفضلون
recent=لعبت معهم مؤخرًا
noFriends=العب عبر الإنترنت: يظهر هنا من تلتقي بهم. ضع نجمة لتحتفظ بهم كأصدقاء.
inviteSent=تم إرسال الدعوة إلى {name}
invitedYou={name} يدعوك إلى طاولة
join=انضم
invite=ادعُ
today=اليوم
yesterday=أمس
daysAgo=قبل {n} أيام
gamesTogether={n} مباريات معًا
quickChat=رسالة سريعة
msg_hi=مرحبًا!
msg_gl=حظًا موفقًا!
msg_nice=يد رائعة!
msg_wow=واو!
msg_hurry=أسرع!
msg_oops=عفوًا!
msg_thanks=شكرًا!
msg_gg=مباراة جيدة!
rematch=إعادة المباراة
rematchWait=بانتظار المضيف…
rematchVotes=إعادة ({n} يريدون)
rematchReady=طاولة الإعادة جاهزة
yourName=ما اسمك؟
nameHint=اسمك على الطاولة
nameWhy=سيراه اللاعبون الآخرون والترتيب.
save=حفظ
later=لاحقًا
training=تدريب
trainingHint=تعلّم خطوة بخطوة ضد كمبيوتر سهل، مع تلميحات
hint=تلميح
hintText=تلميح: الورقة المضيئة حركة جيدة
analysis=تحليل المباراة
noMisses=مباراة رائعة: لا فرص ضائعة!
missedPastra=باسترا بـ {card} (+{n})
missedCapture=كنت ستأخذ {n} أوراق بـ {card}
playedInstead=لعبت {card}
missedCount={n} فرص ضائعة
highlights=أبرز الأرقام
favTable=الطاولة المفضلة
bestGamePastras=أكثر باسترا في مباراة
"""
T['zh'] = """
shareInvite=分享邀请
copyLink=复制链接
linkCopied=链接已复制
inviteText=和我一起玩 Pastra！房间 {code}：{link}
inviteFriends=邀请好友
friends=好友
friendsHint=和你在线玩过的人
favorites=收藏
recent=最近一起玩过
noFriends=在线游戏：遇到的玩家会出现在这里。加星即可保存为好友。
inviteSent=已向 {name} 发送邀请
invitedYou={name} 邀请你入桌
join=加入
invite=邀请
today=今天
yesterday=昨天
daysAgo={n} 天前
gamesTogether=一起玩了 {n} 局
quickChat=快捷消息
msg_hi=你好！
msg_gl=祝你好运！
msg_nice=好牌！
msg_wow=哇！
msg_hurry=快点！
msg_oops=哎呀！
msg_thanks=谢谢！
msg_gg=打得好！
rematch=再来一局
rematchWait=等待房主…
rematchVotes=再来一局（{n} 人想要）
rematchReady=再战的牌桌已准备好
yourName=你叫什么名字？
nameHint=你在牌桌上的名字
nameWhy=其他玩家和排行榜会看到它。
save=保存
later=稍后
training=训练
trainingHint=对战简单电脑，带提示，一步步学习
hint=提示
hintText=提示：发光的牌是好选择
analysis=对局分析
noMisses=打得很棒：没有错过任何机会！
missedPastra=用 {card} 可以打出 Pastra（+{n}）
missedCapture=用 {card} 可以拿走 {n} 张牌
playedInstead=你出了 {card}
missedCount=错过 {n} 次机会
highlights=亮点
favTable=最爱的牌桌
bestGamePastras=单局最多 Pastra
"""
order = ['en','el','tr','de','fr','es','it','pt','ru','bg','ar','zh']
def parse(txt):
    d = {}
    for line in txt.strip().split('\n'):
        k, v = line.split('=', 1)
        d[k.strip()] = v.strip()
    return d
data = {l: parse(T[l]) for l in order}
keys = list(data['en'].keys())
ph = re.compile(r'\{(\w+)\}')
for l in order:
    assert list(data[l].keys()) == keys, (l, set(keys) ^ set(data[l].keys()))
    for k in keys:
        assert set(ph.findall(data[l][k])) == set(ph.findall(data['en'][k])), (l, k)
def q(v):
    return "'" + v.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
out = []
out.append("// Generated by tool/l10n/social.py — edit the texts there.")
out.append("")
out.append("/// Texts of invites, friends, quick chat, rematch, training and the game review.")
out.append("class SocialStrings {")
out.append("  const SocialStrings(this.lang);")
out.append("")
out.append("  final String lang;")
out.append("")
out.append("  /// Quick chat messages (ids); emojis are sent as they are.")
out.append("  static const List<String> messages = <String>['hi', 'gl', 'nice', 'wow', 'hurry', 'oops', 'thanks', 'gg'];")
out.append("  static const List<String> emojis = <String>['👍', '😂', '😮', '😎', '🔥', '😢', '👏', '🤔'];")
out.append("")
out.append("  /// Keys of a language (for the tests: every language has all texts).")
out.append("  static Set<String> keysOf(String lang) => _texts[lang]?.keys.toSet() ?? const <String>{};")
out.append("")
out.append("  String _t(String key, [Map<String, Object> args = const <String, Object>{}]) {")
out.append("    var text = _texts[lang]?[key] ?? _texts['en']![key] ?? key;")
out.append("    args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));")
out.append("    return text;")
out.append("  }")
out.append("")
for k in keys:
    if k.startswith('msg_'):
        continue
    params = ph.findall(data['en'][k])
    if not params:
        out.append(f"  String get {k} => _t('{k}');")
    else:
        sig = ', '.join(f"Object {p}" for p in params)
        args = ', '.join(f"'{p}': {p}" for p in params)
        out.append(f"  String {k}({sig}) => _t('{k}', <String, Object>{{{args}}});")
out.append("")
out.append("  /// A chat message: a message id (`m:<id>`) or an emoji (`e:<emoji>`).")
out.append("  String chat(String raw) {")
out.append("    if (raw.startsWith('m:') && messages.contains(raw.substring(2))) return _t('msg_${raw.substring(2)}');")
out.append("    if (raw.startsWith('e:') && emojis.contains(raw.substring(2))) return raw.substring(2);")
out.append("    return '';")
out.append("  }")
out.append("")
out.append("  /// \"Today\", \"Yesterday\" or \"3 days ago\".")
out.append("  String when(DateTime t, DateTime now) {")
out.append("    final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;")
out.append("    if (days <= 0) return today;")
out.append("    if (days == 1) return yesterday;")
out.append("    return daysAgo(days);")
out.append("  }")
out.append("")
out.append("  static const Map<String, Map<String, String>> _texts = <String, Map<String, String>>{")
for l in order:
    out.append(f"    '{l}': <String, String>{{")
    for k in keys:
        out.append(f"      '{k}': {q(data[l][k])},")
    out.append("    },")
out.append("  };")
out.append("}")
open(sys.argv[1] if len(sys.argv) > 1 else 'lib/l10n/social_strings.dart', 'w').write('\n'.join(out) + '\n')
print(len(keys), 'keys')
