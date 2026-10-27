RULES = {}

RULES['tr'] = {
 'pile': [
  ('Oyun', 'Pastra 52 kartlık tek desteyle iki kişi ya da eşli dört kişi oynanır (eşin karşında oturur, kartlarınız birlikte sayılır). Kartlar ortada tek bir yığına atılır; amaç yığını almak ve pastra yapmaktır.'),
  ('Dağıtım', 'Destenin en alttaki kartı açılır ve tur boyunca destenin altında açık durur ("kapak altı"): son dağıtılan kart olduğu için dağıtana gider ve herkes onda olduğunu bilir.\nHer oyuncuya 6 kart (ayarlardan 4) verilir. Ortaya 4 kart yan yana açılır; en sağdaki en üstteki kart sayılır. Oraya vale gelirse kapak altına gider ve yerine yeni kart açılır. İlk kart atılınca dördü tek yığında toplanır, bundan sonra sadece en üstteki görünür. Eller bitince yeniden dağıtılır; ortaya yeni kart açılmaz.'),
  ('Kart alma', 'Sıran gelince yığının üstüne bir kart atarsın.\n• En üstteki kartla aynı değerdeyse (7\'ye 7, kıza kız) bütün yığını alırsın.\n• Vale her zaman bütün yığını alır.\n• Değilse kartın yığının üstünde kalır ve alttakileri kapatır.\nAlttaki kartlar görünmez: neler atıldığını aklında tutman gerekir.'),
  ('Pastra', 'Yığında tek kart varken onu aynı değerde kartla alırsan pastra yaparsın: 10 puan. Tek valeyi valeyle almak 20 puan (ayarlardan 10 / 20 / 25). Tek başka kartı valeyle almak ve turun en son kartı pastra sayılmaz (ayarlanabilir).'),
  ('Tur sonu', 'Deste ve eller bitince yığında kalan kartları en son alan oyuncu alır (bu pastra sayılmaz).'),
  ('Puanlar', '• En çok kart: 3 (26–26 berabere ise kimse almaz)\n• Her as, papaz, kız, vale ve 10: 1\n• Karo 10: 1 fazla, toplam 2\n• Sinek 2: 1\n• Her pastra: 10 · valeye vale: 20\nHer tur 25 puan ve pastralardan oluşur.'),
  ('Kazanma', '151 puana (ya da ayarlardaki hedefe) ilk ulaşan taraf kazanır. İki taraf aynı turda geçip berabere kalırsa bir tur daha oynanır. Her tur dağıtan bir sonraki oyuncuya geçer.'),
  ('Uygulamada', 'Oynamak için elindeki kartı ortaya sürükle. Sürüklerken (ya da bir kez dokununca) kart yığını alacaksa üstteki kart parlar; ikinci dokunuş da kartı oynar. Ayarlardan Kıbrıs usulü toplamalı pastrayı da seçebilirsin.'),
 ],
 'sums': [
  ('Oyun', 'Pastra 52 kartlık tek desteyle iki kişi ya da eşli dört kişi oynanır (eşin karşında oturur, kartlarınız birlikte sayılır). Amaç masadan kart almaktır.'),
  ('Dağıtım', 'Her oyuncuya 4 kart (ayarlardan 6) verilir, masaya 4 kart açık konur. Masaya vale gelirse desteye geri girer ve yerine başka kart açılır. Eller bitince yeniden dağıtılır; masaya kart açılmaz.'),
  ('Kart alma', 'Sıran gelince bir kart atarsın.\n• As ile 10 arası: aynı kartları ve toplamı aynı değeri tutan kart gruplarını alır (as 1 sayılır). Ör. 8, masadaki 8\'i, 5+3\'ü ve 6+A+A\'yı birlikte alır.\n• Kız ve papaz sadece kızı ve papazı alır; toplamaya girmez.\n• Vale bütün masayı alır.\nKartın alabiliyorsa alabileceği en çok kartı alır, alamıyorsa masada açık kalır.'),
  ('Pastra', 'Masayı vale dışında bir kartla tamamen temizlemek pastradır: 10 puan. Tek valeyi valeyle almak 10 puan (ayarlardan 0 / 10 / 20).'),
  ('Tur sonu', 'Deste ve eller bitince masada kalan kartları en son alan oyuncu alır (bu pastra sayılmaz).'),
  ('Puanlar', '• En çok kart: 3 (26–26 berabere ise kimse almaz)\n• Her as: 1 · her vale: 1\n• Sinek 2: 2\n• Karo 10: 3\n• Her pastra: 10\nHer tur 16 puan ve pastralardan oluşur.'),
  ('Kazanma', '101 puana (ya da ayarlardaki hedefe) ilk ulaşan taraf kazanır. İki taraf aynı turda geçip berabere kalırsa bir tur daha oynanır. Her tur dağıtan bir sonraki oyuncuya geçer.'),
  ('Uygulamada', 'Bir karta dokununca neleri alacağı görünür (masadaki kartlar parlar); oynamak için ortaya sürükle ya da tekrar dokun.'),
 ],
}

