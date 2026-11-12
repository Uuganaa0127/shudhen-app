import 'package:camera/camera.dart';
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
  CameraController? camera;
  int last = 0;
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final devices = await availableCameras();
      if (!mounted) return;
      if (devices.isEmpty) throw StateError('No camera');
      final device = devices.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => devices.first);
      final controller =
          CameraController(device, ResolutionPreset.low, enableAudio: false);
      camera = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.startImageStream((frame) {
        if (!mounted || DateTime.now().millisecondsSinceEpoch - last < 250) {
          return;
        }
        last = DateTime.now().millisecondsSinceEpoch;
        final plane = frame.planes.first;
        final side =
            (frame.width < frame.height ? frame.width : frame.height) * 0.4;
        final pixels = <int>[];
        for (int y = 0; y < 24; y++) {
          for (int x = 0; x < 24; x++) {
            final px = ((frame.width - side) / 2 + x * side / 24).floor();
            final py = ((frame.height - side) / 2 + y * side / 24).floor();
            final offset =
                py * plane.bytesPerRow + px * (plane.bytesPerPixel ?? 1);
            if (frame.format.group == ImageFormatGroup.bgra8888) {
              pixels.add(((plane.bytes[offset] +
                          plane.bytes[offset + 1] +
                          plane.bytes[offset + 2]) /
                      3)
                  .round());
            } else {
              pixels.add(plane.bytes[offset]);
            }
          }
        }
        widget.onFrame(pixels);
      });
    } catch (_) {
      if (mounted) {
        widget.onError(
            'Камер нээгдэхгүй байна. Төхөөрөмжийн тохиргоонд камераа зөвшөөрөөд дахин оролдоно уу.');
      }
    }
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return camera?.value.isInitialized == true
        ? Center(child: CameraPreview(camera!))
        : const Center(child: CircularProgressIndicator());
  }
}
