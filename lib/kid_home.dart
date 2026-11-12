import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gift_progress.dart';

class KidHome extends StatefulWidget {
  final String name;
  final int stars;
  final Set<String> dates;
  final Map<String, dynamic> gift;
  final bool night;
  final VoidCallback onBrush, onSettings;
  const KidHome(
      {super.key,
      required this.name,
      required this.stars,
      required this.dates,
      required this.gift,
      required this.night,
      required this.onBrush,
      required this.onSettings});
  @override
  State<KidHome> createState() => _KidHomeState();
}

class _KidHomeState extends State<KidHome> with SingleTickerProviderStateMixin {
  late final AnimationController motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  void calendar() {
    var month = DateTime.now();
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, set) {
              final count = DateTime(month.year, month.month + 1, 0).day;
              final offset = DateTime(month.year, month.month, 1).weekday - 1;
              return AlertDialog(
                  title: Row(children: [
                    IconButton(
                        onPressed: () => set(() =>
                            month = DateTime(month.year, month.month - 1)),
                        icon: const Icon(Icons.chevron_left)),
                    Expanded(
                        child: Text('${month.year} / ${month.month}',
                            textAlign: TextAlign.center)),
                    IconButton(
                        onPressed: () => set(() =>
                            month = DateTime(month.year, month.month + 1)),
                        icon: const Icon(Icons.chevron_right))
                  ]),
                  content: SingleChildScrollView(
                      child: SizedBox(
                          width: 340,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('⭐ Дөрвөн хэсгээ дуусгасан өдөр'),
                            const SizedBox(height: 16),
                            Row(
                                children: [
                              'Да',
                              'Мя',
                              'Лх',
                              'Пү',
                              'Ба',
                              'Бя',
                              'Ня'
                            ]
                                    .map((d) => Expanded(
                                        child: Text(d,
                                            textAlign: TextAlign.center)))
                                    .toList()),
                            const SizedBox(height: 8),
                            GridView.count(
                                crossAxisCount: 7,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                children: List.generate(offset + count, (i) {
                                  if (i < offset) return const SizedBox();
                                  final d = DateTime(
                                      month.year, month.month, i - offset + 1);
                                  final done = widget.dates
                                      .contains(GiftProgress.key(d));
                                  return Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: done
                                              ? const Color(0xFFFFE199)
                                              : const Color(0xFFF2F0F7),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(done ? '⭐' : '${d.day}',
                                          style: TextStyle(
                                              color: d.isAfter(DateTime.now())
                                                  ? Colors.grey
                                                  : Colors.black87)));
                                })),
                            const SizedBox(height: 12),
                            const Text(
                                'Алгассан өдөр дарааллыг шинээр эхлүүлнэ.',
                                style: TextStyle(fontSize: 13))
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Хаах'))
                  ]);
            }));
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.gift['days'] == 30 ? 30 : 7;
    final progress = GiftProgress(widget.dates, target, DateTime.now());
    final title = widget.gift['name'] as String?;
    return Scaffold(
        backgroundColor: const Color(0xFFF7F3EB),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                        padding: EdgeInsets.all(
                            MediaQuery.sizeOf(context).width < 380 ? 16 : 24),
                        children: [
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: motion,
                              builder: (context, _) {
                                final t =
                                    MediaQuery.of(context).disableAnimations
                                        ? 0.0
                                        : motion.value * math.pi * 2;
                                return Column(children: [
                                  Row(children: [
                                    Transform.rotate(
                                      angle: math.sin(t) * .14,
                                      child: Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFE4DDF7),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        alignment: Alignment.center,
                                        child: const Text('👋',
                                            style: TextStyle(fontSize: 32)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          const Text('Сайн уу!',
                                              style: TextStyle(
                                                  color: Color(0xFF628680),
                                                  fontWeight: FontWeight.w700)),
                                          Text(widget.name,
                                              style: const TextStyle(
                                                  fontSize: 26,
                                                  height: 1.15,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF354B58))),
                                        ])),
                                    IconButton(
                                        tooltip: 'Тохиргоо',
                                        onPressed: widget.onSettings,
                                        icon: const Icon(Icons.settings_rounded,
                                            color: Color(0xFF77858A))),
                                  ]),
                                  const SizedBox(height: 20),
                                  Semantics(
                                    label: '${widget.stars} ашиглах од',
                                    child: ExcludeSemantics(
                                        child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFFFFE5A3),
                                          Color(0xFFFFF3D3)
                                        ]),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                            color: const Color(0xFFFFD16F),
                                            width: 2),
                                      ),
                                      child: Row(children: [
                                        Transform.rotate(
                                            angle: math.sin(t) * .1,
                                            child: const Text('⭐',
                                                style:
                                                    TextStyle(fontSize: 36))),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              const Text('Миний од',
                                                  style: TextStyle(
                                                      color: Color(0xFF926321),
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              AnimatedSwitcher(
                                                  duration: const Duration(
                                                      milliseconds: 350),
                                                  child: Text('${widget.stars}',
                                                      key: ValueKey(
                                                          widget.stars),
                                                      style: const TextStyle(
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Color(
                                                              0xFF735018)))),
                                            ])),
                                        ...List.generate(
                                            3,
                                            (i) => Transform.translate(
                                                  offset: Offset(
                                                      0,
                                                      math.sin(t + i * 1.3) *
                                                          3),
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 5),
                                                      child: Icon(
                                                          Icons.auto_awesome,
                                                          size: 14.0 + i * 4,
                                                          color: const Color(
                                                                  0xFFE8AE37)
                                                              .withValues(
                                                                  alpha: .5 +
                                                                      .25 *
                                                                          (1 +
                                                                              math.sin(t + i))))),
                                                )),
                                      ]),
                                    )),
                                  ),
                                ]);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                              label: 'Сойзоор угаалгаж буй инээмсэглэсэн шүд',
                              child: SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height < 650
                                          ? 220
                                          : 280,
                                  child: RepaintBoundary(
                                      child: AnimatedBuilder(
                                          animation: motion,
                                          builder: (_, __) => CustomPaint(
                                              painter: HappyTooth(
                                                  MediaQuery.of(context)
                                                          .disableAnimations
                                                      ? 0
                                                      : motion.value),
                                              child:
                                                  const SizedBox.expand()))))),
                          FilledButton.icon(
                              onPressed: widget.onBrush,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF479D95),
                                  minimumSize: const Size.fromHeight(70),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24))),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 36),
                              label: const Text('Шүдээ угаах',
                                  style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800))),
                          const SizedBox(height: 25),
                          Material(
                              color: const Color(0xFFEAE3F7),
                              borderRadius: BorderRadius.circular(26),
                              child: InkWell(
                                  onTap: calendar,
                                  borderRadius: BorderRadius.circular(26),
                                  child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              const Text('🎁',
                                                  style:
                                                      TextStyle(fontSize: 42)),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                  child: Text(
                                                      progress.remaining == 0
                                                          ? 'Бэлгийн зорилт биеллээ!'
                                                          : 'Бэлэг хүртэл ${progress.remaining} өдөр',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 22,
                                                          color: Color(
                                                              0xFF61518A)))),
                                              const Icon(
                                                  Icons.calendar_month_rounded,
                                                  color: Color(0xFF61518A))
                                            ]),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                    value: (progress.streak /
                                                            target)
                                                        .clamp(0, 1),
                                                    minHeight: 12,
                                                    backgroundColor:
                                                        Colors.white,
                                                    color: const Color(
                                                        0xFF9680C5))),
                                            const SizedBox(height: 12),
                                            Text(
                                                '${progress.streak} / $target дараалсан өдөр',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF61518A))),
                                            const SizedBox(height: 6),
                                            Text(
                                                title != null &&
                                                        title.isNotEmpty
                                                    ? title
                                                    : 'Виртуал одон',
                                                style: const TextStyle(
                                                    color: Color(0xFF61518A))),
                                            if (progress.remaining == 0)
                                              const Text(
                                                  'Эмчтэйгээ бэлгээ ярилцаарай.',
                                                  style: TextStyle(
                                                      color: Color(0xFF61518A)))
                                          ]))))
                        ])))));
  }
}