RULES['de'] = {
 'pile': [
  ('Das Spiel', 'Pastra wird mit einem Blatt zu 52 Karten zu zweit oder zu viert in Teams gespielt (dein Partner sitzt dir gegenüber, eure Karten zählen zusammen). Die Karten werden auf einen Stapel in der Mitte gespielt; Ziel ist es, den Stapel zu nehmen und Pastras zu machen.'),
  ('Austeilen', 'Die unterste Karte des Stapels wird aufgedeckt und liegt die ganze Runde offen unter dem Talon („kapak altı“): Sie wird als letzte ausgeteilt, also bekommt sie der Geber, und alle wissen es.\nJeder bekommt 6 Karten (oder 4, siehe Einstellungen). Vier Karten werden offen nebeneinander in die Mitte gelegt; die rechte ist die oberste. Oben darf kein Bube liegen: Er kommt offen unter den Talon und eine andere Karte wird aufgedeckt. Sobald die erste Karte gespielt ist, werden die vier zu einem Stapel zusammengeschoben; danach sieht man nur die oberste. Sind die Hände leer, wird neu ausgeteilt; in die Mitte kommen keine Karten mehr.'),
  ('Karten nehmen', 'Wenn du dran bist, spielst du eine Karte auf den Stapel.\n• Hat sie denselben Rang wie die oberste Karte (7 auf 7, Dame auf Dame), nimmst du den ganzen Stapel.\n• Ein Bube nimmt immer den ganzen Stapel.\n• Sonst bleibt deine Karte oben liegen und verdeckt die anderen.\nDie Karten unter der obersten sind nicht sichtbar: Du musst dir merken, was gespielt wurde.'),
  ('Pastra', 'Liegt nur eine Karte auf dem Stapel und du nimmst sie mit einer Karte gleichen Rangs, ist das eine Pastra: 10 Punkte. Bube auf einzelnem Buben: 20 Punkte (einstellbar: 10 / 20 / 25). Ein Bube auf einer einzelnen anderen Karte ist keine Pastra, die letzte Karte der Runde auch nicht (einstellbar).'),
  ('Rundenende', 'Wenn Talon und Hände aufgebraucht sind, bekommt der Spieler, der zuletzt genommen hat, den Rest des Stapels (keine Pastra).'),
  ('Punkte', '• Meiste Karten: 3 (bei 26–26 niemand)\n• Jedes Ass, jeder König, jede Dame, jeder Bube und jede Zehn: 1\n• Karo 10: 1 zusätzlich, insgesamt 2\n• Kreuz 2: 1\n• Jede Pastra: 10 · Bube auf Bube: 20\nJede Runde bringt 25 Punkte plus Pastras.'),
  ('Sieg', 'Wer zuerst 151 Punkte (oder das eingestellte Ziel) erreicht, gewinnt. Überschreiten beide Seiten das Ziel in derselben Runde mit Gleichstand, wird eine weitere Runde gespielt. Der Geber wechselt jede Runde.'),
  ('In der App', 'Ziehe eine Karte aus deiner Hand in die Mitte, um sie zu spielen. Beim Ziehen (oder nach einmaligem Tippen) leuchtet die oberste Karte auf, wenn du sie nimmst; ein zweites Tippen spielt die Karte ebenfalls. In den Einstellungen kannst du auch die zypriotische Pastra mit Summen wählen.'),
 ],
 'sums': [
  ('Das Spiel', 'Pastra wird mit einem Blatt zu 52 Karten zu zweit oder zu viert in Teams gespielt (dein Partner sitzt dir gegenüber, eure Karten zählen zusammen). Ziel ist es, Karten vom Tisch zu nehmen.'),
  ('Austeilen', 'Jeder bekommt 4 Karten (oder 6) und 4 Karten werden offen auf den Tisch gelegt. Ein aufgedeckter Bube kommt zurück in den Talon und wird ersetzt. Sind die Hände leer, wird neu ausgeteilt; auf den Tisch kommen keine Karten mehr.'),
  ('Karten nehmen', 'Wenn du dran bist, spielst du eine Karte.\n• Ass bis 10: nimmt gleiche Karten und jede Gruppe, deren Summe denselben Wert ergibt (Ass = 1). Eine 8 nimmt z. B. 8, 5+3 und 6+A+A zusammen.\n• Dame und König nehmen nur Dame bzw. König; sie werden nie addiert.\n• Ein Bube nimmt den ganzen Tisch.\nKann deine Karte nehmen, nimmt sie so viele Karten wie möglich; sonst bleibt sie offen liegen.'),
  ('Pastra', 'Den ganzen Tisch mit einer Karte außer einem Buben abzuräumen ist eine Pastra: 10 Punkte. Bube auf einzelnem Buben: 10 Punkte (einstellbar: 0 / 10 / 20).'),
  ('Rundenende', 'Sind Talon und Hände aufgebraucht, bekommt der Spieler, der zuletzt genommen hat, die restlichen Tischkarten (keine Pastra).'),
  ('Punkte', '• Meiste Karten: 3 (bei 26–26 niemand)\n• Jedes Ass: 1 · jeder Bube: 1\n• Kreuz 2: 2\n• Karo 10: 3\n• Jede Pastra: 10\nJede Runde bringt 16 Punkte plus Pastras.'),
  ('Sieg', 'Wer zuerst 101 Punkte (oder das eingestellte Ziel) erreicht, gewinnt. Bei Gleichstand nach Überschreiten wird weitergespielt. Der Geber wechselt jede Runde.'),
  ('In der App', 'Tippe eine Karte an, um zu sehen, was sie nimmt (die Tischkarten leuchten); zum Spielen in die Mitte ziehen oder noch einmal tippen.'),
 ],
}

