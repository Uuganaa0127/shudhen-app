import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'camera_feed_native.dart' if (dart.library.html) 'camera_feed_web.dart';
import 'motion_check.dart';
import 'session.dart';
import 'teeth_art.dart';
import 'floss_icon.dart';

const filterIcons = ['✨', '🐱', '👑', '🌈', '🦄', '🐼', '🦋', '🚀', '🐠', '🌸'];
const filterNames = [
  'Гялбаа',
  'Муужгай',
  'Титэм',
  'Солонго',
  'Ганц эвэрт',
  'Панда',
  'Эрвээхэй',
  'Сансар',
  'Загасхан',
  'Цэцэг'
];

class CameraCoach extends StatefulWidget {
  final Future<void> Function()? onFloss;
  final bool autoStart;
  final int? age;
  final BrushingSession session;
  final Future<void> Function() onFinish;
  const CameraCoach(
      {super.key,
      required this.session,
      required this.onFinish,
      this.autoStart = false,
      this.age,
      this.onFloss});
  @override
  State<CameraCoach> createState() => _CameraCoachState();
}

class _CameraCoachState extends State<CameraCoach>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const names = ['Дээд зүүн', 'Дээд баруун', 'Доод зүүн', 'Доод баруун'];
  bool active = false, finishing = false;
  bool flossOpen = false;
  int filter = 0;
  String status = 'Бэлэн бол эхлээрэй';
  MotionCheck check = MotionCheck();
  DateTime? lastFrame;
  Timer? timer;
  int lastShownSecond = -1;
  late final AnimationController animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  BrushingSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    active = widget.autoStart;
    if (active) status = 'Камер холбож байна…';
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (session.watch.isRunning &&
          (lastFrame == null ||
              DateTime.now().difference(lastFrame!).inMilliseconds > 600)) {
        session.pause();
        status = 'Камерын дүрс тасарлаа — хугацаа зогслоо';
      }
      final second = session.watch.elapsed.inSeconds;
      if (active && second != lastShownSecond) {
        lastShownSecond = second;
        setState(() {});
      }
    });
  }

  void resetMotion() {
    session.pause();
    check = MotionCheck();
    lastFrame = null;
  }

  void frame(List<int> pixels) {
    if (!mounted || !active || finishing || flossOpen) return;
    setState(() {
      lastFrame = DateTime.now();
      status = check.inspect(pixels);
      check.isMoving ? session.start() : session.pause();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) resetMotion();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() {
        active = false;
        status = 'Камер түр зогслоо. Камер асаах товчийг дарна уу.';
      });
    }
  }

  @override
  void dispose() {
    session.pause();
    timer?.cancel();
    animation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String clock(Duration time) =>
      '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';
  Future<void> completeSection() async {
    if (finishing) return;
    setState(() {
      finishing = true;
      resetMotion();
    });
    await widget.onFinish();
    if (!mounted) return;
    if (session.complete) {
      setState(() => active = false);
      await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('🌟 Дөрвөн хэсгээ угааж дууслаа!'),
                  content: Text(
                      'Та инээмсэглэлийн од авлаа. Нийт идэвхтэй хугацаа: ${clock(session.total)}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Мундаг байна!'))
                  ]));
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      finishing = false;
      status = 'Шинэ хэсэг — сойзоо хөдөлгөж хугацааг эхлүүлээрэй';
    });
  }

  Future<void> floss() async {
    if (flossOpen) return;
    resetMotion();
    setState(() => flossOpen = true);
    final done = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('🦷 Шүдний утас'),
                content:
                    const Column(mainAxisSize: MainAxisSize.min, children: [
                  FlossIcon(size: 80),
                  SizedBox(height: 12),
                  Text('Аав, ээжтэйгээ хамт хийгээрэй.')
                ]),
                actions: [
                  IconButton(
                      tooltip: 'Арай дуусаагүй',
                      onPressed: () => Navigator.pop(c, false),
                      icon: const Icon(Icons.close_rounded, size: 30)),
                  IconButton.filled(
                      tooltip: 'Утас хэрэглэж дууслаа',
                      onPressed: () => Navigator.pop(c, true),
                      icon: const Icon(Icons.check_rounded, size: 36))
                ]));
    if (mounted) {
      setState(() {
        flossOpen = false;
        resetMotion();
      });
    }
    if (done == true && mounted) {
      try {
        await widget.onFloss?.call();
        if (mounted) {
          setState(() => status =
              'Утас хэрэглэснийг бүртгэлээ. Бэлэн бол шүдээ угаагаарай.');
        }
      } catch (_) {
        if (mounted) {
          setState(() => status = 'Бүртгэж чадсангүй. Дахин оролдоно уу.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('🦷 Угаацгаая!'), actions: [
          IconButton(
              tooltip: 'Тусламж',
              icon: const Icon(Icons.help_outline),
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                          title: const Text('Хэрхэн тоглох вэ?'),
                          content: const Text('''① Шүдний хэсгээ сонго.
② Сойзоо хөдөлгө — хугацаа тоолно.
③ Дуусгах товчийг дар.

Хөдөлгөөнөөр хугацаа хэмжинэ; угаалтын чанарыг батлахгүй. Нүүрний хүрээ нь байрлал заах зориулалттай. Камерын дүрс хадгалахгүй, илгээхгүй.'''),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Ойлголоо'))
                          ])))
        ]),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton.icon(
                  onPressed: !finishing &&
                          !session.complete &&
                          session.watch.elapsed.inSeconds >= 1
                      ? completeSection
                      : null,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      backgroundColor: const Color(0xFF7358C8),
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: Text(session.section == 3 ? 'Дуусгах 🌟' : 'Дуусгах →',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            key: const ValueKey('camera-external-timer'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFE6F1DD),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(names[session.section],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(session.watch.isRunning
                        ? '▶ Угааж байна'
                        : '⏸ Сойзоо хөдөлгөөрэй'),
                  ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                    '⏳ ${(30 - session.watch.elapsed.inSeconds).clamp(0, 30)} сек',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('Үлдсэн'),
                Text('🪥 ${session.watch.elapsed.inSeconds} сек угаасан',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
              height: 245,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: Color(0xFF183E38)),
                    if (active)
                      CameraFeed(
                          onFrame: frame,
                          onError: (message) {
                            if (mounted) {
                              setState(() {
                                resetMotion();
                                status = message;
                                active = false;
                              });
                            }
                          }),
                    if (!active)
                      const Center(
                          child: Icon(Icons.videocam_outlined,
                              color: Colors.white54, size: 64)),
                    IgnorePointer(
                        child: AnimatedBuilder(
                            animation: animation,
                            builder: (_, __) => CustomPaint(
                                painter: FaceGuide(
                                    animation.value,
                                    session.section,
                                    session.watch.isRunning,
                                    filter)))),
                    Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                            '${names[session.section]} · ${session.watch.isRunning ? "Тоолж байна" : "Түр зогссон"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.black54))),
                  ]))),
          const SizedBox(height: 12),
          const Text('👇 Хэсгээ сонгоорой',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
              height: 135,
              child: LayoutBuilder(
                  builder: (context, bounds) => GestureDetector(
                        key: const ValueKey('camera-teeth-selector'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (finishing) return;
                          final scale = math.min(
                              bounds.maxWidth / 340, bounds.maxHeight / 230);
                          final x =
                              (details.localPosition.dx - bounds.maxWidth / 2) /
                                  scale;
                          final y = (details.localPosition.dy -
                                  bounds.maxHeight / 2) /
                              scale;
                          if (x.abs() > 157 || y < -95 || y > 85) return;
                          final i = (y < 0 ? 0 : 2) + (x < 0 ? 1 : 0);
                          if (session.times[i] != null) return;
                          setState(() {
                            resetMotion();
                            session.select(i);
                            status =
                                'Хэсгийг сонголоо — сойзоо хөдөлгөж эхлээрэй';
                          });
                        },
                        child: CustomPaint(
                            painter: TeethPainter(
                                active: session.section,
                                night: DateTime.now().hour >= 19 ||
                                    DateTime.now().hour < 7,
                                done: session.times
                                    .map((t) => t != null)
                                    .toList()),
                            child: const SizedBox.expand()),
                      ))),
          const Text(
              'Урдаас харсан зураг · таны зүүн тал зурагт баруун талд байна',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  filterIcons.length,
                  (i) => Tooltip(
                      message: filterNames[i],
                      child: Semantics(
                          label: filterNames[i],
                          selected: filter == i,
                          child: ChoiceChip(
                              label: Text(filterIcons[i],
                                  style: const TextStyle(fontSize: 30)),
                              showCheckmark: false,
                              padding: const EdgeInsets.all(10),
                              selectedColor: const Color(0xFFE4D9FF),
                              selected: filter == i,
                              onSelected: (_) =>
                                  setState(() => filter = i)))))),
          const SizedBox(height: 12),
          if (!active) Text(status, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(
                tooltip: active ? 'Камер унтраах' : 'Камер асаах',
                iconSize: 36,
                style: IconButton.styleFrom(minimumSize: const Size(72, 72)),
                onPressed: () => setState(() {
                      resetMotion();
                      active = !active;
                      status = active
                          ? 'Камер холбож байна…'
                          : 'Камер унтарсан — хугацаа түр зогссон';
                    }),
                icon: Icon(active
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded)),
            const SizedBox(width: 20),
            IconButton.filledTonal(
                tooltip: 'Шүдний утас',
                style: IconButton.styleFrom(minimumSize: const Size(72, 72)),
                onPressed: floss,
                icon: const FlossIcon(size: 40)),
          ]),
          const SizedBox(height: 12),
          const Text('🎯 30 сек × 4 = 120 сек', textAlign: TextAlign.center),
          Text(
              widget.age == null
                  ? 'Нас бүрт 2 минут · Том хүнтэй хамт угаагаарай'
                  : widget.age! < 3
                      ? '👨‍👧 ${widget.age} нас · Эцэг эх нь угааж өгнө'
                      : widget.age! < 7
                          ? '👨‍👧 ${widget.age} нас · Том хүнтэй хамт угаагаарай'
                          : '🪥 ${widget.age} нас · Том хүнээр шалгуулаарай',
              textAlign: TextAlign.center),
        ])),
      );
}