class HappyTooth extends CustomPainter {
  final double t;
  HappyTooth(this.t);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 300, size.height / 300);
    c.scale(scale, scale);
    final bob = math.sin(t * math.pi * 2) * 5;
    c.translate(0, bob);
    final p = Paint();
    p.color = const Color(0xFFE0EFE6);
    c.drawCircle(Offset.zero, 132, p);
    p.color = const Color(0xFFCBDFD4);
    c.drawOval(const Rect.fromLTWH(-75, 104, 150, 16), p);
    final tooth = Path()
      ..moveTo(0, -88)
      ..cubicTo(-110, -135, -110, -25, -75, 25)
      ..cubicTo(-62, 52, -69, 118, -37, 100)
      ..cubicTo(-16, 86, -19, 45, 0, 44)
      ..cubicTo(19, 45, 16, 86, 37, 100)
      ..cubicTo(69, 118, 62, 52, 75, 25)
      ..cubicTo(110, -25, 110, -135, 0, -88)
      ..close();
    p.color = Colors.white;
    c.drawPath(tooth, p);
    p
      ..color = const Color(0xFFA7CCC2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawPath(tooth, p);
    p.style = PaintingStyle.fill;
    p.color = const Color(0xFF355C59);
    for (final x in [-29.0, 29.0])
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, -18), width: 10, height: t > .92 ? 2 : 15),
          p);
    p.color = const Color(0xFFFFC0BC);
    c.drawOval(const Rect.fromLTWH(-55, -6, 22, 11), p);
    c.drawOval(const Rect.fromLTWH(33, -6, 22, 11), p);
    p
      ..color = const Color(0xFF355C59)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawArc(const Rect.fromLTWH(-15, -7, 30, 27), 0, math.pi, false, p);
    p.style = PaintingStyle.fill;
    c.save();
    c.translate(30 + math.sin(t * math.pi * 6) * 15, 38);
    c.rotate(-.28);
    p.color = const Color(0xFFEFAD70);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, 0, 126, 14), const Radius.circular(7)),
        p);
    p.color = const Color(0xFF79BBB3);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-38, -6, 48, 22), const Radius.circular(7)),
        p);
    p.color = Colors.white;
    for (int i = 0; i < 6; i++)
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-33 + i * 7, -18, 4, 17), const Radius.circular(2)),
          p);
    c.restore();
    p.color = Colors.white.withValues(alpha: .75);
    for (int i = 0; i < 5; i++) {
      final x = -15 + i * 15.0;
      final y = 25 - (t * 40 + i * 8) % 50;
      c.drawCircle(Offset(x, y), 4 + i % 3.0, p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(HappyTooth old) => old.t != t;
}
