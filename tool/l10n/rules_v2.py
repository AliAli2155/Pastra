# Rules sections rewritten with the house scoring: 10 of diamonds 3, every ace 1,
# every jack 1, 2 of clubs 2, most cards 3 (16 points a round plus pastras),
# the kapak altı (a jack there never lies alone) and the four-of-a-kind void deal.
# gen.py puts these into section 2 (Dealing) and section 6 (Points) of both games.

T = {}

T['en'] = dict(
    deal6='Each player gets 6 cards (or 4, see settings).',
    kapak='Kapak altı: the bottom card of the deck is turned face up and stays under the deck for the whole round. It is the last card dealt, so the dealer gets it and everybody knows it.',
    jackalone='A jack never lies there alone: if the kapak altı is a jack, the next card is turned face up next to it (and one more if that is a jack too).',
    opening='Four cards are opened side by side in the middle; the rightmost one is the top card. A jack may not open on top: it goes face up under the deck and another card is opened.',
    quad='Four of a kind in one hand (e.g. four aces): the deal is void, the cards are shown to everybody and the same dealer deals again.',
    gather='When the first card is played, the four opening cards are gathered into one pile; from then on only the top card shows. When the hands are empty new cards are dealt; no more cards go to the pile.',
    deal4='Each player gets 4 cards (or 6, see settings) and 4 cards are laid face up on the table.',
    jackback='A jack turned up for the table goes back into the deck and is replaced.',
    nomore='When the hands are empty new cards are dealt; no more cards go to the table.',
    ten='10 of diamonds: 3', ace='Each ace: 1', jack='Each jack: 1', two='2 of clubs: 2',
    most='Most cards: 3 (nobody on a 26–26 tie)',
    pastra_pile='Each pastra: 10 · jack on a lone jack: 20', pastra_sums='Each pastra: 10',
    total='Every round is worth 16 points plus the pastras.',
)

T['el'] = dict(
    deal6='Κάθε παίκτης παίρνει 6 φύλλα (ή 4, από τις ρυθμίσεις).',
    kapak='Kapak altı: το κάτω φύλλο της τράπουλας γυρίζει ανοιχτό και μένει κάτω από την τράπουλα όλο τον γύρο. Είναι το τελευταίο φύλλο που μοιράζεται, άρα το παίρνει αυτός που μοιράζει και όλοι το ξέρουν.',
    jackalone='Ο βαλές δεν μένει ποτέ μόνος εκεί: αν το kapak altı είναι βαλές, ανοίγει και το επόμενο φύλλο δίπλα του (κι άλλο ένα, αν βγει πάλι βαλές).',
    opening='Τέσσερα φύλλα ανοίγουν στη μέση δίπλα-δίπλα· το δεξί είναι το πάνω φύλλο. Πάνω δεν μπορεί να ανοίξει βαλές: μπαίνει ανοιχτός κάτω από την τράπουλα και ανοίγει άλλο φύλλο.',
    quad='Τέσσερα ίδια φύλλα σε ένα χέρι (π.χ. τέσσερις άσσοι): το μοίρασμα ακυρώνεται, τα φύλλα δείχνονται σε όλους και μοιράζει ξανά ο ίδιος.',
    gather='Μόλις παιχτεί το πρώτο φύλλο, τα τέσσερα μαζεύονται σε στοίβα και από εκεί και πέρα φαίνεται μόνο το πάνω. Όταν αδειάσουν τα χέρια μοιράζονται ξανά φύλλα· στη στοίβα δεν ανοίγουν άλλα.',
    deal4='Κάθε παίκτης παίρνει 4 φύλλα (ή 6, από τις ρυθμίσεις) και 4 φύλλα ανοίγουν στο τραπέζι.',
    jackback='Αν ανοίξει βαλές για το τραπέζι, μπαίνει πίσω στην τράπουλα και ανοίγει άλλο φύλλο.',
    nomore='Όταν αδειάσουν τα χέρια, μοιράζονται ξανά φύλλα· στο τραπέζι δεν ανοίγουν άλλα.',
    ten='10 καρό: 3', ace='Κάθε άσσος: 1', jack='Κάθε βαλές: 1', two='2 σπαθί: 2',
    most='Περισσότερα φύλλα: 3 (στην ισοπαλία 26–26 κανείς)',
    pastra_pile='Κάθε πάστρα: 10 · βαλές σε μόνο βαλέ: 20', pastra_sums='Κάθε πάστρα: 10',
    total='Κάθε γύρος μοιράζει 16 πόντους συν τις πάστρες.',
)

