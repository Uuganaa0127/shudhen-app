import 'dart:html' as html;
import 'dart:convert';

String childName(String id) {
  try {
    final profiles =
        jsonDecode(html.window.localStorage['shudkhen.childProfiles'] ?? '{}');
    final name = profiles[id]?['name'];
    if (name is String && name.trim().isNotEmpty) return name;
  } catch (_) {}
  return 'Бяцхан найз';
}

Map<String, dynamic> giftConfig(String id) {
  try {
    final all = jsonDecode(html.window.localStorage['shudkhen.gifts'] ?? '{}');
    return Map<String, dynamic>.from(all[id] ?? {});
  } catch (_) {
    return {};
  }
}

int? childAge(String id) {
  try {
    final p =
        jsonDecode(html.window.localStorage['shudkhen.childProfiles'] ?? '{}');
    return (p[id]?['age'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

int availableStars(String id, int earned) {
  try {
    final rows =
        jsonDecode(html.window.localStorage['shudkhen.redemptions'] ?? '[]')
            as List;
    final spent = rows
        .where((e) => e['childId'] == id)
        .fold<int>(0, (sum, e) => sum + (e['cost'] as num).toInt());
    return (earned - spent).clamp(0, earned).toInt();
  } catch (_) {
    return 0;
  }
}
