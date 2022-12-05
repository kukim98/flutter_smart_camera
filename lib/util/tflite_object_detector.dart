import 'package:flutter_smart_camera/data_structure/tflite_model.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as tflite;

class TfliteObjectDetector {
  TfliteModel model;
  late tflite.ObjectDetector _objectDetector;

  TfliteObjectDetector({required this.model}) {
    _objectDetector = tflite.ObjectDetector(
      options: tflite.LocalObjectDetectorOptions(
        mode: tflite.DetectionMode.stream,
        modelPath: model.modelPath,
        classifyObjects: true,
        multipleObjects: true
      )
    );
  }

  void dispose() => _objectDetector.close();

  Future<List<tflite.DetectedObject>> infer(tflite.InputImage image) async => await _objectDetector.processImage(image);
}