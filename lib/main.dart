import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reminders.dart';
import 'session.dart';
import 'camera_coach.dart';
import 'teeth_art.dart';
import 'care_data.dart';
import 'kid_home.dart';
import 'child_name.dart';

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
  const ToothTime({super.key});
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
          textTheme: ThemeData.light()
              .textTheme
              .apply(bodyColor: ink, displayColor: ink),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 19),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none))),
      home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  SharedPreferences? prefs;
  Map<String, dynamic>? profile;
  final reminders = Reminders();
  final form = GlobalKey<FormState>();
  final first = TextEditingController();
  bool signedIn = false, saving = false, alertOpen = false, brushing = false;
  int rewards = 0, hour = 8, minute = 0;
  String? error, lastAlert;
  String careSessionId = DateTime.now().microsecondsSinceEpoch.toString();
  bool settingsOpen = false;
  bool rememberMe = true;
  bool enabled = false;
  List<Map<String, dynamic>> reminderTimes = [];
  bool updatingReminders = false;
  DateTime currentTime = DateTime.now();
  bool get night => isNightTime(currentTime);
  Timer? ticker;
  int lastStarBalance = -1;
  BrushingSession session = BrushingSession();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    ticker?.cancel();
    try {
      prefs = await SharedPreferences.getInstance();
      final store = CareData(prefs!);
      if (!store.exists('123456')) await store.addClient('123456');
      rememberMe = prefs!.getBool('rememberMe') ?? true;
      final id = prefs!.getString('activeClient');
      first.text = prefs!.getString('rememberedClient') ??
          (prefs!.containsKey('rememberMe') ? '' : '123456');
      signedIn = id != null &&
          store.exists(id) &&
          (signedIn || (prefs!.getBool('signedIn') ?? false));
      profile = signedIn ? {'first': id, 'last': ''} : null;
      rewards = signedIn ? CareStats(store.forChild(id!)).complete : 0;
      hour = 8;
      minute = 0;
      enabled = false;
      final savedReminders =
          prefs!.getString('reminderTimes:${profile?['first'] ?? 'guest'}');
      reminderTimes = savedReminders == null
          ? [
              {'hour': hour, 'minute': minute, 'enabled': enabled}
            ]
          : (jsonDecode(savedReminders) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      if (!mounted) return;
      setState(() {});
      try {
        final launched = await reminders.initialize(() {
          if (signedIn && mounted) showAlert();
        });
        if (signedIn &&
            reminders.supported &&
            reminderTimes.any((r) => r['enabled'] == true)) {
          await reminders.schedule(reminderTimes);
        }
        if (launched && signedIn && mounted) showAlert();
      } catch (_) {
        if (mounted) {
          setState(() => error =
              'Төхөөрөмжийн сануулга боломжгүй. Апп доторх сануулга ажиллана.');
        }
      }
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now();
        if (signedIn && profile != null) {
          final id = profile!['first'] as String;
          final balance = availableStars(
              id, CareStats(CareData(prefs!).forChild(id)).complete);
          if (balance != lastStarBalance)
            setState(() => lastStarBalance = balance);
        }
        if (now.minute != currentTime.minute || now.hour != currentTime.hour) {
          setState(() => currentTime = now);
        }
        final key =
            '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
        if (reminderTimes.any((r) =>
                r['enabled'] == true &&
                r['hour'] == now.hour &&
                r['minute'] == now.minute) &&
            signedIn &&
            !brushing &&
            lastAlert != key) {
          lastAlert = key;
          showAlert();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Бүртгэлийг нээж чадсангүй. Аппаа дахин нээнэ үү.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => currentTime = DateTime.now());
    }
    if (state != AppLifecycleState.resumed) {
      session.pause();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    first.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (saving || prefs == null || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await prefs!.reload();
      if (!await CareData(prefs!).login(first.text, rememberMe: rememberMe)) {
        if (mounted) {
          setState(
              () => error = 'ID олдсонгүй. Эмчээс олгосон ID-гаа шалгана уу.');
        }
        return;
      }
      if (mounted) {
        setState(() {
          error = null;
          signedIn = true;
          session = BrushingSession();
          brushing = false;
        });
        await load();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Нэвтэрч чадсангүй. Дахин оролдоно уу.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> showAlert() async {
    if (alertOpen || brushing || !mounted) return;
    alertOpen = true;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                title: const Text('Бяцхан арчилгаа, том инээмсэглэл. ✨'),
                content: const Text(
                    'Шүдээ угаах цаг боллоо! Шүдхэн найз чинь хүлээж байна.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Дараа')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('За, шүдээ угаая'))
                ]));
    alertOpen = false;
    if (yes == true && mounted) {
      await openCamera();
    }
  }

  Future<void> openCamera() async {
    if (!signedIn) return;
    session.pause();
    setState(() {
      if (!brushing || session.complete) {
        session = BrushingSession();
        careSessionId = DateTime.now().microsecondsSinceEpoch.toString();
      }
      brushing = true;
    });
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CameraCoach(
                session: session,
                age: childAge(profile!['first'] as String),
                onFinish: finish,
                onFloss: recordFloss,
                autoStart: true)));
    session.pause();
    if (mounted) setState(() {});
  }

  Future<void> recordEvent(Map<String, dynamic> details) async {
    final childId = prefs!.getString('activeClient');
    if (childId == null || !CareData(prefs!).exists(childId)) {
      throw StateError('Unknown client');
    }
    final events = (jsonDecode(prefs!.getString('careEvents') ?? '[]') as List);
    events.add({
      'date': DateTime.now().toIso8601String(),
      'childId': childId,
      'childName': profile == null
          ? 'Зочин'
          : '${profile!['first']} ${profile!['last']}',
      'sessionId': careSessionId,
      ...details
    });
    if (!await prefs!.setString('careEvents', jsonEncode(events))) {
      throw StateError('Save failed');
    }
  }

  Future<void> recordFloss() async => recordEvent({'type': 'floss'});
  Future<void> finish() async {
    final section = session.section;
    if (!session.finishSection()) return;
    setState(() {});
    try {
      await recordEvent({
        'type': 'brush',
        'section': section,
        'milliseconds': session.times[section]!.inMilliseconds
      });
      if (session.complete) {
        rewards++;
        await prefs!.setInt('rewards:${profile!['first']}', rewards);
        await prefs!.setString('lastSession:${profile?['first'] ?? 'guest'}',
            jsonEncode(session.times.map((e) => e!.inMilliseconds).toList()));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Энэ бүртгэлийг төхөөрөмжид хадгалж чадсангүй.');
      }
    }
  }

  String duration(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  Future<void> introduction() async {
    session.pause();
    setState(() {});
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              title: const Text('Шүдхэн найзтайгаа танилцаарай ✨'),
              content: const SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('1. Бэлтгээрэй',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Сойз, оогоо бэлдээд толины өмнө тухтай байрлаарай.'),
                    SizedBox(height: 16),
                    Text('2. Хэсгээ сонгоорой',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Дээд зүүн, дээд баруун, доод зүүн эсвэл доод баруун хэсгээ сонгоорой. Шар өнгөтэй хэсэг нь таны сонголт.'),
                    SizedBox(height: 16),
                    Text('3. Найзтайгаа угаагаарай',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Камераа асаагаад сойзоо зөөлөн тойруулж угаагаарай. Сонгосон хэсгийн гадна, дотор, зажлах гадаргууг цэвэрлээрэй.'),
                    SizedBox(height: 16),
                    Text('4. Дуусгаад тэмдэглээрэй',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Хэсэг бүрийг 30 секунд угаагаад Дуусгах товчийг дараарай. Дөрвөн хэсгээ дуусгавал од авна! Хэсэг солиход хугацаа хадгалагдана.'),
                  ])),
              actions: [
                ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Ойлголоо!'))
              ],
            ));
  }

  Widget heading(String eyebrow, String title, String sub) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow,
            style: const TextStyle(
                color: green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 34, height: 1.12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(sub,
            style: const TextStyle(
                color: Color(0xFF6F817B), fontSize: 16, height: 1.5))
      ]);
  Widget panel(Widget child, {Color color = Colors.white}) => Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      child: Padding(padding: const EdgeInsets.all(24), child: child));
  @override
  Widget build(BuildContext context) {
    if (signedIn && !settingsOpen) {
      final stats =
          CareStats(CareData(prefs!).forChild(profile!['first'] as String));
      return KidHome(
          name: childName(profile!['first'] as String),
          stars: availableStars(profile!['first'] as String, stats.complete),
          dates: stats.completedDates,
          gift: giftConfig(profile!['first'] as String),
          night: night,
          onBrush: openCamera,
          onSettings: () => setState(() => settingsOpen = true));
    }
    return Scaffold(
        appBar: AppBar(
            title: Text(signedIn ? 'Тохиргоо' : 'Шүдхэн'),
            leading: signedIn
                ? IconButton(
                    tooltip: 'Нүүр',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => settingsOpen = false))
                : null),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                        padding: EdgeInsets.all(
                            MediaQuery.sizeOf(context).width < 380 ? 16 : 24),
                        children: [
                          if (error != null)
                            Text(error!,
                                style:
                                    const TextStyle(color: Colors.deepOrange)),
                          if (prefs == null && error == null)
                            const Center(child: CircularProgressIndicator())
                          else if (!signedIn)
                            registration()
                          else ...[
                            settingsContent(),
                            const SizedBox(height: 16),
                            ListTile(
                                leading: const Icon(Icons.help_outline),
                                title: const Text('Хэрхэн угаах вэ?'),
                                onTap: introduction),
                            ListTile(
                                leading: const Icon(Icons.logout),
                                title: const Text('Гарах'),
                                onTap: () async {
                                  session.pause();
                                  await prefs!.setBool('signedIn', false);
                                  if (reminders.supported)
                                    await reminders.plugin.cancelAll();
                                  if (mounted)
                                    setState(() {
                                      signedIn = false;
                                      settingsOpen = false;
                                      brushing = false;
                                    });
                                }),
                          ],
                          if (!signedIn)
                            IconButton(
                                tooltip: 'Хэрхэн угаах вэ?',
                                onPressed: introduction,
                                icon: const Icon(Icons.help_outline)),
                        ])))));
  }

  Widget registration() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading('🦷 ШҮДХЭН', 'Сайн уу!', 'ID-гаа оруулаад нэвтрээрэй.'),
        SizedBox(
            height: 170,
            child:
                CustomPaint(painter: TeethPainter(mascot: true, night: night))),
        panel(Form(
            key: form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                      controller: first,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Хүүхдийн ID',
                          prefixIcon: Icon(Icons.badge_outlined)),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'ID-гаа оруулна уу'
                          : null,
                      onFieldSubmitted: (_) => register()),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Намайг санах'),
                      value: rememberMe,
                      onChanged: saving
                          ? null
                          : (value) =>
                              setState(() => rememberMe = value ?? false)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                      onPressed: saving ? null : register,
                      icon: const Icon(Icons.login),
                      label: Text(saving ? 'Түр хүлээнэ үү…' : 'Нэвтрэх')),
                  const SizedBox(height: 12),
                  const Text('Офлайн туршилт: 123456 • Утсанд хадгална',
                      textAlign: TextAlign.center),
                ]))),
      ]);
  Widget settingsContent() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Угаах сануулга',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (reminderTimes.isEmpty)
            const Text('Сануулга алга. Өөрт тохирох цагаа нэмээрэй.'),
          ...List.generate(reminderTimes.length, (i) {
            final r = reminderTimes[i];
            return Row(children: [
              Expanded(
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          TimeOfDay(
                                  hour: r['hour'] as int,
                                  minute: r['minute'] as int)
                              .format(context),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Өдөр бүр · дарж засах'),
                      onTap: updatingReminders ? null : () => editReminder(i))),
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
                        }),
              IconButton(
                  tooltip: 'Сануулга устгах',
                  onPressed: updatingReminders
                      ? null
                      : () {
                          final updated = reminderTimes
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList()
                            ..removeAt(i);
                          saveReminders(updated);
                        },
                  icon: const Icon(Icons.delete_outline)),
            ]);
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: updatingReminders ? null : () => editReminder(null),
              icon: const Icon(Icons.add_alarm),
              label: Text(
                  updatingReminders ? 'Хадгалж байна…' : 'Сануулга нэмэх')),
          const SizedBox(height: 12),
          Text(
              reminders.supported
                  ? '30 хүртэл хоногийн, хамгийн ихдээ 60 сануулга төлөвлөж, апп нээх бүрд шинэчилнэ.'
                  : 'Вэб дээр апп нээлттэй үед сануулга гарна.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF718078))),
        ])),
      ]);
  Future<void> editReminder(int? index) async {
    final r = index == null ? null : reminderTimes[index];
    final time = await showTimePicker(
        context: context,
        initialTime: r == null
            ? TimeOfDay.now()
            : TimeOfDay(hour: r['hour'] as int, minute: r['minute'] as int));
    if (time == null || !mounted) return;
    if (reminderTimes.asMap().entries.any((e) =>
        e.key != index &&
        e.value['hour'] == time.hour &&
        e.value['minute'] == time.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Энэ цагт сануулга аль хэдийн байна.')));
      return;
    }
    final updated =
        reminderTimes.map((e) => Map<String, dynamic>.from(e)).toList();
    final entry = <String, dynamic>{
      'hour': time.hour,
      'minute': time.minute,
      'enabled': r == null ? true : r['enabled']
    };
    if (index == null) {
      updated.add(entry);
    } else {
      updated[index] = entry;
    }
    updated.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int))
        .compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));
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
          'reminderTimes:${profile?['first'] ?? 'guest'}',
          jsonEncode(updated))) {
        throw StateError('Could not save');
      }
      if (mounted) setState(() => reminderTimes = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Сануулгыг хадгалж чадсангүй. Мэдэгдлийн зөвшөөрлөө шалгаад дахин оролдоно уу.')));
      }
    } finally {
      if (mounted) setState(() => updatingReminders = false);
    }
  }
}