RULES['fr'] = {
 'pile': [
  ('Le jeu', 'La Pastra se joue avec un jeu de 52 cartes à deux, ou à quatre en équipes (ton partenaire est en face de toi et vos cartes comptent ensemble). Les cartes sont jouées sur une seule pile au centre ; le but est de prendre la pile et de faire des pastras.'),
  ('La donne', 'La carte du dessous du paquet est retournée et reste visible sous le paquet toute la manche (« kapak altı ») : c\'est la dernière carte distribuée, le donneur la reçoit et tout le monde le sait.\nChacun reçoit 6 cartes (ou 4, voir réglages). Quatre cartes sont posées face visible côte à côte au centre ; celle de droite est la carte du dessus. Un valet ne peut pas être dessus : il va face visible sous le paquet et une autre carte est retournée. Dès que la première carte est jouée, les quatre sont réunies en une pile ; ensuite seule la carte du dessus est visible. Quand les mains sont vides, on redistribue ; aucune carte n\'est ajoutée au centre.'),
  ('Prendre', 'À ton tour, tu joues une carte sur la pile.\n• Si elle a la même valeur que la carte du dessus (7 sur 7, dame sur dame), tu prends toute la pile.\n• Un valet prend toujours toute la pile.\n• Sinon ta carte reste dessus et cache les autres.\nLes cartes sous celle du dessus sont cachées : il faut se souvenir de ce qui a été joué.'),
  ('Pastra', 'Quand la pile ne contient qu\'une carte et que tu la prends avec une carte de même valeur, c\'est une pastra : 10 points. Valet sur un valet seul : 20 points (réglable : 10 / 20 / 25). Un valet qui prend une autre carte seule n\'est pas une pastra, ni la dernière carte de la manche (réglable).'),
  ('Fin de manche', 'Quand le paquet et les mains sont épuisés, ce qui reste sur la pile va au dernier joueur qui a pris (ce n\'est pas une pastra).'),
  ('Points', '• Le plus de cartes : 3 (personne à 26–26)\n• Chaque as, roi, dame, valet et dix : 1\n• 10 de carreau : 1 de plus, 2 au total\n• 2 de trèfle : 1\n• Chaque pastra : 10 · valet sur valet : 20\nChaque manche vaut 25 points plus les pastras.'),
  ('Victoire', 'Le premier camp à atteindre 151 points (ou l\'objectif réglé) gagne. Si les deux camps le dépassent dans la même manche à égalité, on joue une manche de plus. La donne passe au joueur suivant à chaque manche.'),
  ('Dans l\'appli', 'Glisse une carte de ta main vers le centre pour la jouer. Pendant le glissement (ou après un toucher), la carte du dessus s\'allume si tu la prends ; un second toucher joue aussi la carte. Dans les réglages tu peux aussi choisir la pastra chypriote avec sommes.'),
 ],
 'sums': [
  ('Le jeu', 'La Pastra se joue avec un jeu de 52 cartes à deux, ou à quatre en équipes (ton partenaire est en face de toi et vos cartes comptent ensemble). Le but est de prendre des cartes sur la table.'),
  ('La donne', 'Chacun reçoit 4 cartes (ou 6) et 4 cartes sont posées face visible sur la table. Un valet retourné pour la table retourne dans le paquet et est remplacé. Quand les mains sont vides, on redistribue ; plus aucune carte ne va sur la table.'),
  ('Prendre', 'À ton tour, tu joues une carte.\n• As à 10 : prend les cartes égales et chaque groupe de cartes dont la somme fait la même valeur (l\'as vaut 1). Un 8 prend par exemple 8, 5+3 et 6+A+A ensemble.\n• Dames et rois ne prennent que dames et rois ; ils ne s\'additionnent jamais.\n• Un valet prend toute la table.\nSi ta carte peut prendre, elle prend le plus de cartes possible ; sinon elle reste visible sur la table.'),
  ('Pastra', 'Vider toute la table avec une carte autre qu\'un valet est une pastra : 10 points. Valet sur un valet seul : 10 points (réglable : 0 / 10 / 20).'),
  ('Fin de manche', 'Quand le paquet et les mains sont épuisés, les cartes restées sur la table vont au dernier joueur qui a pris (ce n\'est pas une pastra).'),
  ('Points', '• Le plus de cartes : 3 (personne à 26–26)\n• Chaque as : 1 · chaque valet : 1\n• 2 de trèfle : 2\n• 10 de carreau : 3\n• Chaque pastra : 10\nChaque manche vaut 16 points plus les pastras.'),
  ('Victoire', 'Le premier camp à atteindre 101 points (ou l\'objectif réglé) gagne. En cas d\'égalité au-delà, on joue une manche de plus. La donne passe au joueur suivant à chaque manche.'),
  ('Dans l\'appli', 'Touche une carte pour voir ce qu\'elle prendrait (les cartes de la table s\'allument) ; glisse-la au centre ou touche-la encore pour la jouer.'),
 ],
}

