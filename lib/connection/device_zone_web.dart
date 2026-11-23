import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _DateFormat._(JSObject _) implements JSObject {
  external factory _DateFormat();
  external _Options resolvedOptions();
}
extension type _Options._(JSObject _) implements JSObject {
  external String get timeZone;
}
Future<String> deviceTimeZone() async {
  try {
    return _DateFormat().resolvedOptions().timeZone;
  } catch (_) {
    return 'UTC';
  }
}