T['tr'] = dict(
    deal6='Her oyuncuya 6 kart (ayarlardan 4) verilir.',
    kapak='Kapak altı: destenin en alttaki kartı açılır ve tur boyunca destenin altında açık durur. Son dağıtılan kart olduğu için dağıtana gider ve herkes bilir.',
    jackalone='Kapak altında vale yalnız kalmaz: kapak altı vale ise yanına bir kart daha açılır (o da vale çıkarsa bir tane daha).',
    opening='Ortaya 4 kart yan yana açılır; en sağdaki en üstteki karttır. Üste vale gelemez: vale açık olarak kapak altına gider ve yerine yeni kart açılır.',
    quad='Bir elde aynı karttan dört tane (ör. dört as) gelirse dağıtım bozulur: kartlar herkese gösterilir ve aynı oyuncu yeniden dağıtır.',
    gather='İlk kart atılınca açılan dört kart tek yığında toplanır; bundan sonra sadece en üstteki görünür. Eller bitince yeniden dağıtılır; yığına yeni kart açılmaz.',
    deal4='Her oyuncuya 4 kart (ayarlardan 6) verilir, masaya 4 kart açık konur.',
    jackback='Masaya vale gelirse desteye geri girer ve yerine başka kart açılır.',
    nomore='Eller bitince yeniden dağıtılır; masaya kart açılmaz.',
    ten='Karo 10: 3', ace='Her as: 1', jack='Her vale: 1', two='Sinek 2: 2',
    most='En çok kart: 3 (26–26 berabere ise kimse almaz)',
    pastra_pile='Her pastra: 10 · tek valeye vale: 20', pastra_sums='Her pastra: 10',
    total='Her tur 16 puan ve pastralardan oluşur.',
)

T['de'] = dict(
    deal6='Jeder bekommt 6 Karten (oder 4, siehe Einstellungen).',
    kapak='Kapak altı: Die unterste Karte des Stapels wird aufgedeckt und liegt die ganze Runde offen unter dem Talon. Sie wird als letzte ausgeteilt, also bekommt sie der Geber, und alle wissen es.',
    jackalone='Ein Bube liegt dort nie allein: Ist die Kapak-altı-Karte ein Bube, wird die nächste Karte daneben aufgedeckt (und noch eine, falls auch sie ein Bube ist).',
    opening='Vier Karten werden offen nebeneinander in die Mitte gelegt; die rechte ist die oberste. Oben darf kein Bube liegen: Er kommt offen unter den Talon und eine andere Karte wird aufgedeckt.',
    quad='Vier gleiche Karten in einer Hand (z. B. vier Asse): Das Geben ist ungültig, die Karten werden allen gezeigt und derselbe Geber gibt neu.',
    gather='Sobald die erste Karte gespielt ist, werden die vier zu einem Stapel zusammengeschoben; danach sieht man nur die oberste. Sind die Hände leer, wird neu ausgeteilt; in die Mitte kommen keine Karten mehr.',
    deal4='Jeder bekommt 4 Karten (oder 6, siehe Einstellungen) und 4 Karten werden offen auf den Tisch gelegt.',
    jackback='Ein für den Tisch aufgedeckter Bube kommt zurück in den Talon und wird ersetzt.',
    nomore='Sind die Hände leer, wird neu ausgeteilt; auf den Tisch kommen keine Karten mehr.',
    ten='Karo 10: 3', ace='Jedes Ass: 1', jack='Jeder Bube: 1', two='Kreuz 2: 2',
    most='Meiste Karten: 3 (bei 26–26 niemand)',
    pastra_pile='Jede Pastra: 10 · Bube auf einzelnen Buben: 20', pastra_sums='Jede Pastra: 10',
    total='Jede Runde bringt 16 Punkte plus Pastras.',
)

