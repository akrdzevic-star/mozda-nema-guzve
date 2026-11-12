import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_state.dart';
import 'data.dart';
import 'widgets.dart';

class Detail extends StatefulWidget {
  final Lot lot;
  const Detail({super.key, required this.lot});
  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 3, vsync: this);
  Lot get lot => widget.lot;
  int lvl = 0;
  int? selK;
  int selLvl = 0;
  // plaćanje (demo)
  int hours = 1;
  bool daily = false;
  String method = 'Kartica';
  final TextEditingController plate = TextEditingController();
  String? payResult;

  static const reasons = [
    'Zauzeo/la dva mjesta',
    'Parkirano koso / preko linije',
    'Mjesto za osobe s invaliditetom bez oznake',
    'Punjač zauzet bez punjenja',
    'Blokira prolaz ili izlaz',
  ];

  @override
  void dispose() {
    tc.dispose();
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kDarkGreen,
        foregroundColor: kLime,
        title: Text(lot.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kLime)),
        actions: [
          ListenableBuilder(
            listenable: app,
            builder: (_, __) => IconButton(
              onPressed: () => app.toggleFav(lot.id),
              icon: Text(app.favs.contains(lot.id) ? '⭐' : '☆', style: const TextStyle(fontSize: 24)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: tc,
          labelColor: kLime,
          unselectedLabelColor: Colors.white70,
          indicatorColor: kLime,
          tabs: [Tab(text: t('Tlocrt')), Tab(text: t('Cijene')), Tab(text: t('Info'))],
        ),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (ctx, _) => TabBarView(controller: tc, children: [planTab(), pricesTab(), infoTab()]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => app.navigateTo(lot),
                icon: const Icon(Icons.navigation),
                label: Text(t('Pokreni navigaciju'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            if (lot.hasPay) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => tc.animateTo(1),
                  child: Text('💳 ${t('Plati')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------- TLOCRT ----------------
  String specialAt(int i) {
    if (lvl != 0) return '';
    if (lot.ev.contains(i)) return 'ev';
    if (lot.inv.contains(i)) return 'inv';
    return '';
  }

  Widget cell(List<bool> spots, int i) {
    final occ = spots[i];
    final ty = specialAt(i);
    final sv = app.car;
    final r = app.res;
    final isCar = sv != null && sv.lotId == lot.id && sv.lvl == lvl && sv.k == i;
    final isRes = r != null && r.lotId == lot.id && r.lvl == lvl && r.k == i;
    final isLeave = app.leaveAt(lot, lvl, i) != null;
    final isSel = selK == i && selLvl == lvl;
    Color color = occ ? kRed : kFree;
    if (isRes) color = kYellow;
    if (isLeave) color = kOrange;
    String sym = occ ? '✕' : '✓';
    if (ty == 'ev') sym = '⚡';
    if (ty == 'inv') sym = '♿';
    if (isLeave) sym = '⏳';
    if (isRes) sym = '🔒';
    if (isCar) sym = '🚗';
    Widget cellBox = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isSel
            ? Border.all(color: Colors.white, width: 2.5)
            : (ty.isNotEmpty || isCar ? Border.all(color: Colors.white, width: 1.5) : null),
      ),
      child: Text(sym, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
    );
    if (isLeave) cellBox = Blink(child: cellBox);
    return GestureDetector(
      onTap: () => setState(() {
        selK = i;
        selLvl = lvl;
      }),
      child: cellBox,
    );
  }

  Widget legendItem(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 6, backgroundColor: c),
        const SizedBox(width: 5),
        Text(s, style: muted(context)),
      ]);

  Widget planTab() {
    final spots = lot.levels[lvl];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('${lot.type} · ${t('Slobodno')} ${lot.free}/${lot.total}', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(spInfo(lot), style: muted(context)),
      const SizedBox(height: 8),
      if (lot.levels.length > 1)
        Wrap(spacing: 8, children: [
          for (var i = 0; i < lot.levels.length; i++)
            ChoiceChip(
              label: Text('${t('Nivo')} -${i + 1}'),
              selected: i == lvl,
              onSelected: (_) => setState(() => lvl = i),
            ),
        ]),
      Panel(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: spots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 14, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.75),
          itemBuilder: (_, i) => cell(spots, i),
        ),
      ),
      Wrap(spacing: 14, runSpacing: 4, children: [
        legendItem(kFree, '✓ ${t('Slobodno')}'),
        legendItem(kRed, '✕ ${t('Zauzeto')}'),
        Text('⚡ ${t('Punjač')}', style: muted(context)),
        Text('♿ ${t('Invalidi')}', style: muted(context)),
        legendItem(kOrange, t('Oslobađa se')),
        legendItem(kYellow, '🔒 ${t('Rezervirano')}'),
      ]),
      Text(t('Primjer: raspored punjača i invalidskih mjesta je simuliran.'), style: muted(context, size: 11)),
      const SizedBox(height: 8),
      actionPanel(),
    ]);
  }

  String whereTxt(int l, int k) => '${lvT(lot, l)}${t('mjesto')} ${k + 1}';

  Widget actionPanel() {
    final k = selK;
    final sv = app.car;
    if (k != null) {
      final occ = lot.levels[selLvl][k];
      final isCar = sv != null && sv.lotId == lot.id && sv.lvl == selLvl && sv.k == k;
      final r = app.res;
      final isRes = r != null && r.lotId == lot.id && r.lvl == selLvl && r.k == k;
      final lv = app.leaveAt(lot, selLvl, k);
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${t('Odabrano')}: ${whereTxt(selLvl, k)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              app.saveCar(lot, selLvl, k);
              setState(() => selK = null);
            },
            icon: const Icon(Icons.push_pin),
            label: Text(t('Spasi moju lokaciju')),
          ),
          if (lot.hasPay && !lot.street && !occ && app.res == null)
            OutlinedButton.icon(
              onPressed: () => reserveDialog(k),
              icon: const Icon(Icons.lock_outline),
              label: Text(t('Rezerviraj ovo mjesto')),
            ),
          if (occ && !isCar && !isRes && lv == null)
            OutlinedButton.icon(
              onPressed: () => reportDialog(k),
              icon: const Icon(Icons.warning_amber),
              label: Text(t('Prijavi nepravilno parkiranje')),
            ),
          if (lv != null && !lv.mine && !lv.claimed && app.res == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
              onPressed: () {
                app.claimLeave(lot, selLvl, k);
                setState(() => selK = null);
              },
              icon: const Icon(Icons.hourglass_top),
              label: Text(t('Rezerviši mjesto dok izlazi')),
            ),
        ]),
      );
    }
    if (sv != null && sv.lotId == lot.id) {
      final mineLeave = app.leaveAt(lot, sv.lvl, sv.k) != null;
      return Panel(
        border: Theme.of(context).colorScheme.primary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('🚗', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Text('${t('Vaš auto')}: ${whereTxt(sv.lvl, sv.k)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            TextButton(onPressed: app.clearCar, child: Text(t('Obriši'))),
          ]),
          if (lot.street && !mineLeave)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
              onPressed: app.leaveMine,
              icon: const Icon(Icons.exit_to_app),
              label: Text(t('Napuštam mjesto za 1 minut')),
            ),
        ]),
      );
    }
    return Text(t('Dodirni mjesto na tlocrtu: spasi lokaciju auta, rezerviraj slobodno mjesto ili prijavi nepravilno parkiranje na zauzetom.'), style: muted(context));
  }

  void reserveDialog(int k) {
    var arrive = 15;
    var hrs = 1;
    var m = 'Kartica';
    final pl = TextEditingController();
    String? err;
    final level = selLvl;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final total = 2 + lot.priceFor!(hrs);
        return AlertDialog(
          title: Text('🔒 ${t('Rezervacija mjesta')}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${lot.name} · ${whereTxt(level, k)}', style: muted(ctx)),
              const SizedBox(height: 8),
              Text(t('Dolazim za')),
              Wrap(spacing: 6, children: [
                for (final a in [15, 30, 60])
                  ChoiceChip(label: Text(a == 60 ? '1 h' : '$a min'), selected: arrive == a, onSelected: (_) => setD(() => arrive = a)),
              ]),
              const SizedBox(height: 8),
              Text(t('Planirano trajanje')),
              Wrap(spacing: 6, children: [
                for (final h in [1, 2, 3]) ChoiceChip(label: Text('$h h'), selected: hrs == h, onSelected: (_) => setD(() => hrs = h)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: pl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: t('Registarska oznaka'), errorText: err),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final x in ['Kartica', 'Google Pay / Apple Pay'])
                  ChoiceChip(label: Text(x), selected: m == x, onSelected: (_) => setD(() => m = x)),
              ]),
              const SizedBox(height: 10),
              Text('${t('Ukupno')}: $total KM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(t('Naknada za rezervaciju 2 KM + parking po cjenovniku. Mjesto se čuva 15 minuta nakon planiranog dolaska. Primjer: iznosi i pravila su izmišljeni.'), style: muted(ctx, size: 11)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Odustani'))),
            FilledButton(
              onPressed: () {
                if (pl.text.trim().isEmpty) {
                  setD(() => err = t('Unesi registarsku oznaku.'));
                  return;
                }
                final tot = app.reserve(lot, level, k, pl.text.trim(), hrs, arrive);
                Navigator.pop(ctx);
                setState(() => selK = null);
                final hold = app.res == null ? '' : hhmm(app.res!.hold);
                app.showAlert('✅ ${t('Mjesto rezervirano')}',
                    '${lot.name} · ${whereTxt(level, k)}\n${t('Plaćeno')} $tot KM ($m) ${t('za')} ${pl.text.trim().toUpperCase()}.\n${t('Mjesto čuvamo do')} $hold.\n\n${t('Stvarna naplata nije izvršena. Rezervaciju možeš otkazati u tabu „Moje“.')}');
              },
              child: Text(t('Rezerviraj i plati')),
            ),
          ],
        );
      }),
    );
  }

  void reportDialog(int k) {
    final level = selLvl;
    var idx = 0;
    if (level == 0 && lot.inv.contains(k)) idx = 2;
    if (level == 0 && lot.ev.contains(k)) idx = 3;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text('⚠️ ${t('Prijava nepravilnog parkiranja')}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${lot.name} · ${whereTxt(level, k)}', style: muted(ctx)),
              for (var i = 0; i < reasons.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(reasons[i])),
                  trailing: i == idx ? const Icon(Icons.check_circle) : const Icon(Icons.circle_outlined),
                  onTap: () => setD(() => idx = i),
                ),
              Text(t('Prijava je anonimna prema operateru. Bodovi (+10) se dodjeljuju nakon što operater potvrdi prijavu. Fotografija nije dio ove probne verzije.'), style: muted(ctx, size: 11)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Odustani'))),
            FilledButton(
              onPressed: () {
                app.sendReport(lot, level, k, reasons[idx]);
                Navigator.pop(ctx);
                setState(() => selK = null);
                app.showAlert('✅ ${t('Prijava poslana')}', t('Operator objekta je dobio prijavu. Kad je potvrdi, dobit ćeš +10 bodova. Prijavu možeš pratiti u tabu „Moje“.'));
              },
              child: Text(t('Pošalji prijavu')),
            ),
          ],
        );
      }),
    );
  }

  // ---------------- CIJENE ----------------
  void doPay() {
    final n = DateTime.now();
    if (lot.street && (n.weekday == DateTime.sunday || n.hour < 7 || n.hour >= 22)) {
      setState(() => payResult = t('Parking se trenutno ne naplaćuje (naplata: pon–sub, I zona 07–22 h; nedjeljom i praznicima besplatno).'));
      return;
    }
    if (plate.text.trim().isEmpty) {
      setState(() => payResult = t('Unesi registarsku oznaku.'));
      return;
    }
    final h = daily ? 24 : hours;
    final amount = daily ? lot.daily! : lot.priceFor!(hours);
    final pl = plate.text.trim().toUpperCase();
    app.payTicket(lot, pl, h);
    final end = app.ticket!.end;
    setState(() => payResult =
        'DEMO: ${t('plaćanje')} $amount KM ${t('za')} $pl ($method). ${t('Karta vrijedi do')} ${hhmm(end)}. ${t('Upozorenje stiže 15 minuta prije isteka. Stvarna naplata nije izvršena.')}');
  }

  Widget payPanel() {
    final amount = daily ? lot.daily! : lot.priceFor!(hours);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lot.street ? t('Plati parking (DEMO)') : t('Plati garažnu kartu (DEMO)'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final h in [1, 2, 3])
            ChoiceChip(
              label: Text('$h h'),
              selected: !daily && hours == h,
              onSelected: (_) => setState(() {
                daily = false;
                hours = h;
              }),
            ),
          if (lot.daily != null)
            ChoiceChip(label: Text(t('Dnevna karta')), selected: daily, onSelected: (_) => setState(() => daily = true)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: plate,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: t('Registarska oznaka'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: [
          for (final x in ['Kartica', 'Google Pay / Apple Pay'])
            ChoiceChip(label: Text(x), selected: method == x, onSelected: (_) => setState(() => method = x)),
        ]),
        const SizedBox(height: 10),
        Text('${t('Ukupno')}: $amount KM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (!lot.street)
          Text(t('Napomena: garaže u stvarnosti naplaćuju po izlasku uz ulaznu kartu; ovo prikazuje kako bi plaćanje izgledalo uz saradnju s operatorom.'), style: muted(context, size: 11)),
        const SizedBox(height: 8),
        FilledButton(onPressed: doPay, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: Text(t('Plati'))),
        if (payResult != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(payResult!)),
        if (app.ticket != null) TextButton(onPressed: app.testWarn, child: Text(t('Testiraj upozorenje (za 10 s)'))),
        if (lot.street)
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://parking-sarajevo.ba/'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: Text(t('Stvarno plaćanje: Parking Sarajevo')),
          ),
      ]),
    );
  }

  Widget rowsPanel(String title, List<List<String>> rows, String note, String source) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(t(r[0]))),
              const SizedBox(width: 10),
              Flexible(child: Text(t(r[1]), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),
        if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note, style: muted(context))),
        if (source.isNotEmpty) Text(source, style: muted(context, size: 11)),
      ]),
    );
  }

  Widget pricesTab() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (lot.prices.isEmpty)
        Panel(child: Text(t('Cijena nije javno objavljena. Provjeriti kod operatera objekta.')))
      else
        rowsPanel(t('Cijene'), lot.prices, lot.priceNote, lot.priceSource ?? kRadSource),
      if (lot.hasPay) payPanel(),
    ]);
  }

  // ---------------- INFO ----------------
  Widget infoTab() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (lot.hours.isEmpty)
        Panel(child: Text(t('Radno vrijeme nije pronađeno. Provjeriti na licu mjesta.')))
      else
        rowsPanel(t('Radno vrijeme'), lot.hours, lot.hoursNote, ''),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Vrsta'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(lot.type),
        ]),
      ),
      if (lot.near.isNotEmpty)
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🧭 ${t('U blizini')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            for (final n in lot.near)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${n.icon} ${n.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(n.text, style: muted(context)),
                ]),
              ),
            if (lot.nearNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(lot.nearNote, style: muted(context, size: 11))),
          ]),
        ),
    ]);
  }
}
