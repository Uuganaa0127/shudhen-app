// Browser frames are processed in memory, never saved or uploaded.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class CameraFeed extends StatefulWidget {
  final ValueChanged<List<int>> onFrame;
  final ValueChanged<String> onError;
  const CameraFeed({super.key, required this.onFrame, required this.onError});
  @override
  State<CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static int counter = 0;
  late final String viewId = 'brush-camera-${counter++}';
  final video = html.VideoElement()
    ..autoplay = true
    ..muted = true;
  final canvas = html.CanvasElement(width: 24, height: 24);
  html.MediaStream? stream;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    video.setAttribute('playsinline', 'true');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..transform = 'scaleX(-1)';
    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) => video);
    start();
  }

  Future<void> start() async {
    try {
      final result = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false
      });
      if (!mounted) {
        for (final track in result.getTracks()) {
          track.stop();
        }
        return;
      }
      stream = result;
      video.srcObject = result;
      await video.play();
      if (!mounted) return;
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (video.videoWidth == 0 || video.videoHeight == 0) return;
        try {
          final size = (video.videoWidth < video.videoHeight
                  ? video.videoWidth
                  : video.videoHeight) *
              0.4;
          canvas.context2D.drawImageScaledFromSource(
              video,
              (video.videoWidth - size) / 2,
              (video.videoHeight - size) / 2,
              size,
              size,
              0,
              0,
              24,
              24);
          final bytes = canvas.context2D.getImageData(0, 0, 24, 24).data;
          widget.onFrame(List.generate(
              24 * 24,
              (i) => ((bytes[i * 4] + bytes[i * 4 + 1] + bytes[i * 4 + 2]) / 3)
                  .round()));
        } catch (_) {
          timer?.cancel();
          widget
              .onError('Камерын шинжилгээ зогслоо. Хаагаад дахин оролдоно уу.');
        }
      });
    } catch (_) {
      if (mounted) {
        widget.onError(
            'Камер нээгдэхгүй байна. Хөтчийн камерын зөвшөөрлийг нээгээд дахин оролдоно уу. HTTPS эсвэл localhost ашиглана уу.');
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final track in stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return HtmlElementView(viewType: viewId);
  }
}