T['fr'] = dict(
    deal6='Chacun reçoit 6 cartes (ou 4, voir réglages).',
    kapak="Kapak altı : la carte du dessous du paquet est retournée et reste visible sous le paquet toute la manche. C'est la dernière carte distribuée : le donneur la reçoit et tout le monde le sait.",
    jackalone="Un valet n'y reste jamais seul : si la kapak altı est un valet, la carte suivante est retournée à côté (et encore une si c'est aussi un valet).",
    opening='Quatre cartes sont posées face visible côte à côte au centre ; celle de droite est la carte du dessus. Un valet ne peut pas être dessus : il va face visible sous le paquet et une autre carte est retournée.',
    quad='Quatre cartes identiques dans une main (p. ex. quatre as) : la donne est annulée, les cartes sont montrées à tous et le même donneur redistribue.',
    gather="Dès que la première carte est jouée, les quatre sont réunies en une pile ; ensuite seule la carte du dessus est visible. Quand les mains sont vides, on redistribue ; aucune carte n'est ajoutée au centre.",
    deal4='Chacun reçoit 4 cartes (ou 6, voir réglages) et 4 cartes sont posées face visible sur la table.',
    jackback='Un valet retourné pour la table retourne dans le paquet et est remplacé.',
    nomore='Quand les mains sont vides, on redistribue ; plus aucune carte ne va sur la table.',
    ten='10 de carreau : 3', ace='Chaque as : 1', jack='Chaque valet : 1', two='2 de trèfle : 2',
    most='Le plus de cartes : 3 (personne à 26–26)',
    pastra_pile='Chaque pastra : 10 · valet sur un valet seul : 20', pastra_sums='Chaque pastra : 10',
    total='Chaque manche vaut 16 points plus les pastras.',
)

T['es'] = dict(
    deal6='Cada jugador recibe 6 cartas (o 4, ver ajustes).',
    kapak='Kapak altı: la carta de abajo del mazo se da la vuelta y queda visible bajo el mazo toda la ronda. Es la última que se reparte, así que se la lleva quien reparte y todos lo saben.',
    jackalone='Una jota nunca queda sola ahí: si la kapak altı es una jota, se da la vuelta a la carta siguiente a su lado (y a otra más si también es jota).',
    opening='Se ponen cuatro cartas boca arriba una al lado de otra en el centro; la de la derecha es la de arriba. Arriba no puede quedar una jota: va boca arriba bajo el mazo y se saca otra carta.',
    quad='Cuatro cartas iguales en una mano (p. ej. cuatro ases): el reparto se anula, las cartas se enseñan a todos y reparte de nuevo el mismo jugador.',
    gather='En cuanto se juega la primera carta, las cuatro se juntan en un montón y desde entonces solo se ve la de arriba. Cuando se acaban las manos se reparte de nuevo; al centro no van más cartas.',
    deal4='Cada jugador recibe 4 cartas (o 6, ver ajustes) y se ponen 4 cartas boca arriba en la mesa.',
    jackback='Si sale una jota para la mesa, vuelve al mazo y se sustituye.',
    nomore='Cuando se acaban las manos se reparte de nuevo; a la mesa no van más cartas.',
    ten='10 de diamantes: 3', ace='Cada as: 1', jack='Cada jota: 1', two='2 de tréboles: 2',
    most='Más cartas: 3 (nadie si hay empate 26–26)',
    pastra_pile='Cada pastra: 10 · jota sobre una jota sola: 20', pastra_sums='Cada pastra: 10',
    total='Cada ronda reparte 16 puntos más las pastras.',
)

T['it'] = dict(
    deal6='Ogni giocatore riceve 6 carte (o 4, vedi impostazioni).',
    kapak="Kapak altı: l'ultima carta del mazzo viene girata e resta scoperta sotto il mazzo per tutta la mano. È l'ultima carta distribuita, quindi va al mazziere e tutti lo sanno.",
    jackalone="Un fante non resta mai da solo lì: se la kapak altı è un fante, si gira anche la carta successiva accanto (e un'altra ancora se è di nuovo un fante).",
    opening="Quattro carte vengono messe scoperte una accanto all'altra al centro; quella più a destra è la carta in cima. In cima non può esserci un fante: va scoperto sotto il mazzo e si gira un'altra carta.",
    quad='Quattro carte uguali in una mano (es. quattro assi): la distribuzione è nulla, le carte vengono mostrate a tutti e lo stesso mazziere ridistribuisce.',
    gather='Appena viene giocata la prima carta, le quattro si riuniscono in un mazzetto e da allora si vede solo quella in cima. Quando le mani finiscono si ridistribuisce; al centro non vanno altre carte.',
    deal4='Ogni giocatore riceve 4 carte (o 6, vedi impostazioni) e 4 carte vengono messe scoperte sul tavolo.',
    jackback='Un fante uscito per il tavolo torna nel mazzo e viene sostituito.',
    nomore='Quando le mani finiscono si ridistribuisce; sul tavolo non vanno altre carte.',
    ten='10 di quadri: 3', ace='Ogni asso: 1', jack='Ogni fante: 1', two='2 di fiori: 2',
    most='Più carte: 3 (nessuno se 26–26)',
    pastra_pile='Ogni pastra: 10 · fante su un fante solo: 20', pastra_sums='Ogni pastra: 10',
    total='Ogni mano vale 16 punti più le pastra.',
)