RULES['es'] = {
 'pile': [
  ('El juego', 'La Pastra se juega con una baraja de 52 cartas entre dos, o entre cuatro por parejas (tu compañero se sienta enfrente y vuestras cartas cuentan juntas). Las cartas se juegan a un solo montón en el centro; el objetivo es llevarse el montón y hacer pastras.'),
  ('Reparto', 'La carta de abajo del mazo se da la vuelta y queda visible bajo el mazo toda la ronda («kapak altı»): es la última que se reparte, así que se la lleva quien reparte y todos lo saben.\nCada jugador recibe 6 cartas (o 4, ver ajustes). Se ponen cuatro cartas boca arriba una al lado de otra en el centro; la de la derecha es la de arriba. Arriba no puede quedar una jota: va boca arriba bajo el mazo y se saca otra carta. En cuanto se juega la primera carta, las cuatro se juntan en un montón y desde entonces solo se ve la de arriba. Cuando se acaban las manos se reparte de nuevo; al centro no van más cartas.'),
  ('Cómo se captura', 'En tu turno juegas una carta sobre el montón.\n• Si tiene el mismo valor que la de arriba (7 sobre 7, reina sobre reina), te llevas todo el montón.\n• La jota siempre se lleva todo el montón.\n• Si no, tu carta queda arriba y tapa a las demás.\nLas cartas de debajo no se ven: tienes que recordar lo que se ha jugado.'),
  ('Pastra', 'Si en el montón hay una sola carta y te la llevas con otra del mismo valor, haces pastra: 10 puntos. Jota sobre una jota sola: 20 puntos (ajustable: 10 / 20 / 25). Una jota que se lleva otra carta sola no es pastra, ni la última carta de la ronda (ajustable).'),
  ('Fin de ronda', 'Cuando se acaban el mazo y las manos, lo que queda en el montón es para el último que capturó (no es pastra).'),
  ('Puntos', '• Más cartas: 3 (nadie si hay empate 26–26)\n• Cada as, rey, reina, jota y diez: 1\n• 10 de diamantes: 1 más, 2 en total\n• 2 de tréboles: 1\n• Cada pastra: 10 · jota sobre jota: 20\nCada ronda reparte 25 puntos más las pastras.'),
  ('Victoria', 'Gana el primer bando que llega a 151 puntos (o al objetivo de los ajustes). Si ambos lo superan en la misma ronda empatados, se juega otra ronda. El que reparte cambia en cada ronda.'),
  ('En la app', 'Arrastra una carta de tu mano al centro para jugarla. Mientras la arrastras (o tras tocarla una vez) la carta de arriba se ilumina si la capturas; un segundo toque también la juega. En los ajustes puedes elegir también la pastra chipriota con sumas.'),
 ],
 'sums': [
  ('El juego', 'La Pastra se juega con una baraja de 52 cartas entre dos, o entre cuatro por parejas (tu compañero se sienta enfrente y vuestras cartas cuentan juntas). El objetivo es llevarse cartas de la mesa.'),
  ('Reparto', 'Cada jugador recibe 4 cartas (o 6) y se ponen 4 cartas boca arriba en la mesa. Si sale una jota para la mesa, vuelve al mazo y se sustituye. Cuando se acaban las manos se reparte de nuevo; a la mesa no van más cartas.'),
  ('Cómo se captura', 'En tu turno juegas una carta.\n• As a 10: se lleva las cartas iguales y cada grupo de cartas que sume el mismo valor (el as vale 1). Un 8 se lleva, por ejemplo, 8, 5+3 y 6+A+A a la vez.\n• Reinas y reyes solo se llevan reinas y reyes; nunca se suman.\n• La jota se lleva toda la mesa.\nSi tu carta puede capturar, se lleva todas las que pueda; si no, queda boca arriba en la mesa.'),
  ('Pastra', 'Dejar la mesa vacía con una carta que no sea jota es pastra: 10 puntos. Jota sobre una jota sola: 10 puntos (ajustable: 0 / 10 / 20).'),
  ('Fin de ronda', 'Cuando se acaban el mazo y las manos, las cartas de la mesa son para el último que capturó (no es pastra).'),
  ('Puntos', '• Más cartas: 3 (nadie si hay empate 26–26)\n• Cada as: 1 · cada jota: 1\n• 2 de tréboles: 2\n• 10 de diamantes: 3\n• Cada pastra: 10\nCada ronda reparte 16 puntos más las pastras.'),
  ('Victoria', 'Gana el primer bando que llega a 101 puntos (o al objetivo de los ajustes). Si hay empate al superarlo, se juega otra ronda. El que reparte cambia en cada ronda.'),
  ('En la app', 'Toca una carta para ver qué se llevaría (se iluminan las cartas de la mesa); arrástrala al centro o tócala otra vez para jugarla.'),
 ],
}

