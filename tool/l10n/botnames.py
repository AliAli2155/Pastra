# Extra computer-player names per language (appended after the first four in gen.py).
# Every language must end up with exactly 40 names; the first four never change
# (saved games refer to names by index).
EXTRA = {
 'el': 'Δημήτρης Κώστας Αλέξανδρος Παναγιώτης Χρήστος Θανάσης Στέλιος Μιχάλης Βασίλης Άρης Πέτρος Σταύρος Αντώνης Λευτέρης Θοδωρής Σωτήρης Κατερίνα Σοφία Αθανασία Δήμητρα Χριστίνα Αναστασία Βασιλική Ιωάννα Ζωή Ειρήνη Φωτεινή Αγγελική Κωνσταντίνα Δέσποινα Αφροδίτη Ελπίδα Μαρίνα Πηνελόπη Ευαγγελία Ναταλία',
 'en': 'James Oliver Liam Noah Jack Henry Thomas Daniel Max Leo Ben Sam Adam Ryan Luke Jake Emma Sophie Olivia Ava Charlotte Amelia Grace Lily Chloe Ruby Zoe Hannah Isla Ella Mia Nora Ivy Alice Lucy Emily',
 'tr': 'Mustafa Ali Hasan Hüseyin İbrahim Emre Burak Murat Can Kerem Cem Berk Onur Serkan Tolga Yusuf Fatma Zeynep Emine Hatice Merve Selin Büşra Esra Derya Ceren Gamze Deniz Nur İpek Pınar Seda Dilara Burcu Melis Ece',
 'de': 'Felix Paul Max Leon Finn Noah Ben Elias Tim Jan Niklas Moritz Tobias Sebastian Florian Julian Marie Sophie Laura Julia Emma Mia Hannah Lea Sarah Clara Johanna Nina Katharina Lisa Emilia Greta Frieda Charlotte Paula Nele',
 'fr': 'Jules Gabriel Arthur Lucas Raphaël Nathan Théo Maxime Antoine Julien Mathieu Pierre Clément Romain Adrien Baptiste Chloé Camille Manon Inès Jade Sarah Louise Alice Lola Zoé Juliette Clara Anaïs Margaux Océane Élise Charlotte Mélanie Pauline Eva',
 'es': 'Carlos Miguel Álvaro Diego Daniel Sergio Adrián Alejandro Iván Rubén Marcos Andrés Jorge Raúl Hugo Mateo Carmen Laura Marta Paula Elena Sara Claudia Andrea Alba Irene Julia Nuria Isabel Rocío Cristina Patricia Beatriz Silvia Noelia Ainhoa',
 'it': 'Andrea Matteo Francesco Alessandro Lorenzo Davide Simone Federico Riccardo Stefano Paolo Giorgio Gabriele Nicola Tommaso Enrico Chiara Francesca Sara Martina Elena Alessia Giorgia Valentina Elisa Silvia Federica Laura Anna Beatrice Paola Ilaria Camilla Alice Noemi Greta',
 'pt': 'Miguel Tiago Rui Diogo Rafael André Bruno Carlos Nuno Hugo Gonçalo Filipe Ricardo Paulo Duarte Vasco Beatriz Inês Catarina Sofia Mariana Joana Teresa Carolina Rita Marta Leonor Sara Helena Margarida Filipa Clara Raquel Daniela Luísa Matilde',
 'ru': 'Алексей Сергей Андрей Михаил Николай Владимир Павел Артём Максим Егор Кирилл Олег Антон Игорь Роман Денис Елена Ольга Наталья Татьяна Екатерина Ирина Светлана Юлия Алиса Дарья Полина Виктория Ксения Софья Вера Надежда Валерия Алёна Маргарита Анастасия',
 'bg': 'Димитър Николай Петър Стефан Христо Александър Красимир Борис Владимир Калоян Тодор Любомир Михаил Васил Венцислав Пламен Десислава Силвия Теодора Йорданка Радостина Цветелина Виктория Николина Габриела Надежда Симона Ралица Полина Гергана Анелия Мариана Калина Весела Боряна Ангелина',
 'ar': 'محمد علي حسن خالد يوسف إبراهيم كريم طارق سامي ماجد ياسر زياد نبيل عادل فادي هشام فاطمة عائشة سارة نور هدى سلمى رنا دينا لينا جميلة أمل ريم هالة منى سعاد زينب ياسمين نادية سناء رشا',
 'zh': '小刚 小华 大伟 志强 建国 小龙 小军 阿杰 小峰 子轩 浩然 阿宝 小勇 小东 阿辉 小凯 小丽 小芳 小燕 阿梅 小雪 小玲 佳怡 雨涵 小娟 小琳 梓萱 欣怡 小莉 阿珍 小敏 晓燕 思雨 小慧 梦琪 小青',
}
EXTRA = {k: v.split() for k, v in EXTRA.items()}
