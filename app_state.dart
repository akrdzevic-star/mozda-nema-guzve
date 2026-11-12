import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'strings.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> msgKey = GlobalKey<ScaffoldMessengerState>();
final AppState app = AppState();

String t(String s) => app.en ? (enStrings[s] ?? s) : s;
String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fm(double x, int d) => x.toStringAsFixed(d).replaceAll('.', ',');

// Pretpostavke za modul "Zeleni vozač" (procjena, ne mjerenje).
const int ecoMin = 10; // min kruženja koje se uštedi po dolasku
const double ecoSpeed = 15; // km/h
const double ecoKg = 0.18; // kg CO2 po km
const double ecoTree = 21; // kg CO2 godišnje po stablu (okvirno)
const int ecoSeed = 5; // primjer dolazaka sedmično
const int ecoWeek = 5; // dolazaka sedmično po korisniku (projekcija)

class SavedCar {
  final int lotId, lvl, k;
  SavedCar(this.lotId, this.lvl, this.k);
}

class Reservation {
  final int lotId, lvl, k, total;
  final String plate;
  final DateTime hold;
  final bool p2p;
  Reservation(this.lotId, this.lvl, this.k, this.plate, this.hold, this.total, this.p2p);
}

class Leave {
  final int lotId, lvl, k;
  final DateTime until;
  final bool mine;
  bool claimed = false;
  Leave(this.lotId, this.lvl, this.k, this.until, this.mine);
}

class Report {
  final int id;
  final String lot, where, reason;
  bool confirmed = false;
  Report(this.id, this.lot, this.where, this.reason);
}

class Ticket {
  final String lot, plate;
  DateTime end;
  bool warned = false;
  Ticket(this.lot, this.plate, this.end);
}

class AppState extends ChangeNotifier {
  final List<Lot> lots = buildLots();
  final Set<int> favs = {};
  SavedCar? car;
  Reservation? res;
  final List<Leave> leaves = [];
  final List<Report> reports = [];
  Ticket? ticket;
  int points = 0;
  int etrips = 0;
  bool light = false, big = false, en = false, seenOb = false;
  final ValueNotifier<int> prefsTick = ValueNotifier<int>(0);
  SharedPreferences? _p;
  final Random _rnd = Random();

