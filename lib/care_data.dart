import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CareData {
  final SharedPreferences prefs;
  CareData(this.prefs);
  static String normalize(String id) => id.trim().toUpperCase();
  List<String> get clients => prefs.getStringList('doctorClients') ?? [];
  bool exists(String id) => clients.contains(normalize(id));
  Future<bool> addClient(String id) async {
    id = normalize(id);
    if (!RegExp(r'^[A-Z0-9-]{3,32}$').hasMatch(id) || exists(id)) return false;
    return prefs.setStringList('doctorClients', [...clients, id]);
  }

  List<Map<String, dynamic>> get events =>
      (jsonDecode(prefs.getString('careEvents') ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<Map<String, dynamic>> forChild(String id) =>
      events.where((e) => e['childId'] == id).toList();
  Future<bool> login(String id, {bool rememberMe = true}) async {
    id = normalize(id);
    if (!exists(id)) return false;
    await prefs.setString('activeClient', id);
    await prefs.setBool('rememberMe', rememberMe);
    if (rememberMe) {
      await prefs.setString('rememberedClient', id);
    } else {
      await prefs.remove('rememberedClient');
    }
    return prefs.setBool('signedIn', rememberMe);
  }
}

class CareStats {
  final List<Map<String, dynamic>> events;
  CareStats(this.events);
  List<Map<String, dynamic>> get brush =>
      events.where((e) => e['type'] == 'brush').toList();
  List<Map<String, dynamic>> side(int i) =>
      brush.where((e) => e['section'] == i).toList();
  double average(int i) {
    final rows = side(i);
    return rows.isEmpty
        ? 0
        : rows.fold<double>(
                0, (sum, e) => sum + (e['milliseconds'] as num) / 1000) /
            rows.length;
  }

  double total(int i) => side(i)
      .fold<double>(0, (sum, e) => sum + (e['milliseconds'] as num) / 1000);
  Map<String, Set<int>> get sessions {
    final result = <String, Set<int>>{};
    for (final e in brush) {
      result
          .putIfAbsent(e['sessionId'] as String, () => {})
          .add(e['section'] as int);
    }
    return result;
  }

  int get complete => sessions.values.where((s) => s.length == 4).length;
  Set<String> get completedDates {
    final completed = sessions.entries
        .where((e) => e.value.length == 4)
        .map((e) => e.key)
        .toSet();
    final dates = <String, String>{};
    for (final e in brush) {
      final id = e['sessionId'] as String;
      if (!completed.contains(id)) continue;
      final date = e['date'] as String;
      if (!dates.containsKey(id) || date.compareTo(dates[id]!) > 0)
        dates[id] = date;
    }
    return dates.values.map((d) => d.substring(0, 10)).toSet();
  }

  int get completedDays => completedDates.length;
  int get activeDays =>
      brush.map((e) => (e['date'] as String).substring(0, 10)).toSet().length;
  static const names = ['Дээд зүүн', 'Дээд баруун', 'Доод зүүн', 'Доод баруун'];
  String get childTip {
    if (brush.isEmpty) return '🦷 Эхний угаалгаа хийцгээе!';
    for (int i = 0; i < 4; i++) {
      if (side(i).isEmpty) return '🦷 ${names[i]} хэсгээ бас угаагаарай!';
    }
    var lowest = 0;
    for (int i = 1; i < 4; i++) {
      if (average(i) < average(lowest)) lowest = i;
    }
    if (average(lowest) < 30) {
      return '⏱ ${names[lowest]} хэсэгт 30 секунд хүргэе!';
    }
    return '🌟 Дөрвөн хэсгээ үргэлжлүүлэн арчлаарай!';
  }

  List<String> get doctorTips {
    if (brush.isEmpty) {
      return [
        'Өгөгдөл хүрэлцэхгүй. Апп ашиглалт, камерын зөвшөөрөл, бүртгэл дамжуулалтыг шалгана уу. Бүртгэлгүй гэдэг нь угаагаагүй гэсэн үг биш.'
      ];
    }
    final result = <String>[];
    if (sessions.length < 3) {
      result.add(
          'Ердөө ${sessions.length} угаалтын бүртгэл байна. Давтагдах хандлага дүгнэхээс өмнө илүү олон бүртгэл цуглуулна уу.');
    }
    for (int i = 0; i < 4; i++) {
      if (side(i).isEmpty) {
        result.add(
            '${names[i]}: бүртгэл алга. Хэсэг сонголтыг хүүхэд, асран хамгаалагчтай хамт шалгана уу.');
      } else if (average(i) < 30) {
        result.add(
            '${names[i]}: дундаж ${average(i).toStringAsFixed(0)} секунд (${side(i).length} бүртгэл). Аппын 30 секундын зорилтоос бага; эрт дуусгасан эсэх, хөдөлгөөн тасалдсан эсэх, сойз хүрч байгаа эсэхийг ажиглан шалгана уу.');
      }
    }
    final incomplete = sessions.length - complete;
    if (incomplete > 0) {
      result.add(
          '$incomplete угаалт дөрвөн хэсгээр баталгаажаагүй. Дутуу хэсэг ба Дуусгах товчны хэрэглээг шалгана уу.');
    }
    if (brush.any((e) => (e['milliseconds'] as num) > 180000)) {
      result.add(
          'Нэг хэсгийн хугацаа 3 минутаас их байна. Толгойн хөдөлгөөн, камерын алдаа, хугацаа хэт тоолсон эсэхийг шалгана уу; удаан хугацааг сайн чанар гэж үнэлэхгүй.');
    }
    if (events.every((e) => e['type'] != 'floss')) {
      result.add(
          'Утас хэрэглэсэн тэмдэглэгээ алга. Бодит дадлыг асран хамгаалагчаас лавлаж, тохирох аргыг үзүүлнэ үү.');
    }
    result.add(
        'Энэ нь дүрэмд суурилсан ажиглалтын санал; онош, цоорлын эрсдэлийн үнэлгээ биш. Камер угаалтын чанар болон бодит шүдний хэсгийг баталгаажуулахгүй.');
    return result;
  }
}
