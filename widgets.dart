import 'package:flutter/material.dart';
import 'app_state.dart';
import 'data.dart';

const Color kBg = Color(0xFF07331A);
const Color kCard = Color(0xFF0E4A25);
const Color kLime = Color(0xFFC8FC84);
const Color kText = Color(0xFFECFFD2);
const Color kDarkGreen = Color(0xFF09401A);
const Color kFree = Color(0xFF3FCF74);
const Color kYellow = Color(0xFFF2C230);
const Color kRed = Color(0xFFEF5B5B);
const Color kOrange = Color(0xFFF08A00);
const Color kOnLime = Color(0xFF06301A);

ThemeData brandTheme(bool light) {
  final ColorScheme cs = light
      ? ColorScheme.light(
          primary: const Color(0xFF1B7F3B),
          onPrimary: Colors.white,
          secondary: const Color(0xFF2E9E5B),
          surface: Colors.white,
          onSurface: const Color(0xFF10281A),
        )
      : ColorScheme.dark(
          primary: kLime,
          onPrimary: kOnLime,
          secondary: kFree,
          surface: kCard,
          onSurface: kText,
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: light ? const Color(0xFFEEF3EF) : kBg,
  );
}

TextStyle muted(BuildContext c, {double size = 12.5}) =>
    TextStyle(fontSize: size, color: Theme.of(c).colorScheme.onSurface.withAlpha(165));

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? cs.onSurface.withAlpha(28)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

class Blink extends StatefulWidget {
  final Widget child;
  const Blink({super.key, required this.child});
  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_c), child: widget.child);
}

String lvT(Lot l, int lvl) => l.levels.length > 1 ? 'nivo -${lvl + 1}, ' : '';

String spInfo(Lot l) {
  final a = <String>[];
  if (l.ev.isNotEmpty) a.add('⚡ ${l.freeOf(l.ev)}/${l.ev.length}');
  if (l.inv.isNotEmpty) a.add('♿ ${l.freeOf(l.inv)}/${l.inv.length}');
  final n = app.leaveN(l);
  if (n > 0) a.add('🟠 $n ${t('se oslobađa')}');
  a.add(l.stale
      ? '⚠️ ${t('podaci nisu svježi')} (${DateTime.now().difference(l.updated).inMinutes} min)'
      : '● ${t('uživo')}');
  return a.join(' · ');
}

int? costFor(Lot l, int h) {
  if (l.priceFor == null) return null;
  var c = l.priceFor!(h);
  if (l.daily != null && c > l.daily!) c = l.daily!;
  return c;
}
