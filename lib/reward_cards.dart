import 'dart:convert';
import 'package:flutter/material.dart';

class RewardCards extends StatelessWidget {
  final Map<String, dynamic> data;
  const RewardCards({super.key, required this.data});

  Widget picture(Map<String, dynamic> reward, {double size = 76}) {
    try {
      final raw = reward['imageData'] as String? ?? '';
      return Image.memory(
        base64Decode(raw.split(',').last),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) =>
            Icon(Icons.card_giftcard, size: size),
        semanticLabel: reward['name'] as String? ?? 'Бэлэг',
      );
    } catch (_) {
      return Icon(Icons.card_giftcard, size: size);
    }
  }

  static int progressAt(Map<String, dynamic> reward, DateTime now) {
    final day = reward['lastQualifiedDay'] as String?;
    final goal = (reward['goalDays'] as num?)?.toInt() ?? 7;
    final progress = ((reward['progress'] as num?)?.toInt() ?? 0).clamp(
      0,
      goal,
    );
    if (day == null || day.isEmpty) return progress;
    // Ulaanbaatar uses UTC+8. Compare calendar dates, not elapsed 24h periods.
    final local = now.toUtc().add(const Duration(hours: 8));
    final yesterday = DateTime.utc(
      local.year,
      local.month,
      local.day - 1,
    ).toIso8601String().substring(0, 10);
    return day.compareTo(yesterday) < 0 ? 0 : progress;
  }

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final awards = (data['awards'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🎁 Миний бэлгүүд',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text('Эмнэлгээс бэлэг тохируулахад энд харагдана.'),
        ...items.map((r) {
          final goal = (r['goalDays'] as num?)?.toInt() ?? 7;
          final progress = progressAt(r, DateTime.now());
          return Card(
            color: const Color(0xFFEAE3F7),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      picture(r),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['name'] as String? ?? 'Бэлэг',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('$goal өдөр тутам'),
                            Text('Бэлэг хүртэл ${goal - progress} өдөр'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: goal > 0 ? (progress / goal).clamp(0, 1) : 0,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text('$progress / $goal дараалсан өдөр'),
                ],
              ),
            ),
          );
        }),
        if (items.isNotEmpty)
          const Text(
            'Өдөрт 2 минутын зорилтоо хангасан угаалт тооцно. Нэг өдөр тасарвал ахиц дахин эхэлнэ. Бэлэг Улаанбаатарын цагаар, серверт ирсэн бүртгэлээр шинэчлэгдэнэ.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        const SizedBox(height: 16),
        Text(
          '🏆 Цуглуулсан бэлгүүд (${data['totalAwards'] ?? awards.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (awards.isEmpty)
          const Text('Зорилтоо биелүүлээд анхны бэлгээ цуглуулаарай!'),
        if (awards.length >= 50)
          const Text('Сүүлийн 50 бэлгийг харуулж байна.'),
        ...awards.map(
          (r) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: picture(r, size: 52),
            title: Text(r['name'] as String? ?? 'Бэлэг'),
            subtitle: Text((r['earnedDay'] as String? ?? '').split('T').first),
            trailing: const Icon(Icons.check_circle, color: Color(0xFF499C93)),
          ),
        ),
      ],
    );
  }
}
