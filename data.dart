import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Near {
  final String icon, title, text;
  const Near(this.icon, this.title, this.text);
}

class Lot {
  final int id;
  final String name, short, type, query;
  final LatLng pos;
  final List<List<bool>> levels; // true = zauzeto
  Lot(this.id, this.name, this.short, this.type, this.query, this.pos, this.levels);

  List<List<String>> prices = [];
  String priceNote = '';
  String? priceSource;
  List<List<String>> hours = [];
  String hoursNote = '';
  int Function(int)? priceFor; // cijena za N sati u KM
  int? daily;
  bool street = false; // ulična zona: naplata pon-sub 07-22
  List<int> ev = [];
  List<int> inv = [];
  List<Near> near = [];
  String nearNote = '';
  String highlight = '';
  DateTime updated = DateTime.now();
  List<String>? coupon; // [partner, gdje]

  bool get hasPay => priceFor != null;
  int get total => levels.fold(0, (a, l) => a + l.length);
  int get free => levels.fold(0, (a, l) => a + l.where((o) => !o).length);
  int freeOf(List<int> idx) =>
      idx.where((i) => i < levels[0].length && !levels[0][i]).length;
  bool get stale => DateTime.now().difference(updated).inMinutes >= 5;
  Color get color {
    if (stale) return const Color(0xFF8A9A90);
    final f = free / total;
    if (f > .3) return const Color(0xFF3FCF74);
    if (f >= .1) return const Color(0xFFF2C230);
    return const Color(0xFFEF5B5B);
  }
}

Lot _mk(int id, String name, String short, String type, String query, double la,
    double ln, int total, int lv, double fr) {
  final r = Random(id * 977 + 13);
  final per = (total / lv).ceil();
  return Lot(id, name, short, type, query, LatLng(la, ln),
      List.generate(lv, (_) => List.generate(per, (_) => r.nextDouble() > fr)));
}

const String kRadSource = 'Izvor: cjenovnik KJKP "Rad", na snazi od 27.7.2026.';
const String _naplata =
    'Naplata: ponedjeljak–subota, I zona 07–22 h, II zona 07–20 h; nedjeljom i praznicima besplatno. ';
const String _radnoStreet = 'Parking Sarajevo (KJKP Rad); II zona se naplaćuje 07–20 h.';
const String _src2023 =
    'Izvor: radiosarajevo.ba (oko 2023.) i internet pretraga; nije službeni cjenovnik.';

