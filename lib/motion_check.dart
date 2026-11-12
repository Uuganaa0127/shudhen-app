/// Experimental frame difference, not a tooth/brush or technique classifier.
class MotionCheck {
  List<int>? _previous;
  int _still = 0;
  bool isMoving = false;
  String inspect(List<int> pixels) {
    isMoving = false;
    if (pixels.isEmpty) return 'Камерын дүрс хүлээж байна…';
    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    final previous = _previous;
    _previous = List.of(pixels);
    if (mean < 30) return 'Гэрлээ нэмээрэй';
    if (previous == null || previous.length != pixels.length) {
      return 'Эхлэхийн өмнө түр хөдөлгөөнгүй байгаарай';
    }
    final oldMean = previous.reduce((a, b) => a + b) / previous.length;
    if ((mean - oldMean).abs() > 15) {
      _still = 0;
      return 'Гэрэл өөрчлөгдлөө — камераа хөдөлгөөнгүй байлгаарай';
    }
    double difference = 0;
    for (int i = 0; i < pixels.length; i++) {
      difference += (pixels[i] - previous[i]).abs();
    }
    difference /= pixels.length;
    if (difference > 5) {
      isMoving = true;
      _still = 0;
      return 'Хөдөлгөөн илэрлээ — зөөлөн тойруулж угаагаарай';
    }
    _still++;
    return _still >= 8
        ? 'Хөдөлгөөн бага байна — сойзоо зөөлөн хөдөлгөөрэй'
        : 'Хөдөлгөөн ажиглаж байна…';
  }
}
