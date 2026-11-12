import 'package:flutter/material.dart';
import 'app_state.dart';
import 'data.dart';
import 'detail.dart';
import 'widgets.dart';

class MeTab extends StatefulWidget {
  const MeTab({super.key});
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  int calcHours = 4;
  int ecoUsers = 1000;

  Widget section(String keyName, String title, String sub, List<Widget> children) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(keyName),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(sub, style: muted(context)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget box(String big, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(big, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, textAlign: TextAlign.center, style: muted(context, size: 11)),
        ]),
      ),
    );
  }

  Widget eco() {
    final trips = ecoSeed + app.etrips;
    final m = trips * ecoMin;
    final co = m / 60 * ecoSpeed * ecoKg;
    final tr = co / ecoTree * 100;
    final per = ecoMin / 60 * ecoSpeed * ecoKg;
    final proj = ecoUsers * ecoWeek * 52 * per / 1000;
    return section('eco', '🌱 ${t('Zeleni vozač')}', '${fm(co, 1)} kg CO₂ ${t('manje')}', [
      Text('${t('Ove sedmice · primjer + tvoje navigacije u ovoj demo sesiji')} ($trips ${t('dolazaka')})', style: muted(context)),
      Row(children: [
        box('⏱ $m min', t('manje kruženja')),
        box('💨 ${fm(co, 1)} kg', t('manje CO₂')),
        box('🌳 ≈${tr.round()}%', t('godišnje apsorpcije jednog stabla')),
      ]),
      const SizedBox(height: 8),
      Text(
          '${t('Zahvaljujući navigaciji direktno na slobodno mjesto uštedjeli ste oko')} $m ${t('minuta kruženja i smanjili emisiju CO₂ za oko')} ${fm(co, 1)} kg.'),
      const SizedBox(height: 10),
      Text(t('Kako računamo (pretpostavke)'), style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(
          '• ${t('Bez aplikacije')}: $ecoMin min ${t('dodatnog kruženja po dolasku (pretpostavka)')}\n'
          '• ${t('Brzina kruženja')}: ${ecoSpeed.round()} km/h\n'
          '• ${t('Emisija')}: ${fm(ecoKg, 2)} kg CO₂ ${t('po km')}\n'
          '• ${t('Jedno stablo upije oko')} ${ecoTree.round()} kg CO₂ ${t('godišnje (okvirno)')}\n'
          '• ${t('To je procjena, ne mjerenje: za izvještaj treba mjeriti stvarno vrijeme traženja mjesta i uporediti s grupom koja ne koristi aplikaciju.')}',
          style: muted(context)),
      Row(children: [
        Text(t('Projekcija za'), style: muted(context)),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: ecoUsers,
          items: [for (final u in [100, 1000, 5000]) DropdownMenuItem(value: u, child: Text('$u ${t('korisnika')}'))],
          onChanged: (v) => setState(() => ecoUsers = v ?? 1000),
        ),
      ]),
      Text('≈ ${fm(proj, proj < 10 ? 1 : 0)} t CO₂ ${t('godišnje manje')} ($ecoWeek ${t('dolazaka sedmično po korisniku')}). ${t('Projekcija, ne izmjereni podatak.')}', style: muted(context)),
    ]);
  }

  Widget carSection() {
    final r = app.res;
    final c = app.car;
    String sub;
    if (r != null) {
      sub = t('rezervacija aktivna');
    } else if (c != null) {
      sub = '${app.lotById(c.lotId).short} · ${t('mjesto')} ${c.k + 1}';
    } else {
      sub = t('nema spašenog auta');
    }
    final children = <Widget>[];
    if (r != null) {
      final l = app.lotById(r.lotId);
      children.add(Panel(
        border: kYellow,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔒 ${t('Rezervacija')}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${l.name} · ${lvT(l, r.lvl)}${t('mjesto')} ${r.k + 1}', style: muted(context)),
              Text('${t('Čuvamo do')} ${hhmm(r.hold)} · ${r.plate}', style: muted(context)),
            ]),
          ),
          TextButton(onPressed: app.cancelRes, child: Text(t('Otkaži'))),
        ]),
      ));
    }
    if (app.reports.isNotEmpty || app.points > 0) {
      final pend = app.reports.where((x) => !x.confirmed).length * 10;
      children.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('⭐ ${t('Bodovi')}: ${app.points}${pend > 0 ? '  (${t('na provjeri')}: +$pend)' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(t('Moje prijave'), style: muted(context)),
          for (final x in app.reports)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x.lot}, ${x.where}'),
                    Text(t(x.reason), style: muted(context)),
                  ]),
                ),
                x.confirmed
                    ? Text('✔ ${t('Potvrđeno')}', style: const TextStyle(color: kFree, fontWeight: FontWeight.bold))
                    : OutlinedButton(onPressed: () => app.confirmReport(x), child: Text(t('Simuliraj potvrdu'))),
              ]),
            ),
        ]),
      ));
    }
    if (c != null) {
      final l = app.lotById(c.lotId);
      children.add(Panel(
        border: Theme.of(context).colorScheme.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(lot: l))),
        child: Row(children: [
          const Text('🚗', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Moj auto'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${l.name} · ${lvT(l, c.lvl)}${t('mjesto')} ${c.k + 1}', style: muted(context)),
            ]),
          ),
          Text(t('Prikaži'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ));
    } else {
      children.add(Text(t('Nema spašenog auta. Otvori objekat, dodirni mjesto na tlocrtu i pritisni „Spasi moju lokaciju“.'), style: muted(context)));
    }
    return section('car', '🚗 ${t('Moj auto')}', sub, children);
  }

  Widget calc() {
    final rows = <MapEntry<String, int>>[];
    for (final l in app.lots) {
      final c = costFor(l, calcHours);
      if (c != null) rows.add(MapEntry(l.name, c));
    }
    rows.sort((a, b) => a.value.compareTo(b.value));
    final best = rows.isEmpty ? '-' : rows.first.key.split(' ').first;
    return section('calc', '🧮 ${t('Kalkulator cijena')}', '$calcHours h · ${t('najjeftinije')}: $best', [
      Row(children: [
        Text(t('Planiram ostati'), style: muted(context)),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: calcHours,
          items: [for (final h in [1, 2, 3, 4, 5, 6, 8, 10, 12]) DropdownMenuItem(value: h, child: Text('$h h'))],
          onChanged: (v) => setState(() => calcHours = v ?? 4),
        ),
      ]),
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text('${i == 0 ? '✅ ' : ''}${rows[i].key}')),
            Text('${rows[i].value} KM', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
      const SizedBox(height: 6),
      Text(t('Dnevne tarife bez promocija (npr. besplatni sati uz račun). Ulični parking se ne naplaćuje nedjeljom i van radnog vremena. Ciglane nisu uključene jer nemaju poznatu satnicu.'), style: muted(context, size: 11)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) => ListView(padding: const EdgeInsets.all(12), children: [eco(), carSection(), calc()]),
    );
  }
}
