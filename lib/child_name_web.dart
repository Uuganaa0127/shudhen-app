import 'package:web/web.dart' as web;
import 'dart:convert';

String childName(String id) {
  try {
    final profiles =
        jsonDecode(web.window.localStorage.getItem('shudkhen.childProfiles') ?? '{}');
    final name = profiles[id]?['name'];
    if (name is String && name.trim().isNotEmpty) return name;
  } catch (_) {}
  return 'Бяцхан найз';
}

Map<String, dynamic> giftConfig(String id) {
  try {
    final all = jsonDecode(web.window.localStorage.getItem('shudkhen.gifts') ?? '{}');
    return Map<String, dynamic>.from(all[id] ?? {});
  } catch (_) {
    return {};
  }
}

int? childAge(String id) {
  try {
    final p =
        jsonDecode(web.window.localStorage.getItem('shudkhen.childProfiles') ?? '{}');
    return (p[id]?['age'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

int availableStars(String id, int earned) {
  try {
    final rows =
        jsonDecode(web.window.localStorage.getItem('shudkhen.redemptions') ?? '[]')
            as List;
    final spent = rows
        .where((e) => e['childId'] == id)
        .fold<int>(0, (sum, e) => sum + (e['cost'] as num).toInt());
    return (earned - spent).clamp(0, earned).toInt();
  } catch (_) {
    return 0;
  }
}