T['pt'] = dict(
    deal6='Cada jogador recebe 6 cartas (ou 4, ver definições).',
    kapak='Kapak altı: a carta de baixo do baralho é virada e fica visível debaixo do baralho a rodada toda. É a última carta distribuída, por isso fica com quem distribui e todos sabem.',
    jackalone='Um valete nunca fica sozinho ali: se a kapak altı for um valete, vira-se também a carta seguinte ao lado dele (e mais uma se também for valete).',
    opening='Quatro cartas são postas viradas para cima lado a lado no centro; a da direita é a carta de cima. Em cima não pode ficar um valete: vai virado para cima para debaixo do baralho e abre-se outra carta.',
    quad='Quatro cartas iguais numa mão (p. ex. quatro ases): a distribuição é anulada, as cartas são mostradas a todos e o mesmo jogador distribui de novo.',
    gather='Assim que a primeira carta é jogada, as quatro juntam-se num monte e daí em diante só se vê a de cima. Quando as mãos acabam distribui-se de novo; não vão mais cartas para o centro.',
    deal4='Cada jogador recebe 4 cartas (ou 6, ver definições) e 4 cartas são postas viradas para cima na mesa.',
    jackback='Um valete que saia para a mesa volta ao baralho e é substituído.',
    nomore='Quando as mãos acabam distribui-se de novo; não vão mais cartas para a mesa.',
    ten='10 de ouros: 3', ace='Cada ás: 1', jack='Cada valete: 1', two='2 de paus: 2',
    most='Mais cartas: 3 (ninguém em 26–26)',
    pastra_pile='Cada pastra: 10 · valete sobre um valete sozinho: 20', pastra_sums='Cada pastra: 10',
    total='Cada rodada vale 16 pontos mais as pastras.',
)

T['ru'] = dict(
    deal6='Каждый получает 6 карт (или 4, см. настройки).',
    kapak='Kapak altı: нижнюю карту колоды открывают, и она весь раунд лежит открытой под колодой. Это последняя раздаваемая карта, поэтому она достаётся сдающему, и все об этом знают.',
    jackalone='Валет там никогда не лежит один: если kapak altı — валет, рядом открывают следующую карту (и ещё одну, если это снова валет).',
    opening='Четыре карты кладут открыто рядом в центр; правая — верхняя. Верхней не может быть валет: он уходит открытым под колоду, и открывают другую карту.',
    quad='Четыре одинаковые карты в одной руке (например, четыре туза): раздача отменяется, карты показывают всем, и тот же игрок сдаёт заново.',
    gather='Как только сыграна первая карта, четыре карты собирают в стопку, и дальше видна только верхняя. Когда руки пустеют, раздают снова; в центр карты больше не кладут.',
    deal4='Каждый получает 4 карты (или 6, см. настройки), на стол открыто кладут 4 карты.',
    jackback='Валет, открытый на стол, возвращается в колоду и заменяется.',
    nomore='Когда руки пустеют, раздают снова; на стол карты больше не кладут.',
    ten='Десятка бубен: 3', ace='Каждый туз: 1', jack='Каждый валет: 1', two='Двойка треф: 2',
    most='Больше карт: 3 (при 26–26 никому)',
    pastra_pile='Каждая пастра: 10 · валет на одинокого валета: 20', pastra_sums='Каждая пастра: 10',
    total='За раунд разыгрывается 16 очков плюс пастры.',
)

T['bg'] = dict(
    deal6='Всеки получава 6 карти (или 4, виж настройките).',
    kapak='Kapak altı: долната карта на тестето се обръща и стои открита под тестето целия рунд. Тя е последната раздадена карта, затова отива при раздаващия и всички знаят това.',
    jackalone='Вале никога не стои само там: ако kapak altı е вале, до него се открива и следващата карта (и още една, ако и тя е вале).',
    opening='Четири карти се нареждат открити една до друга в средата; най-дясната е горната. Отгоре не може да има вале: то отива открито под тестето и се открива друга карта.',
    quad='Четири еднакви карти в една ръка (напр. четири аса): раздаването се анулира, картите се показват на всички и същият играч раздава отново.',
    gather='Щом се изиграе първата карта, четирите се събират в купчина и оттам нататък се вижда само горната. Когато ръцете свършат, се раздава отново; в средата не се слагат нови карти.',
    deal4='Всеки получава 4 карти (или 6, виж настройките) и 4 карти се откриват на масата.',
    jackback='Вале, излязло за масата, се връща в тестето и се заменя.',
    nomore='Когато ръцете свършат, се раздава отново; на масата не се слагат нови карти.',
    ten='Каро 10: 3', ace='Всяко асо: 1', jack='Всяко вале: 1', two='Спатия 2: 2',
    most='Най-много карти: 3 (при 26–26 никой)',
    pastra_pile='Всяка пастра: 10 · вале върху само вале: 20', pastra_sums='Всяка пастра: 10',
    total='Всеки рунд дава 16 точки плюс пастрите.',
)