class FaceGuide extends CustomPainter {
  final double phase;
  final int section;
  final bool moving;
  final int filter;
  FaceGuide(this.phase, this.section, this.moving, this.filter);
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFFD67D),
      const Color(0xFFFFA7CB),
      const Color(0xFFB59BFF),
      const Color(0xFF84DEDD),
      const Color(0xFFE3AEFF),
      const Color(0xFFAEE2BA),
      const Color(0xFFB6DAFF),
      const Color(0xFFA99BEF),
      const Color(0xFF85DDEA),
      const Color(0xFFFFB8D0)
    ];
    final tint = colors[filter];
    canvas.drawRect(
        Offset.zero & size, Paint()..color = tint.withValues(alpha: .08));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(7), const Radius.circular(24)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = tint.withValues(alpha: .7));
    final center = Offset(size.width / 2, size.height / 2);
    final width = math.min(size.width * .66, 225.0);
    final oval = Rect.fromCenter(center: center, width: width, height: 245);
    void sticker(String symbol, Offset position, double fontSize) {
      final text = TextPainter(
          text: TextSpan(text: symbol, style: TextStyle(fontSize: fontSize)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, position - Offset(text.width / 2, text.height / 2));
    }

    for (int i = 0; i < 10; i++) {
      final y = (i / 10 * size.height + phase * 50) % size.height;
      sticker(
          filterIcons[filter], Offset(i.isEven ? 20 : size.width - 20, y), 23);
    }
    final bob = math.sin(phase * math.pi * 2) * 5;
    if (filter == 1) {
      sticker('🐱', center + Offset(0, -105 + bob), 52);
      for (final side in [-1, 1]) {
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(
              center + Offset(side * 42, 22 + i * 7),
              center + Offset(side * 86, 22 + i * 14),
              Paint()
                ..color = const Color(0xFFFFCEE3)
                ..strokeWidth = 3);
        }
      }
    } else if (filter == 2) {
      sticker('👑', center + Offset(0, -105 + bob), 66);
      sticker('💎', center + const Offset(-105, 30), 28);
      sticker('💎', center + const Offset(105, 30), 28);
    } else if (filter == 3) {
      sticker('🌈', center + Offset(0, -100 + bob), 70);
      sticker('☁️', center + const Offset(-105, 45), 34);
      sticker('☁️', center + const Offset(105, 45), 34);
    } else if (filter >= 4) {
      sticker(filterIcons[filter], center + Offset(0, -92 + bob), 58);
      for (int i = 0; i < 8; i++) {
        final x = (i * size.width / 7 + phase * 28) % size.width;
        final y = i.isEven ? 25.0 + bob : size.height - 28 - bob;
        sticker(filterIcons[filter], Offset(x, y), 24 + (i % 3) * 3.0);
      }
      sticker(['💖', '🎋', '🌼', '⭐', '🫧', '🌷'][filter - 4],
          center + const Offset(-95, 42), 30);
      sticker(['💖', '🎋', '🌼', '⭐', '🫧', '🌷'][filter - 4],
          center + const Offset(95, 42), 30);
    } else {
      for (int i = 0; i < 6; i++) {
        final a = phase * math.pi * 2 + i * math.pi / 3;
        sticker(
            '✨',
            center + Offset((width / 2 + 18) * math.cos(a), 125 * math.sin(a)),
            23);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white54;
    canvas.drawOval(oval, paint);
    // Front view: the child's left is on the right side of the picture.
    final angle = [-math.pi / 2, math.pi, 0.0, math.pi / 2][section];
    paint
      ..color = moving ? const Color(0xFF8FE4B9) : const Color(0xFFFFD67D)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(oval.inflate(5), angle + .1, math.pi / 2 - .2, false, paint);
    final a = phase * math.pi * 2;
    final dot = Offset(center.dx + (width / 2 + 12) * math.cos(a),
        center.dy + 132 * math.sin(a));
    canvas.drawCircle(
        dot, moving ? 6 : 4, Paint()..color = const Color(0xFFFFEDAD));
    final mouth =
        Rect.fromCenter(center: center, width: width * .65, height: 55);
    canvas.drawRRect(
        RRect.fromRectAndRadius(mouth, const Radius.circular(20)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant FaceGuide old) =>
      old.phase != phase ||
      old.section != section ||
      old.moving != moving ||
      old.filter != filter;
}