List<Lot> buildLots() {
  final scc = _mk(1, 'Sarajevo City Center (garaža)', 'SCC', 'Tržni centar · Vrbanja 1',
      'Sarajevo City Center, Vrbanja 1, Sarajevo', 43.8553, 18.4069, 1100, 4, .30)
    ..priceFor = ((h) => h == 1 ? 3 : 3 + 2 * (h - 1))
    ..daily = 30
    ..ev = [0, 1, 2]
    ..inv = [3, 4]
    ..coupon = ['Kafić Primjer', 'na prvom spratu']
    ..highlight = '🏛️ Blizu muzeja, Parlamenta i Mosta Suade i Olge'
    ..prices = [
      ['Dnevna tarifa (08–22 h)', '1. sat 3 KM, svaki sljedeći 2 KM'],
      ['Noćna tarifa (22–08 h)', '1 KM po satu'],
      ['Prvih 15 minuta', 'besplatno'],
      ['Dnevna karta (24 h)', '30 KM'],
      ['Sedmična karta', '80 KM'],
      ['Polumjesečna karta', '130 KM'],
      ['Mjesečna karta (24 h)', '230 KM'],
      ['Mjesečna noćna (20–08 h)', '60 KM'],
    ]
    ..priceNote =
        'Na stranici SCC-a postoji i obavijest o 60 minuta besplatnog parkinga; datum obavijesti nije poznat, provjeriti na ulazu u garažu.'
    ..priceSource = 'Izvor: scc.ba/bs/parking.html (datum cjenovnika nije naveden).'
    ..hours = [
      ['Trgovine', '10–22 h'],
      ['Kafići', '08–23 h'],
      ['Supermarket', '08–22 h'],
      ['Garaža', 'noćna tarifa 22–08 h'],
    ]
    ..hoursNote =
        'Prema turističkim vodičima; garaža vjerovatno radi i noću jer cjenovnik ima noćnu tarifu. Provjeriti na scc.ba.'
    ..near = [
      const Near('🏛️', 'Muzeji na Zmaja od Bosne',
          'Zemaljski muzej BiH i Historijski muzej BiH, u istom dijelu Marijin Dvora.'),
      const Near('🌉', 'Most Suade i Olge (Vrbanja)', 'Spomen na prve žrtve opsade Sarajeva 1992.'),
      const Near('🏨', 'Marijin Dvor', 'Hotel Holiday, UNITIC tornjevi (Momo i Uzeir), Filozofski fakultet.'),
      const Near('🚋', 'Tramvaj', 'Stajalište Marijin Dvor je nekoliko minuta hoda.'),
    ]
    ..nearNote = 'Izvori: sarajevo.travel, kupi.com. Udaljenosti nisu mjerene.';

  final alta = _mk(2, 'Alta Shopping Center', 'Alta', 'Tržni centar · Franca Lehara 2',
      'Alta Shopping Center, Franca Lehara 2, Sarajevo', 43.8567, 18.4030, 300, 2, .15)
    ..priceFor = ((h) => 2 * h)
    ..ev = [0, 1, 2]
    ..inv = [3, 4]
    ..coupon = ['Pekara Primjer', 'u prizemlju']
    ..highlight = '🛍️ Preko puta SCC-a, u kvartu s muzejima'
    ..prices = [
      ['Sat parkiranja (dan)', '2 KM']
    ]
    ..priceNote =
        'Pretraga navodi i noćnu tarifu od 1 KM te 1 sat besplatno uz račun iz supermarketa; nije potvrđeno. Provjeriti na ulazu.'
    ..priceSource = _src2023
    ..hours = [
      ['Pon–sub', '09–22 h'],
      ['Nedjelja', '11–19 h'],
    ]
    ..hoursNote = 'Neslužbeni izvor; provjeriti na alta.ba.'
    ..near = [
      const Near('🛍️', 'Preko puta SCC-a', 'Dva tržna centra u Marijin Dvoru.'),
      const Near('🏛️', 'Muzeji', 'Zemaljski i Historijski muzej BiH u istom kvartu (Marijin Dvor).'),
      const Near('🏨', 'Marijin Dvor', 'Hotel Holiday, UNITIC tornjevi, Parlament BiH.'),
      const Near('🅿️', 'Garaža', 'Dva podzemna nivoa; centar ima 6 nivoa trgovina i market.'),
    ]
    ..nearNote = 'Izvori: sarajevo.travel, kupi.com, sgpa.com. Udaljenosti nisu mjerene.';

  final imp = _mk(3, 'Importanne Centar', 'Importanne', 'Tržni centar · Zmaja od Bosne 7–7a',
      'Importanne Centar, Zmaja od Bosne 7, Sarajevo', 43.8550, 18.4000, 300, 2, .50)
    ..priceFor = ((h) => h)
    ..ev = [0, 1, 2]
    ..inv = [3, 4]
    ..coupon = ['Kafić Primjer', 'u prizemlju']
    ..highlight = '🏛️ U istoj ulici s Zemaljskim i Historijskim muzejem'
    ..prices = [
      ['Sat parkiranja', '1 KM']
    ]
    ..priceNote =
        'Pretraga navodi da je prvi sat možda besplatan uz kupovinu; nije potvrđeno. Provjeriti na ulazu.'
    ..priceSource = _src2023
    ..near = [
      const Near('🏛️', 'Zemaljski muzej BiH',
          'Zmaja od Bosne 3. Arheologija, etnologija, botanički vrt; čuva Sarajevsku hagadu.'),
      const Near('🏛️', 'Historijski muzej BiH', 'Zmaja od Bosne 5. Stalna postavka „Opkoljeno Sarajevo“.'),
      const Near('🏢', 'Nasuprot Ambasade SAD', 'Prema članku iz 2014. godine.'),
      const Near('🚋', 'Tramvaj', 'Stajalište „Tehnička škola“ kod Zemaljskog muzeja.'),
    ]
    ..nearNote =
        'Izvori: zemaljskimuzej.ba, muzej.ba, exploresarajevo.com, balcanicaucaso.org. Radno vrijeme muzeja provjeriti kod njih.';

  final aria = _mk(4, 'ARIA Mall (bivši BBI)', 'ARIA', 'Tržni centar · Trg djece Sarajeva 1',
      'ARIA Mall, Trg djece Sarajeva 1, Sarajevo', 43.8581, 18.4164, 469, 3, .08)
    ..priceFor = ((h) => 2 * h)
    ..ev = [0, 1, 2]
    ..inv = [3, 4]
    ..coupon = ['Kafić Primjer', 'na drugom spratu']
    ..highlight = '🎭 Veliki trg ispred centra za događaje'
    ..prices = [
      ['Pon–sub 08–20 h', '2 KM po satu'],
      ['Pon–sub 20–24 h', '1 KM po satu'],
      ['Pon–sub 24–08 h', '0,50 KM po satu'],
      ['Nedjelja 08–24 h', '1 KM po satu'],
      ['Nedjelja 24–08 h', '0,50 KM po satu'],
    ]
    ..priceNote =
        'ARIA nudi akciju 2 h besplatnog parkinga (uslovi na ariamall.ba). Neki izvori navode 3–4 KM po satu, što je vjerovatno zastarjelo.'
    ..priceSource = 'Izvor: sarajevo.travel (Parking ARIA Mall); datum nije naveden.'
    ..hours = [
      ['Tržni centar', 'oko 09–22 h'],
      ['Garaža', 'pon–ned 00–24 h'],
    ]
    ..hoursNote =
        'Prema ariamall.ba i sarajevo.travel. Upravljanje centrom je od 1.11.2026. preuzeo Bingo, pa se radno vrijeme i naziv mogu promijeniti.'
    ..near = [
      const Near('🏙️', 'U centru grada', 'Na mjestu nekadašnje robne kuće Sarajka.'),
      const Near('🎭', 'Trg ispred centra', 'Mjesto okupljanja i događaja: koncerti, radionice, dječije igraonice.'),
      const Near('🅿️', 'Garaža', '469 mjesta na tri podzemna nivoa, s video nadzorom.'),
      const Near('🏢', 'Veliki centar', 'Oko 43.000 m², banke i kancelarije na spratovima.'),
    ]
    ..nearNote = 'Izvor: Wikipedia (ARIA Centar).';

  final sken = _mk(5, 'Parking Skenderija', 'Skenderija', 'Javni parking · Terezija bb',
      'Centar Skenderija, Terezija, Sarajevo', 43.8587, 18.4105, 350, 1, .40)
    ..priceFor = ((h) => 3 * h)
    ..daily = 30
    ..street = true
    ..ev = [0, 1, 2]
    ..inv = [3, 4]
    ..coupon = ['Bistro Primjer', 'kod ulaza']
    ..highlight = '🌉 Blizu Mosta Suade i Olge i Marijin Dvora'
    ..prices = [
      ['Sat parkiranja (I zona)', '3 KM'],
      ['Dnevna karta', '30 KM'],
      ['Sedmična karta', '65 KM'],
      ['Mjesečna za stanare', '55 KM'],
    ]
    ..priceNote =
        '${_naplata}Zona prema podacima turističke zajednice; provjeriti oznaku zone na terenu.'
    ..hours = [
      ['Naplata parkinga', 'pon–sub, I zona 07–22 h'],
      ['Nedjelja i praznici', 'besplatno'],
    ]
    ..hoursNote = _radnoStreet
    ..near = [
      const Near('🏟️', 'Centar Skenderija', 'Sportski objekti i plato ispred njega.'),
      const Near('🌉', 'Most Suade i Olge', 'U blizini; spomen na prve žrtve opsade.'),
      const Near('🏛️', 'Marijin Dvor', 'Muzeji i Parlament BiH u susjedstvu.'),
    ]
    ..nearNote = 'Izvori: sarajevo.travel, visitsarajevo.ba. Udaljenosti nisu mjerene.';

  final cigl = _mk(6, 'Garaža Ciglane', 'Ciglane', 'Javna garaža', 'Garaža Ciglane, Sarajevo',
      43.8615, 18.4140, 200, 1, .22)
    ..inv = [0, 1]
    ..highlight = '🏘️ Naselje Ciglane, sjeverno od centra'
    ..prices = [
      ['Mjesečni zakup, Ciglane I', '90 KM'],
      ['Mjesečni zakup, Ciglane II', '80 KM'],
      ['Satnica', 'nije javno objavljena'],
    ]
    ..near = [
      const Near('📍', 'Merhemića trg / Alipašina', 'Naselje Ciglane, sjeverno od glavnog dijela centra.'),
      const Near('🅿️', 'Garaža', 'Često veća popunjenost; koriste je stanari i putnici na dnevnoj bazi.'),
    ]
    ..nearNote = 'Izvori: centar.ba, eurocityguide.com. Znamenitosti u blizini nisu provjerene.'
    ..updated = DateTime.now().subtract(const Duration(minutes: 12));

  final basc = _mk(7, 'Baščaršija – ulična zona', 'Baščaršija', 'Ulični parking',
      'Baščaršija, Sarajevo', 43.8597, 18.4313, 60, 1, .12)
    ..priceFor = ((h) => 3 * h)
    ..daily = 30
    ..street = true
    ..inv = [0, 1]
    ..highlight = '🕌 Sebilj, Gazi Husrev-begova džamija, Vijećnica'
    ..prices = [
      ['Sat – I zona', '3 KM'],
      ['Sat – II zona', '2 KM'],
      ['Dnevna karta (I / II zona)', '30 / 15 KM'],
    ]
    ..priceNote = '${_naplata}Za plaćanje je uzeta I zona; provjeriti oznaku zone na terenu.'
    ..hours = [
      ['Naplata parkinga', 'pon–sub, I zona 07–22 h'],
      ['Nedjelja i praznici', 'besplatno'],
    ]
    ..hoursNote = _radnoStreet
    ..near = [
      const Near('⛲', 'Sebilj', 'Drvena česma na glavnom trgu, simbol grada.'),
      const Near('🕌', 'Gazi Husrev-begova džamija', 'Iz 16. stoljeća, sa satnom kulom i medresom.'),
      const Near('🛖', 'Morića han', 'Jedini sačuvani karavansaraj u Sarajevu (1551).'),
      const Near('🏛️', 'Vijećnica', 'Gradska vijećnica iz austrougarskog doba, nekadašnja Nacionalna biblioteka.'),
      const Near('🛍️', 'Bezistan, Sarači, Ferhadija', 'Stara čaršija i glavna pješačka zona.'),
      const Near('🌉', 'Latinska ćuprija', 'Kratka šetnja uz Miljacku.'),
    ]
    ..nearNote = 'Izvori: Wikipedia (Baščaršija), sarajevo.travel, easybalkantransfers.com.';

  final vij = _mk(8, 'Garaža kod Vijećnice', 'Vijećnica', 'Javna podzemna garaža · Avdage Šahinagića',
      'Garaža Avdage Šahinagića, Vijećnica, Sarajevo', 43.8585, 18.4345, 155, 2, .35)
    ..priceFor = ((h) => 2 * h)
    ..ev = [0]
    ..inv = [3, 4]
    ..highlight = '🏛️ Preko puta Vijećnice, pet minuta do Baščaršije'
    ..prices = [
      ['Prvi sat', '2 KM'],
      ['Svakih narednih započetih 30 min', '1 KM'],
      ['Zadržavanje do 10 minuta', 'besplatno'],
      ['Mjesečni najam (fizička lica)', '200 KM'],
      ['Mjesečni najam (pravna lica, bez PDV-a)', '300 KM'],
    ]
    ..priceNote =
        'Cjenovnik je iz objave Općine Stari Grad oko 2021. godine; može biti promijenjen. Provjeriti na ulazu.'
    ..priceSource = 'Izvor: starigrad.ba (Općina Stari Grad).'
    ..hours = [
      ['Garaža', '24 h dnevno'],
      ['Sigurnost', 'videonadzor i 24-satno fizičko obezbjeđenje'],
    ]
    ..hoursNote = 'Prema objavi Općine Stari Grad (oko 2021.). Provjeriti da li još važi.'
    ..near = [
      const Near('🏛️', 'Vijećnica', 'Garaža je preko puta Vijećnice, ispod novog trga od blizu 3.000 m².'),
      const Near('🕌', 'Baščaršija', 'Oko 5 minuta hoda (prema sarajevo.travel).'),
      const Near('🚡', 'Sarajevska žičara', 'Donja stanica oko 5 minuta hoda (prema sarajevo.travel).'),
      const Near('⚡', 'Punjač za električna vozila',
          'Postavio ga je Porsche BH uz Općinu Stari Grad; punjenje je najavljeno kao besplatno 5 godina od otvaranja (2020.), pa provjeriti da li još važi.'),
      const Near('🅿️', 'Prva javna podzemna garaža',
          'Dva podzemna nivoa, oko 155 do 157 mjesta, ulaz i izlaz kod semafora na Novom mostu Vijećnice.'),
    ]
    ..nearNote =
        'Izvori: starigrad.ba, klix.ba, radiosarajevo.ba, sarajevo.travel. Pozicija na mapi je okvirna.';

  return [scc, alta, imp, aria, sken, cigl, basc, vij];
}
