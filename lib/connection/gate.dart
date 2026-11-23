import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'api.dart';
import 'controller.dart';
import 'credentials.dart';
import 'store.dart';

class ConnectionGate extends StatefulWidget {
  final CareController? controller;
  final Widget Function(CareController) home;
  const ConnectionGate({super.key, this.controller, required this.home});
  @override
  State<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<ConnectionGate>
    with WidgetsBindingObserver {
  CareController? care;
  bool loading = true;
  String? error;
  Timer? retry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  Future<void> start() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      care ??=
          widget.controller ??
          CareController(
            api: CareApi(),
            credentials: SecureCredentials(),
            store: createSessionStore(),
          );
      await care!.initialize();
      if (!mounted) return;
      setState(() => loading = false);
      retry ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(background()),
      );
      unawaited(background(profile: true));
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = failure is ApiFailure
              ? failure.message
              : 'Хадгалсан холбоосыг нээж чадсангүй. Дахин оролдоно уу.';
        });
      }
    }
  }

  Future<void> background({bool profile = false}) async {
    try {
      if (profile) await care?.refreshProfile();
      await care?.sync();
    } catch (_) {
      /* Keep local records and let the next retry recover. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(background(profile: true));
    }
  }

  @override
  void dispose() {
    retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) care?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: start,
                  child: const Text('Дахин оролдох'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: care!,
      builder: (_, __) {
        if (care!.connection == null) return LinkScreen(care: care!);
        return widget.home(care!);
      },
    );
  }
}

class LinkScreen extends StatefulWidget {
  final CareController care;
  const LinkScreen({super.key, required this.care});
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final form = GlobalKey<FormState>();
  final token = TextEditingController();
  final guardian = TextEditingController();
  final relationship = TextEditingController();
  final device = TextEditingController();
  Map<String, dynamic>? consent;
  bool accepted = false, busy = false, fetching = false;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(loadConsent());
  }

  Future<void> loadConsent() async {
    setState(() {
      fetching = true;
      error = null;
      accepted = false;
      consent = null;
    });
    try {
      final value = await widget.care.consent();
      if (value['version'] is! String ||
          value['text'] is! String ||
          (value['version'] as String).trim().isEmpty ||
          (value['text'] as String).trim().isEmpty) {
        throw const FormatException();
      }
      if (mounted) setState(() => consent = value);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(
          () => error = 'Зөвшөөрлийн мэдээлэл татагдсангүй. ${failure.message}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Серверээс ирсэн зөвшөөрлийн мэдээлэл буруу байна. Дахин оролдоно уу.',
        );
      }
    } finally {
      if (mounted) setState(() => fetching = false);
    }
  }

  Future<void> connect() async {
    if (busy || consent == null || !form.currentState!.validate()) return;
    if (!accepted) {
      setState(() => error = 'Мэдээлэл хуваалцах зөвшөөрлөө өгнө үү.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.care.link(
        invitation: token.text,
        guardianName: guardian.text,
        relationship: relationship.text,
        deviceName: device.text,
        consentVersion: consent!['version'] as String,
      );
      token.clear();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Холбоосыг хадгалж чадсангүй. Дахин оролдоно уу; урилга ашиглагдсан бол эмнэлгээс шинэ урилга авна уу.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    token.dispose();
    guardian.dispose();
    relationship.dispose();
    device.dispose();
    super.dispose();
  }

  Widget input(
    TextEditingController controller,
    String label,
    int max, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: !secret,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (v) =>
          v == null || v.trim().isEmpty ? '$label оруулна уу' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Шүдхэн — эмнэлэгтэй холбох')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Асран хамгаалагчтайгаа хамт холбоорой',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Эмнэлгээс олгосон нэг удаагийн урилгыг оруулна уу. Хүүхдийн картын дугаар нь урилга биш.',
                ),
                const SizedBox(height: 24),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      input(token, 'Урилгын код', 43, secret: true),
                      input(guardian, 'Асран хамгаалагчийн нэр', 150),
                      input(relationship, 'Хүүхэдтэй ямар хамааралтай вэ?', 50),
                      input(device, 'Төхөөрөмжийн нэр', 100),
                    ],
                  ),
                ),
                if (fetching) const Center(child: CircularProgressIndicator()),
                if (consent != null) ...[
                  Text(consent!['text'] as String),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Уншиж танилцсан, зөвшөөрч байна'),
                    value: accepted,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => accepted = v ?? false),
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                if (error != null && kDebugMode)
                  Text(
                    'API: ${widget.care.api.baseUrl}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (widget.care.syncMessage != null &&
                    widget.care.connection == null)
                  Text(widget.care.syncMessage!),
                if (!fetching && consent == null)
                  TextButton(
                    onPressed: loadConsent,
                    child: const Text('Зөвшөөрлийг дахин татах'),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || consent == null ? null : connect,
                  child: Text(busy ? 'Холбож байна…' : 'Холбох'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Хуучин холбоосын илгээгээгүй бүртгэл утсанд хадгалагдана. Өөр хүүхдийн шинэ холбоос руу дамжуулахгүй.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
