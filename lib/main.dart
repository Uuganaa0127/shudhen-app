import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reminders.dart';
import 'session.dart';
import 'camera_coach.dart';
import 'connection/controller.dart';
import 'connection/gate.dart';
import 'connection/device_zone.dart';
import 'package:uuid/uuid.dart';
import 'kid_home.dart';

const ink = Color(0xFF183E38);
const green = Color(0xFF257A64);
const cream = Color(0xFFFFF9EE);
const names = ['Дээд зүүн', 'Дээд баруун', 'Доод зүүн', 'Доод баруун'];
bool isNightTime(DateTime time) => time.hour >= 19 || time.hour < 7;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToothTime());
}

class ToothTime extends StatelessWidget {
  final CareController? controller;
  const ToothTime({super.key, this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Шүдхэн',
    locale: const Locale('mn'),
    supportedLocales: const [Locale('mn')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: ConnectionGate(
      controller: controller,
      home: (care) => Home(key: ValueKey(care.connection!.scope), care: care),
    ),
  );
}

class Home extends StatefulWidget {
  final CareController care;
  const Home({super.key, required this.care});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  SharedPreferences? prefs;
  CareController get care => widget.care;
  final reminders = Reminders();
  bool alertOpen = false, brushing = false, opening = false;
  String? error, lastAlert;
  String careSessionId = const Uuid().v4();
  DateTime? sessionStarted;
  String sessionZone = 'UTC';
  bool flossed = false;
  Future<void>? checkpointTask;
  Future<void> sessionWrites = Future.value();
  Future<void> serializeSession(Future<void> Function() action) {
    final task = sessionWrites.then((_) => action());
    sessionWrites = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  bool settingsOpen = false;
  List<Map<String, dynamic>> reminderTimes = [];
  bool updatingReminders = false;
  DateTime currentTime = DateTime.now();
  bool get night => isNightTime(currentTime);
  Timer? ticker;
  BrushingSession session = BrushingSession();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs!.getString('reminderTimes:${care.connection!.scope}');
      reminderTimes = saved == null
          ? []
          : (jsonDecode(saved) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      if (!mounted) return;
      setState(() {});
      try {
        final launched = await reminders.initialize(() {
          if (mounted) showAlert();
        });
        if (reminders.supported) await reminders.schedule(reminderTimes);
        if (launched && mounted) showAlert();
      } catch (_) {
        if (mounted) setState(() => error = 'Төхөөрөмжийн сануулга боломжгүй.');
      }
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now();
        if (now.minute != currentTime.minute || now.hour != currentTime.hour) {
          setState(() => currentTime = now);
        }
        if (brushing && now.second % 5 == 0) unawaited(checkpoint());
        final key =
            '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
        if (!brushing &&
            lastAlert != key &&
            reminderTimes.any(
              (r) =>
                  r['enabled'] == true &&
                  r['hour'] == now.hour &&
                  r['minute'] == now.minute,
            )) {
          lastAlert = key;
          showAlert();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Тохиргоог нээж чадсангүй. Аппаа дахин нээнэ үү.',
        );
      }
    }
  }

  Map<String, dynamic> snapshot({
    List<Duration?>? times,
    bool completed = false,
    bool? withFloss,
  }) {
    final values = times ?? List.generate(4, session.elapsedAt);
    return {
      'id': careSessionId,
      'startedAt': sessionStarted!.toUtc().toIso8601String(),
      'endedAt': DateTime.now().toUtc().toIso8601String(),
      'timeZone': sessionZone,
      'status': completed ? 'COMPLETED' : 'INTERRUPTED',
      'sections': [
        for (int i = 0; i < 4; i++)
          if (values[i] != null && values[i]!.inMilliseconds > 0)
            {'index': i, 'activeMs': values[i]!.inMilliseconds},
      ],
      'flossed': withFloss ?? flossed,
    };
  }

  Future<void> checkpoint() async {
    if (!brushing ||
        sessionStarted == null ||
        session.complete ||
        checkpointTask != null) {
      return;
    }
    final task = serializeSession(() async {
      if (sessionStarted != null && !session.complete) {
        await care.saveSession(snapshot(), finalized: false);
      }
    });
    checkpointTask = task;
    try {
      await task;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Бүртгэл хадгалагдсангүй. Утасны сул зайг шалгана уу.',
        );
      }
    } finally {
      checkpointTask = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => currentTime = DateTime.now());
    } else {
      session.pause();
      unawaited(checkpoint());
    }
  }

  @override
  void dispose() {
    session.pause();
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> showAlert() async {
    if (alertOpen || brushing || opening || !mounted) return;
    alertOpen = true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Бяцхан арчилгаа, том инээмсэглэл. ✨'),
        content: const Text(
          'Шүдээ угаах цаг боллоо! Шүдхэн найз чинь хүлээж байна.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Дараа'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('За, шүдээ угаая'),
          ),
        ],
      ),
    );
    alertOpen = false;
    if (yes == true && mounted) {
      await openCamera();
    }
  }

  Future<void> openCamera() async {
    if (opening || brushing) return;
    opening = true;
    try {
      await sessionWrites;
      // A failed final commit from the previous visit must be retried first.
      if (sessionStarted != null) {
        await care.saveSession(
          snapshot(completed: session.complete),
          finalized: true,
        );
      }
      session = BrushingSession();
      careSessionId = const Uuid().v4();
      sessionStarted = DateTime.now();
      sessionZone = CareController.validZone(await deviceTimeZone());
      flossed = false;
      await care.saveSession(snapshot(), finalized: false);
      if (!mounted) return;
      setState(() {
        brushing = true;
        error = null;
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraCoach(
            session: session,
            age: care.connection!.ageAt(DateTime.now()),
            onFinish: finish,
            onFloss: recordFloss,
            autoStart: true,
          ),
        ),
      );
      session.pause();
      if (mounted) setState(() => brushing = false);
      await sessionWrites;
      await care.saveSession(
        snapshot(completed: session.complete),
        finalized: true,
      );
      sessionStarted = null;
      unawaited(care.sync());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Бүртгэлийг хадгалж чадсангүй. Утасны сул зайг шалгаад дахин оролдоно уу.',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }
    } finally {
      opening = false;
      if (mounted) setState(() => brushing = false);
    }
  }

  Future<void> recordFloss() => serializeSession(() async {
    session.pause();
    await care.saveSession(snapshot(withFloss: true), finalized: false);
    flossed = true;
  });

  Future<void> finish() => serializeSession(() async {
    session.pause();
    if (session.complete ||
        session.watch.elapsed < const Duration(seconds: 1)) {
      return;
    }
    final values = List<Duration?>.generate(4, session.elapsedAt);
    final complete = session.completedCount + 1 == 4;
    // Commit to durable storage before mutating the stopwatch/session UI.
    await care.saveSession(
      snapshot(times: values, completed: complete),
      finalized: complete,
    );
    session.finishSection();
    if (mounted) setState(() {});
    if (complete) unawaited(care.sync());
  });

  String duration(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  Future<void> introduction() async {
    session.pause();
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Шүдхэн найзтайгаа танилцаарай ✨'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Бэлтгээрэй',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Сойз, оогоо бэлдээд толины өмнө тухтай байрлаарай.'),
              SizedBox(height: 16),
              Text(
                '2. Хэсгээ сонгоорой',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Дээд зүүн, дээд баруун, доод зүүн эсвэл доод баруун хэсгээ сонгоорой. Шар өнгөтэй хэсэг нь таны сонголт.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Найзтайгаа угаагаарай',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Камераа асаагаад сойзоо зөөлөн тойруулж угаагаарай. Сонгосон хэсгийн гадна, дотор, зажлах гадаргууг цэвэрлээрэй.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Дуусгаад тэмдэглээрэй',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Хэсэг бүрийг 30 секунд угаагаад Дуусгах товчийг дараарай. Дөрвөн хэсгээ дуусгавал од авна! Хэсэг солиход хугацаа хадгалагдана.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Ойлголоо!'),
          ),
        ],
      ),
    );
  }

  Widget heading(String eyebrow, String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: green,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        sub,
        style: const TextStyle(
          color: Color(0xFF6F817B),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    ],
  );
  Widget panel(Widget child, {Color color = Colors.white}) => Material(
    color: color,
    borderRadius: BorderRadius.circular(26),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
  Future<void> relink() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LinkScreen(care: care)),
    );
  }

  Widget syncStatus() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            care.needsRelink
                ? 'Эмнэлэгтэй дахин холбоно уу'
                : care.syncing
                ? 'Эмнэлэгт дамжуулж байна…'
                : care.pending > 0
                ? '${care.pending} угаалт дамжуулахыг хүлээж байна'
                : 'Бүртгэл утсанд хадгалагдсан',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (care.lastSync != null)
            Text(
              'Сүүлд дамжуулсан: ${care.lastSync!.toLocal().toString().substring(0, 16)}',
            ),
          if (care.blocked > 0)
            Text(
              '${care.blocked} бүртгэлийг сервер хүлээн аваагүй. Бүртгэл устахгүй; эмнэлэгтэйгээ холбогдоно уу.',
            ),
          if (care.syncMessage != null) Text(care.syncMessage!),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.deepOrange)),
          TextButton(
            onPressed: care.syncing
                ? null
                : care.needsRelink
                ? relink
                : () => care.sync(),
            child: Text(care.needsRelink ? 'Дахин холбох' : 'Одоо дамжуулах'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (prefs == null) {
      return Scaffold(
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Text(error!),
        ),
      );
    }
    if (!settingsOpen) {
      return KidHome(
        name: care.connection!.name,
        stars: care.stars,
        dates: care.dates,
        gift: care.rewards,
        night: night,
        syncStatus: syncStatus(),
        onBrush: openCamera,
        onSettings: () {
          if (!opening) setState(() => settingsOpen = true);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тохиргоо'),
        leading: IconButton(
          tooltip: 'Нүүр',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => settingsOpen = false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                syncStatus(),
                const SizedBox(height: 16),
                settingsContent(),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Хэрхэн угаах вэ?'),
                  onTap: introduction,
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Шинэ урилгаар дахин холбох'),
                  onTap: relink,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Гарах'),
                  subtitle: const Text(
                    'Илгээгээгүй угаалт утсанд хадгалагдана.',
                  ),
                  onTap: () async {
                    try {
                      try {
                        if (reminders.supported) {
                          await reminders.plugin.cancelAll();
                        }
                      } catch (_) { /* Notification errors must not prevent logout. */ }
                      await care.disconnect();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Гарч чадсангүй. Дахин оролдоно уу.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget settingsContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Угаах сануулга',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (reminderTimes.isEmpty)
              const Text('Сануулга алга. Өөрт тохирох цагаа нэмээрэй.'),
            ...List.generate(reminderTimes.length, (i) {
              final r = reminderTimes[i];
              return Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        TimeOfDay(
                          hour: r['hour'] as int,
                          minute: r['minute'] as int,
                        ).format(context),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text('Өдөр бүр · дарж засах'),
                      onTap: updatingReminders ? null : () => editReminder(i),
                    ),
                  ),
                  Switch(
                    value: r['enabled'] == true,
                    onChanged: updatingReminders
                        ? null
                        : (value) {
                            final updated = reminderTimes
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                            updated[i]['enabled'] = value;
                            saveReminders(updated);
                          },
                  ),
                  IconButton(
                    tooltip: 'Сануулга устгах',
                    onPressed: updatingReminders
                        ? null
                        : () {
                            final updated =
                                reminderTimes
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList()
                                  ..removeAt(i);
                            saveReminders(updated);
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: updatingReminders ? null : () => editReminder(null),
              icon: const Icon(Icons.add_alarm),
              label: Text(
                updatingReminders ? 'Хадгалж байна…' : 'Сануулга нэмэх',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reminders.supported
                  ? '30 хүртэл хоногийн, хамгийн ихдээ 60 сануулга төлөвлөж, апп нээх бүрд шинэчилнэ.'
                  : 'Вэб дээр апп нээлттэй үед сануулга гарна.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF718078)),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> editReminder(int? index) async {
    final r = index == null ? null : reminderTimes[index];
    final time = await showTimePicker(
      context: context,
      initialTime: r == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: r['hour'] as int, minute: r['minute'] as int),
    );
    if (time == null || !mounted) return;
    if (reminderTimes.asMap().entries.any(
      (e) =>
          e.key != index &&
          e.value['hour'] == time.hour &&
          e.value['minute'] == time.minute,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ цагт сануулга аль хэдийн байна.')),
      );
      return;
    }
    final updated = reminderTimes
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final entry = <String, dynamic>{
      'hour': time.hour,
      'minute': time.minute,
      'enabled': r == null ? true : r['enabled'],
    };
    if (index == null) {
      updated.add(entry);
    } else {
      updated[index] = entry;
    }
    updated.sort(
      (a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int)).compareTo(
        (b['hour'] as int) * 60 + (b['minute'] as int),
      ),
    );
    await saveReminders(updated);
  }

  Future<void> saveReminders(List<Map<String, dynamic>> updated) async {
    if (updatingReminders) return;
    setState(() => updatingReminders = true);
    try {
      if (reminders.supported && !await reminders.schedule(updated)) {
        throw StateError('Allow notifications in device settings');
      }
      if (!await prefs!.setString(
        'reminderTimes:${care.connection!.scope}',
        jsonEncode(updated),
      )) {
        throw StateError('Could not save');
      }
      if (mounted) setState(() => reminderTimes = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сануулгыг хадгалж чадсангүй. Мэдэгдлийн зөвшөөрлөө шалгаад дахин оролдоно уу.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => updatingReminders = false);
    }
  }
}
