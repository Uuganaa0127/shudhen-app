import 'package:flutter/services.dart';

Future<String> deviceTimeZone() async {
  try {
    return await const MethodChannel('shudhen/device')
            .invokeMethod<String>('timeZone')
            .timeout(const Duration(seconds: 2)) ??
        'UTC';
  } catch (_) {
    return 'UTC';
  }
}