T['ar'] = dict(
    deal6='يحصل كل لاعب على 6 أوراق (أو 4 من الإعدادات).',
    kapak='Kapak altı: تُقلب الورقة السفلى من الرزمة وتبقى مكشوفة تحتها طوال الجولة. إنها آخر ورقة توزَّع، لذلك تذهب إلى الموزِّع ويعرف الجميع ذلك.',
    jackalone='لا يبقى الولد وحده هناك أبدًا: إذا كانت ورقة kapak altı ولدًا، تُكشف الورقة التالية بجانبه (وأخرى إذا كانت ولدًا أيضًا).',
    opening='توضع أربع أوراق مكشوفة جنبًا إلى جنب في الوسط، والورقة اليمنى هي العليا. لا يجوز أن يكون الولد في الأعلى: يوضع مكشوفًا تحت الرزمة وتُكشف ورقة أخرى.',
    quad='أربع أوراق متشابهة في يد واحدة (مثل أربعة آسات): يُلغى التوزيع، وتُعرض الأوراق على الجميع ويوزّع اللاعب نفسه من جديد.',
    gather='عند لعب أول ورقة تُجمع الأربع في كومة، ومن بعدها لا تظهر إلا العليا. عندما تفرغ الأيدي يُعاد التوزيع، ولا توضع أوراق جديدة في الوسط.',
    deal4='يحصل كل لاعب على 4 أوراق (أو 6 من الإعدادات) وتوضع 4 أوراق مكشوفة على الطاولة.',
    jackback='إذا ظهر ولد للطاولة يعود إلى الرزمة ويُستبدل.',
    nomore='عندما تفرغ الأيدي يُعاد التوزيع، ولا توضع أوراق جديدة على الطاولة.',
    ten='عشرة ديناري: 3', ace='كل آس: 1', jack='كل ولد: 1', two='اثنين سباتي: 2',
    most='أكثر الأوراق: 3 (لا أحد عند 26–26)',
    pastra_pile='كل باسترا: 10 · ولد على ولد وحيد: 20', pastra_sums='كل باسترا: 10',
    total='في كل جولة 16 نقطة إضافة إلى الباسترا.',
)

T['zh'] = dict(
    deal6='每人发 6 张（设置中可改为 4 张）。',
    kapak='Kapak altı：牌库最底下的一张翻成明牌，整轮都露在牌库下面。它是最后发出的一张，所以归发牌者，大家都知道。',
    jackalone='J 不会单独留在那里：如果 kapak altı 是 J，就在旁边再翻开下一张（如果又是 J，再翻一张）。',
    opening='中间并排明放四张牌，最右边的是最上面的牌。最上面不能是 J：J 明着放到牌库底下，再翻一张新牌。',
    quad='一手牌中有四张相同的牌（例如四张 A）：本次发牌作废，向所有人亮牌，由同一人重新发牌。',
    gather='第一张牌打出后，这四张合成一堆，之后只能看到最上面一张。手牌打完后再发牌，中间不再加牌。',
    deal4='每人发 4 张（设置中可改为 6 张），桌上明放 4 张。',
    jackback='翻到桌上的 J 放回牌库并补一张。',
    nomore='手牌打完后再发牌，桌上不再加牌。',
    ten='方块 10：3 分', ace='每张 A：1 分', jack='每张 J：1 分', two='梅花 2：2 分',
    most='牌数最多：3 分（26–26 时都不得）',
    pastra_pile='每次 Pastra：10 分 · J 收单张 J：20 分', pastra_sums='每次 Pastra：10 分',
    total='每轮共 16 分，另加 Pastra 分。',
)


def dealing(code, variant):
    t = T[code]
    if variant == 'pile':
        return '\n'.join([t['deal6'], '• ' + t['kapak'], '• ' + t['jackalone'], '• ' + t['opening'],
                          '• ' + t['quad'], t['gather']])
    return '\n'.join([t['deal4'], '• ' + t['jackback'], '• ' + t['quad'], t['nomore']])


def points(code, variant):
    t = T[code]
    pastra = t['pastra_pile'] if variant == 'pile' else t['pastra_sums']
    lines = [t['ten'], t['ace'], t['jack'], t['two'], t['most'], pastra]
    return '\n'.join(['• ' + x for x in lines] + [t['total']])
