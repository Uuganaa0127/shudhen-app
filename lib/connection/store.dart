import 'records.dart';
import 'store_native.dart' if (dart.library.html) 'store_web.dart' as platform;
export 'records.dart';

SessionStore createSessionStore() => platform.createStore();