  Lot lotById(int id) => lots.firstWhere((l) => l.id == id);

  Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
      light = _p!.getBool('light') ?? false;
      big = _p!.getBool('big') ?? false;
      en = _p!.getBool('en') ?? false;
      seenOb = _p!.getBool('ob') ?? false;
      favs.addAll((_p!.getStringList('fav') ?? <String>[]).map(int.parse));
      final c = _p!.getString('car');
      if (c != null) {
        final a = c.split(',');
        car = SavedCar(int.parse(a[0]), int.parse(a[1]), int.parse(a[2]));
      }
    } catch (_) {}
    _startTimers();
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setStringList('fav', favs.map((e) => e.toString()).toList());
    if (car == null) {
      p.remove('car');
    } else {
      p.setString('car', '${car!.lotId},${car!.lvl},${car!.k}');
    }
  }

  void setPref(String key, bool v) {
    if (key == 'light') light = v;
    if (key == 'big') big = v;
    if (key == 'en') en = v;
    if (key == 'ob') seenOb = v;
    _p?.setBool(key, v);
    prefsTick.value++;
    notifyListeners();
  }

  // ---------- poruke ----------
  void toast(String m) {
    msgKey.currentState
      ?..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(m),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating));
  }

  void showAlert(String title, String body) {
    final c = navKey.currentContext;
    if (c == null) return;
    showDialog<void>(
        context: c,
        builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('U redu')))
              ],
            ));
  }

  // ---------- simulacija uživo ----------
  void _startTimers() {
    Timer.periodic(const Duration(seconds: 3), (_) => _simTick());
    Timer.periodic(const Duration(seconds: 1), (_) => _secTick());
    Timer(const Duration(seconds: 6), simLeave);
    Timer.periodic(const Duration(seconds: 30), (_) => simLeave());
  }

  bool locked(Lot l, int lvl, int k) =>
      (res != null && res!.lotId == l.id && res!.lvl == lvl && res!.k == k) ||
      leaveAt(l, lvl, k) != null;

  void _simTick() {
    for (final l in lots) {
      if (l.id != 6) l.updated = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final lv = _rnd.nextInt(l.levels.length);
        final k = _rnd.nextInt(l.levels[lv].length);
        if (!locked(l, lv, k)) l.levels[lv][k] = !l.levels[lv][k];
      }
    }
    final tk = ticket;
    if (tk != null && !tk.warned && tk.end.difference(DateTime.now()) <= const Duration(minutes: 15)) {
      tk.warned = true;
      final m = tk.end.difference(DateTime.now()).inMinutes;
      showAlert('⏰ ${t('Parking ističe')}',
          '${t('Karta za')} ${tk.lot} (${tk.plate}) ${t('ističe za')} ${m <= 0 ? t('manje od minute') : '$m min'}.');
    }
    notifyListeners();
  }

  void _secTick() {
    final now = DateTime.now();
    var ch = false;
    for (final x in List<Leave>.from(leaves)) {
      if (!x.until.isAfter(now)) {
        lotById(x.lotId).levels[x.lvl][x.k] = x.claimed;
        if (x.mine) {
          car = null;
          _save();
        }
        leaves.remove(x);
        ch = true;
      }
    }
    if (res != null && now.isAfter(res!.hold)) {
      res = null;
      ch = true;
    }
    if (ch) notifyListeners();
  }

  // ---------- oslobađanje uličnih mjesta ----------
  Leave? leaveAt(Lot l, int lvl, int k) {
    for (final x in leaves) {
      if (x.lotId == l.id && x.lvl == lvl && x.k == k) return x;
    }
    return null;
  }

  int leaveN(Lot l) => leaves.where((x) => x.lotId == l.id && !x.claimed).length;

  String leaveText(Lot l) {
    final a = leaves.where((x) => x.lotId == l.id && !x.claimed).toList();
    if (a.isEmpty) return '';
    var s = a.map((x) => x.until.difference(DateTime.now()).inSeconds).reduce(min);
    if (s < 0) s = 0;
    final when = s >= 60 ? '1 min' : '$s s';
    final n = a.length;
    if (en) return 'freeing up $n spot${n == 1 ? '' : 's'} in $when';
    return 'oslobađa se $n ${n == 1 ? 'mjesto' : 'mjesta'} za $when';
  }

  void simLeave() {
    if (leaves.any((x) => !x.mine)) return;
    final st = lots.where((l) => l.street).toList();
    if (st.isEmpty) return;
    final l = st[_rnd.nextInt(st.length)];
    final c = <int>[];
    for (var i = 0; i < l.levels[0].length; i++) {
      if (l.levels[0][i] &&
          !l.ev.contains(i) &&
          !l.inv.contains(i) &&
          !locked(l, 0, i) &&
          !(car != null && car!.lotId == l.id && car!.k == i)) {
        c.add(i);
      }
    }
    if (c.isEmpty) return;
    leaves.add(Leave(l.id, 0, c[_rnd.nextInt(c.length)],
        DateTime.now().add(const Duration(seconds: 60)), false));
    toast('🟠 ${t('Vozač kod')}: ${l.name} ${t('napušta mjesto za 1 minut (simulacija)')}');
    notifyListeners();
  }

  void leaveMine() {
    final c = car;
    if (c == null) return;
    final x = Leave(c.lotId, c.lvl, c.k, DateTime.now().add(const Duration(seconds: 60)), true);
    leaves.add(x);
    toast('🟠 ${t('Tvoje mjesto je označeno kao slobodno za 1 minut. Vozači u blizini ga vide na mapi.')}');
    notifyListeners();
    Timer(const Duration(seconds: 12), () {
      if (leaves.contains(x) && !x.claimed) {
        x.claimed = true;
        points += 5;
        toast('🎉 ${t('Vozač u blizini je rezervisao tvoje mjesto. +5 bodova! (simulacija)')}');
        notifyListeners();
      }
    });
  }

  void claimLeave(Lot l, int lvl, int k) {
    final x = leaveAt(l, lvl, k);
    if (x == null) return;
    x.claimed = true;
    res = Reservation(l.id, lvl, k, '—', x.until.add(const Duration(minutes: 5)), 0, true);
    toast('✅ ${t('Mjesto je tvoje. Vozač izlazi za oko minut, čuvamo ga 5 minuta. Pokreni navigaciju.')}');
    notifyListeners();
  }

  // ---------- favoriti, auto, rezervacije, prijave ----------
  void toggleFav(int id) {
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    _save();
    notifyListeners();
  }

  void saveCar(Lot l, int lvl, int k) {
    car = SavedCar(l.id, lvl, k);
    _save();
    notifyListeners();
  }

  void clearCar() {
    car = null;
    _save();
    notifyListeners();
  }

  int reserve(Lot l, int lvl, int k, String plate, int hours, int arriveMin) {
    final total = 2 + l.priceFor!(hours);
    l.levels[lvl][k] = true;
    res = Reservation(l.id, lvl, k, plate.toUpperCase(), DateTime.now().add(Duration(minutes: arriveMin + 15)), total, false);
    notifyListeners();
    return total;
  }

  void cancelRes() {
    res = null;
    notifyListeners();
  }

  void sendReport(Lot l, int lvl, int k, String reason) {
    final where = '${l.levels.length > 1 ? 'nivo -${lvl + 1}, ' : ''}mjesto ${k + 1}';
    reports.insert(0, Report(DateTime.now().millisecondsSinceEpoch, l.name, where, reason));
    notifyListeners();
  }

  void confirmReport(Report r) {
    if (r.confirmed) return;
    r.confirmed = true;
    points += 10;
    notifyListeners();
  }

  // ---------- plaćanje (DEMO) i navigacija ----------
  void payTicket(Lot l, String plate, int hours) {
    ticket = Ticket(l.short, plate.toUpperCase(), DateTime.now().add(Duration(hours: hours)));
    notifyListeners();
  }

  void testWarn() {
    final tk = ticket;
    if (tk == null) return;
    tk.end = DateTime.now().add(const Duration(minutes: 15, seconds: 10));
    tk.warned = false;
    notifyListeners();
  }

  Future<void> navigateTo(Lot l) async {
    etrips++;
    notifyListeners();
    if (l.coupon != null) showCoupon(l);
    try {
      final uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(l.query)}&travelmode=driving');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) toast(t('Nije moguće otvoriti navigaciju.'));
    } catch (_) {
      toast(t('Nije moguće otvoriti navigaciju.'));
    }
  }

  void showCoupon(Lot l) {
    final c = navKey.currentContext;
    final p = l.coupon;
    if (c == null || p == null) return;
    final code = 'MNG-${l.id}${1000 + _rnd.nextInt(9000)}';
    showDialog<void>(
        context: c,
        builder: (ctx) => AlertDialog(
              title: Text('🎁 ${t('Parkiraj i uštedi')}'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('REKLAMA · PRIMJER'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF2C230))),
                const SizedBox(height: 8),
                Text('${t('Hvala što koristite našu aplikaciju. Pokažite ovaj ekran u objektu')} ${p[0]} (${p[1]}, ${l.name}) ${t('i ostvarite besplatnu kafu uz plaćeni parking.')}'),
                const SizedBox(height: 12),
                Center(child: Text(code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2))),
                const SizedBox(height: 12),
                Text(t('Vrijedi danas do 23:59. Primjer: partner i kupon su izmišljeni, samo da se pokaže mogućnost.'), style: const TextStyle(fontSize: 12)),
              ]),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Zatvori')))],
            ));
  }
}