RULES['it'] = {
 'pile': [
  ('Il gioco', 'La Pastra si gioca con un mazzo da 52 carte in due, o in quattro a coppie (il compagno siede di fronte e le vostre carte contano insieme). Le carte si giocano su un unico mazzetto al centro; lo scopo è prendere il mazzetto e fare pastra.'),
  ('Distribuzione', 'L\'ultima carta del mazzo viene girata e resta scoperta sotto il mazzo per tutta la mano («kapak altı»): è l\'ultima carta distribuita, quindi va al mazziere e tutti lo sanno.\nOgni giocatore riceve 6 carte (o 4, vedi impostazioni). Quattro carte vengono messe scoperte una accanto all\'altra al centro; quella più a destra è la carta in cima. In cima non può esserci un fante: va scoperto sotto il mazzo e si gira un\'altra carta. Appena viene giocata la prima carta, le quattro si riuniscono in un mazzetto e da allora si vede solo quella in cima. Quando le mani finiscono si ridistribuisce; al centro non vanno altre carte.'),
  ('Prese', 'Al tuo turno giochi una carta sul mazzetto.\n• Se ha lo stesso valore della carta in cima (7 su 7, donna su donna), prendi tutto il mazzetto.\n• Il fante prende sempre tutto il mazzetto.\n• Altrimenti la tua carta resta in cima e copre le altre.\nLe carte sotto non si vedono: devi ricordare cosa è stato giocato.'),
  ('Pastra', 'Se nel mazzetto c\'è una sola carta e la prendi con una carta dello stesso valore, fai pastra: 10 punti. Fante su un fante solo: 20 punti (regolabile: 10 / 20 / 25). Un fante che prende un\'altra carta sola non è pastra, e nemmeno l\'ultima carta della mano (regolabile).'),
  ('Fine della mano', 'Quando mazzo e mani sono finiti, ciò che resta sul mazzetto va all\'ultimo che ha preso (non è pastra).'),
  ('Punti', '• Più carte: 3 (nessuno se 26–26)\n• Ogni asso, re, donna, fante e dieci: 1\n• 10 di quadri: 1 in più, 2 in tutto\n• 2 di fiori: 1\n• Ogni pastra: 10 · fante su fante: 20\nOgni mano vale 25 punti più le pastra.'),
  ('Vittoria', 'Vince la prima squadra che arriva a 151 punti (o all\'obiettivo impostato). Se entrambe lo superano nella stessa mano in parità, si gioca un\'altra mano. Il mazziere cambia a ogni mano.'),
  ('Nell\'app', 'Trascina una carta dalla mano al centro per giocarla. Mentre la trascini (o dopo un tocco) la carta in cima si illumina se la prendi; un secondo tocco gioca la carta. Nelle impostazioni puoi scegliere anche la pastra cipriota con le somme.'),
 ],
 'sums': [
  ('Il gioco', 'La Pastra si gioca con un mazzo da 52 carte in due, o in quattro a coppie (il compagno siede di fronte e le vostre carte contano insieme). Lo scopo è prendere carte dal tavolo.'),
  ('Distribuzione', 'Ogni giocatore riceve 4 carte (o 6) e 4 carte vengono messe scoperte sul tavolo. Un fante uscito per il tavolo torna nel mazzo e viene sostituito. Quando le mani finiscono si ridistribuisce; sul tavolo non vanno altre carte.'),
  ('Prese', 'Al tuo turno giochi una carta.\n• Dall\'asso al 10: prende le carte uguali e ogni gruppo di carte la cui somma dà lo stesso valore (l\'asso vale 1). Un 8 prende per esempio 8, 5+3 e 6+A+A insieme.\n• Donne e re prendono solo donne e re; non si sommano mai.\n• Il fante prende tutto il tavolo.\nSe la tua carta può prendere, prende più carte possibile; altrimenti resta scoperta sul tavolo.'),
  ('Pastra', 'Svuotare il tavolo con una carta che non sia un fante è pastra: 10 punti. Fante su un fante solo: 10 punti (regolabile: 0 / 10 / 20).'),
  ('Fine della mano', 'Quando mazzo e mani sono finiti, le carte rimaste sul tavolo vanno all\'ultimo che ha preso (non è pastra).'),
  ('Punti', '• Più carte: 3 (nessuno se 26–26)\n• Ogni asso: 1 · ogni fante: 1\n• 2 di fiori: 2\n• 10 di quadri: 3\n• Ogni pastra: 10\nOgni mano vale 16 punti più le pastra.'),
  ('Vittoria', 'Vince la prima squadra che arriva a 101 punti (o all\'obiettivo impostato). In caso di parità oltre l\'obiettivo si gioca un\'altra mano. Il mazziere cambia a ogni mano.'),
  ('Nell\'app', 'Tocca una carta per vedere cosa prenderebbe (le carte del tavolo si illuminano); trascinala al centro o toccala di nuovo per giocarla.'),
 ],
}
