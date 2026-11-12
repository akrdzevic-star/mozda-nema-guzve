import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'app_state.dart';
import 'data.dart';
import 'detail.dart';
import 'me_tab.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const App());
}

bool splashDone = false;

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: app.prefsTick,
      builder: (context, _, __) => MaterialApp(
        key: ValueKey<String>('lang-${app.en}'),
        navigatorKey: navKey,
        scaffoldMessengerKey: msgKey,
        title: 'Možda nema gužve',
        debugShowCheckedModeBanner: false,
        theme: brandTheme(app.light),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(app.big ? 1.2 : 1.0)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: splashDone ? (app.seenOb ? const Home() : const Onboarding()) : const Splash(),
      ),
    );
  }
}

// ---------------- ekran dobrodošlice i uvod ----------------
class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      splashDone = true;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => app.seenOb ? const Home() : const Onboarding()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kDarkGreen,
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Image.asset('assets/logo.png'))),
      );
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int i = 0;
  static const pages = [
    ['🗺️', 'Pronađi slobodno mjesto', 'Mapa pokazuje koliko je mjesta slobodno u garažama i na ulici, uživo.'],
    ['🧭', 'Navigiraj do ulaza', 'Jednim dodirom otvoriš Google Maps i kreneš direktno do izabranog parkinga.'],
    ['💳', 'Plati, rezerviraj, uštedi', 'Plati parking, rezerviraj mjesto, prijavi nepravilno parkiranje i prati koliko CO₂ si uštedjela.'],
  ];

  void finish() {
    app.setPref('ob', true);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
  }

  @override
  Widget build(BuildContext context) {
    final p = pages[i];
    return Scaffold(
      backgroundColor: kDarkGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(p[0], style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(t(p[1]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(t(p[2]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFFD6EFD9), height: 1.4)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < pages.length; k++)
                Container(
                  margin: const EdgeInsets.all(3),
                  width: k == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: k == i ? kLime : const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kLime, foregroundColor: kOnLime, minimumSize: const Size.fromHeight(52)),
              onPressed: () => i < pages.length - 1 ? setState(() => i++) : finish(),
              child: Text(i < pages.length - 1 ? t('Dalje') : t('Počni'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            TextButton(onPressed: finish, child: Text(t('Preskoči'), style: const TextStyle(color: kLime))),
          ]),
        ),
      ),
    );
  }
}

