import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as tflite;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
 
class TfliteModelGarden {
  static const Map<String, dynamic> tfliteModelMap = {
    'general': {
      'model': 'efficientnet_lite0_int8_2.tflite',
      'label': 'labels_without_background.txt'
    },
    'general-2': {
      'model': 'lite-model_object_detection_mobile_object_labeler_v1_1.tflite',
      'label': 'probability-labels-en.txt'
    }
  };
 
  static List<TfliteModel> models = [];

  static Future<void> populate({String pathPrefix = ''}) async {
    // packages/geo_map_painter/assets/KR-SEOUL.json
    for (MapEntry<String, dynamic> pair in tfliteModelMap.entries) {
      models.add(
        await TfliteModel.fromAsset(
          category: pair.key,
          model: pair.value['model'],
          label: pair.value['label'],
          prefix: pathPrefix
        )
      );
    }
  }
 
  static TfliteModel defaultModel(){
    return models.firstWhere((element) => element.modelCategory == 'general-2');
  }
}
 
class TfliteModel {
  String modelPath;
  String modelCategory;
  String modelFileName;
  String labelFileName;
  List<tflite.Label> labels;
 
  TfliteModel({required this.modelPath, required this.modelCategory, required this.modelFileName, required this.labelFileName, required this.labels});

  static Future<TfliteModel> fromAsset({required String category, required String model, required String label, String prefix = ''}) async {
    Future<List<String>> modelLabels(String category) async {
      String longString = await rootBundle.loadString('${prefix}assets/tflite/${TfliteModelGarden.tfliteModelMap[category]["label"]}');
      List<String> res = longString.split('\n');
      return res;
    }
 
    Future<String> getModel(String assetPath) async {
      if (io.Platform.isAndroid) {
        return 'flutter_assets/$assetPath';
      }
      final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
      await io.Directory(dirname(path)).create(recursive: true);
      final file = io.File(path);
      if (!await file.exists()) {
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
      return file.path;
    }
 
    List<String> labels = (await modelLabels(category))..sort();
    List<tflite.Label> labelList = labels.asMap().entries.map<tflite.Label>((MapEntry<int, String> e) {
      return tflite.Label(
        confidence: 1.0,
        index: e.key,
        text: e.value
      );
    }).toList();
    return TfliteModel(modelPath: await getModel('${prefix}assets/tflite/$model'), modelCategory: category, modelFileName: model, labelFileName: label, labels: labelList);
  }
}