// ---------------- glavni ekran ----------------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  Lot? mini;
  final TextEditingController q = TextEditingController();
  final Set<String> filters = {};
  String sort = 'free';

  static const chipDefs = [
    ['free', 'Slobodno >30%'],
    ['mall', 'Tržni centri'],
    ['pub', 'Javni parkinzi'],
    ['pay', 'Plaćanje'],
    ['ev', '⚡ Punjači'],
    ['inv', '♿ Invalidi'],
    ['lv', '🟠 Oslobađa se'],
    ['fav', '⭐ Favoriti'],
  ];

  bool pass(Lot l) {
    final s = q.text.trim().toLowerCase();
    if (s.isNotEmpty && !'${l.name} ${l.type}'.toLowerCase().contains(s)) return false;
    final mall = l.type.startsWith('Tržni');
    if (filters.contains('free') && (l.stale || l.free / l.total <= .3)) return false;
    if (filters.contains('mall') && !mall) return false;
    if (filters.contains('pub') && mall) return false;
    if (filters.contains('pay') && !l.hasPay) return false;
    if (filters.contains('ev') && l.freeOf(l.ev) == 0) return false;
    if (filters.contains('inv') && l.freeOf(l.inv) == 0) return false;
    if (filters.contains('lv') && app.leaveN(l) == 0) return false;
    if (filters.contains('fav') && !app.favs.contains(l.id)) return false;
    return true;
  }

  List<Lot> sorted() {
    final a = app.lots.where(pass).toList();
    int crit(Lot x, Lot y) {
      if (sort == 'name') return x.name.compareTo(y.name);
      if (sort == 'price') return (costFor(x, 2) ?? 1000000).compareTo(costFor(y, 2) ?? 1000000);
      return (y.free / y.total).compareTo(x.free / x.total);
    }

    a.sort((x, y) {
      final f = (app.favs.contains(y.id) ? 1 : 0) - (app.favs.contains(x.id) ? 1 : 0);
      return f != 0 ? f : crit(x, y);
    });
    return a;
  }

  void openLot(Lot l) {
    setState(() => mini = null);
    Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(lot: l)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kDarkGreen,
        foregroundColor: kLime,
        titleSpacing: 12,
        title: Row(children: [
          Image.asset('assets/mark.png', height: 28),
          const SizedBox(width: 8),
          Flexible(child: Text(t('Možda nema gužve'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kLime))),
        ]),
        actions: [
          TextButton(
              onPressed: () => app.setPref('en', !app.en),
              child: Text(app.en ? 'BS' : 'EN', style: const TextStyle(color: kLime, fontWeight: FontWeight.bold))),
          IconButton(
              tooltip: t('Tema'),
              onPressed: () => app.setPref('light', !app.light),
              icon: Icon(app.light ? Icons.dark_mode : Icons.light_mode)),
          IconButton(
              tooltip: t('Veličina teksta'),
              onPressed: () => app.setPref('big', !app.big),
              icon: const Icon(Icons.text_fields)),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (ctx, _) => Column(children: [
          _ticketBanner(),
          if (tab != 2) _filters(),
          Expanded(
            child: IndexedStack(index: tab, children: [_mapTab(), _listTab(), const MeTab()]),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          mini = null;
        }),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: t('Mapa')),
          NavigationDestination(icon: const Icon(Icons.list_alt), label: t('Lista')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t('Moje')),
        ],
      ),
    );
  }

  Widget _ticketBanner() {
    final tk = app.ticket;
    if (tk == null) return const SizedBox.shrink();
    final left = tk.end.difference(DateTime.now());
    final soon = left <= const Duration(minutes: 15);
    final mins = left.inMinutes < 0 ? 0 : left.inMinutes;
    final label = soon ? '⏰ ${t('Parking ističe')}: ' : '${t('Aktivna karta')}: ';
    return Container(
      width: double.infinity,
      color: soon ? kRed : kLime,
      padding: const EdgeInsets.all(8),
      child: Text('$label${tk.lot} · ${tk.plate} · ${t('još')} $mins min',
          textAlign: TextAlign.center,
          style: TextStyle(color: soon ? Colors.white : kOnLime, fontWeight: FontWeight.w700)),
    );
  }

  Widget _filters() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          controller: q,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: t('Traži objekat…'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            for (final c in chipDefs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(t(c[1])),
                  selected: filters.contains(c[0]),
                  onSelected: (v) => setState(() => v ? filters.add(c[0]) : filters.remove(c[0])),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _stat(String big, String label, VoidCallback onTap, bool on) {
    return Expanded(
      child: Panel(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        border: on ? Theme.of(context).colorScheme.primary : null,
        onTap: onTap,
        child: Column(children: [
          Text(big, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          Text(label, textAlign: TextAlign.center, style: muted(context, size: 11)),
        ]),
      ),
    );
  }

  Widget _mapTab() {
    final shown = app.lots.where(pass).toList();
    final ok = app.lots.where((l) => !l.stale).toList();
    int sm(List<int> Function(Lot) f) => ok.fold(0, (a, l) => a + l.freeOf(f(l)));
    final total = ok.fold(0, (a, l) => a + l.free);
    final m = mini;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          _stat('$total', t('slobodnih mjesta'), () => setState(filters.clear), false),
          _stat('⚡ ${sm((l) => l.ev)}', t('slobodnih punjača'), () => setState(() => filters.contains('ev') ? filters.remove('ev') : filters.add('ev')), filters.contains('ev')),
          _stat('♿ ${sm((l) => l.inv)}', t('slobodnih invalidskih mjesta'), () => setState(() => filters.contains('inv') ? filters.remove('inv') : filters.add('inv')), filters.contains('inv')),
        ]),
      ),
      Expanded(
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(43.8575, 18.4110),
              initialZoom: 14.6,
              onTap: (_, __) => setState(() => mini = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ba.mozdanemaguzve.mozda_nema_guzve',
              ),
              MarkerLayer(markers: [for (final l in shown) _marker(l)]),
              RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
          if (m != null) Positioned(left: 10, right: 10, bottom: 10, child: _miniCard(m)),
        ]),
      ),
    ]);
  }

  Marker _marker(Lot l) {
    final n = app.leaveN(l);
    return Marker(
      point: l.pos,
      width: 140,
      height: 96,
      child: GestureDetector(
        onTap: () => setState(() => mini = l),
        child: Stack(children: [
          if (n > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Blink(
                child: Text(app.leaveText(l),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kOrange, backgroundColor: Color(0xCCFFFFFF))),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 25,
            child: Center(
              child: Stack(alignment: Alignment.center, children: [
                if (n > 0)
                  Blink(
                    child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kOrange, width: 3))),
                  ),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: l.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: Text(l.stale ? '?' : '${l.free}', style: const TextStyle(color: Color(0xFF04210F), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 73,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(6)),
                child: Text(l.short, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _miniCard(Lot l) {
    final pr = costFor(l, 1);
    return Panel(
      margin: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 8, backgroundColor: l.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(l.type, style: muted(context)),
              if (l.highlight.isNotEmpty) Text(l.highlight, style: muted(context)),
            ]),
          ),
          Column(children: [
            Text('${l.free}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            Text('${t('od')} ${l.total}', style: muted(context, size: 11)),
          ]),
          IconButton(
              onPressed: () => app.toggleFav(l.id),
              icon: Text(app.favs.contains(l.id) ? '⭐' : '☆', style: const TextStyle(fontSize: 22))),
          IconButton(onPressed: () => setState(() => mini = null), icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 6),
        Text('${pr == null ? t('Cijena: provjeriti na ulazu') : '${t('Od')} $pr KM ${t('za prvi sat')}'} · ${spInfo(l)}', style: muted(context)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => openLot(l), child: Text(t('Detalji')))),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => app.navigateTo(l),
                  icon: const Icon(Icons.navigation),
                  label: Text(t('Navigiraj')))),
        ]),
      ]),
    );
  }

  Widget _listTab() {
    final items = sorted();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: DropdownButton<String>(
          isExpanded: true,
          value: sort,
          items: [
            DropdownMenuItem(value: 'free', child: Text(t('Sortiraj: najviše slobodnih'))),
            DropdownMenuItem(value: 'price', child: Text(t('Sortiraj: najjeftinije (2 h)'))),
            DropdownMenuItem(value: 'name', child: Text(t('Sortiraj: po nazivu'))),
          ],
          onChanged: (v) => setState(() => sort = v ?? 'free'),
        ),
      ),
      Expanded(
        child: items.isEmpty
            ? Center(child: Text(t('Nema rezultata za odabrane filtere.')))
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (final l in items)
                  Panel(
                    onTap: () => openLot(l),
                    child: Row(children: [
                      CircleAvatar(radius: 7, backgroundColor: l.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${app.favs.contains(l.id) ? '⭐ ' : ''}${l.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                          Text(l.type, style: muted(context)),
                          Text(spInfo(l), style: muted(context)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: l.free / l.total, color: l.color, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Column(children: [
                        Text('${l.free}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                        Text('${t('od')} ${l.total}', style: muted(context, size: 11)),
                      ]),
                    ]),
                  ),
                const SizedBox(height: 12),
              ]),
      ),
    ]);
  }
}
