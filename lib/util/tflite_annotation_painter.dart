import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as tflite;
import 'package:intel_geti_api/intel_geti_api.dart' as geti;
import 'package:intel_geti_ui/intel_geti_ui.dart';

import '../data_structure/tflite_model.dart';
import 'tflite_geti_label_mapper.dart';

class TfliteRawAnnotationPainter extends CustomPainter {
  List<tflite.DetectedObject> annotations;
  Size displaySize;
  double zoom;
  bool isResize;
  // Id of selected MediaAnnotation
  String? id;
  final Size? absoluteImageSize;
  final TfliteModel model;
  final TfliteGetiLabelMapper mapper;
  bool flipDimension;
  TextStyle? labelStyle;

  TfliteRawAnnotationPainter({
    required this.annotations,
    this.zoom = 0.0,
    this.isResize = false,
    this.id,
    this.absoluteImageSize,
    required this.displaySize,
    required this.model,
    required this.mapper,
    this.flipDimension = false,
    this.labelStyle
  });
 
  // List<Label> wantedLabels() => labelPairs.map((e) => e.item1).toSet().toList();
  // bool inWantedLabels(Label label) => wantedLabels().where((element) => label.id == element.id).isNotEmpty;
  // Label? labelInterchange(tflite.Label label){
  //   try {
  //     return findCounterpart(wantedLabels().firstWhere((element) => label.text == element.name));
  //   } catch (error){
  //     return null;
  //   }
  // }
 
  // Label findCounterpart(Label label){
  //   for (Tuple2<Label, Label> pair in labelPairs){
  //     if (label.id == pair.item1.id){
  //       return pair.item2;
  //     }
  //   }
  //   throw Exception('DNE');
  // }
 
  Rect rotatedRect(Rect rect, Size size){
    // final left = absoluteImageSize!.width - rect.bottom;
    // final top = rect.left;
    // final right = absoluteImageSize!.width- rect.top;
    // final bottom = rect.right;
    if (flipDimension){
      return Rect.fromLTRB(
      rect.left / absoluteImageSize!.height * size.width,
      rect.top / absoluteImageSize!.width * size.height,
      rect.right / absoluteImageSize!.height * size.width,
      rect.bottom / absoluteImageSize!.width * size.height);  
    }
    return Rect.fromLTRB(
      rect.left / absoluteImageSize!.width * size.width,
      rect.top / absoluteImageSize!.height * size.height,
      rect.right / absoluteImageSize!.width * size.width,
      rect.bottom / absoluteImageSize!.height * size.height);
    // return rect;
  }
 
  @override
  void paint(Canvas canvas, Size size){
    double factor = 22.5;
    double strokeWidth = 5.0 + (1- zoom) * factor;
 
    if (mapper.isTfliteViewMode){
      for (tflite.DetectedObject element in annotations) {
        for (tflite.Label label in element.labels) {
          Paint labelColorPaint = Paint()
            ..color = Colors.white
            ..strokeCap = StrokeCap.round
            ..strokeWidth = strokeWidth;
          Paint labelFillPaint = Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.fill
            ..strokeCap = StrokeCap.round
            ..strokeWidth = strokeWidth;
 
          Rect uiAnnotation = rotatedRect(element.boundingBox, displaySize);
          // print("$uiAnnotation$flipDimension");
          // print("UI - $uiAnnotation; RAW - ${element.boundingBox}; IMG - $absoluteImageSize; RENDERrrrrr - $displaySize");
          TextStyle textStyle = (labelStyle ?? const TextStyle()).copyWith(color: Colors.black, fontSize: 25.0, fontWeight: FontWeight.w600);
          TextSpan textSpan = TextSpan(text: '${label.text} ${(label.confidence * 100).round()}%', style: textStyle);
          TextPainter textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
          textPainter.layout(minWidth: 0.0, maxWidth: double.infinity);
          // Draw Annotation ROI
          canvas.drawRect(uiAnnotation, labelColorPaint..style = PaintingStyle.stroke);
          canvas.drawRect(uiAnnotation, labelFillPaint);
          // Draw Annotation Label
          Rect labelAnnotation = Rect.fromLTWH(
            uiAnnotation.left,
            uiAnnotation.top - (6 * (1- zoom)) - textPainter.height,
            (66 * (1- zoom)) + textPainter.width,
            (6 * (1- zoom)) + textPainter.height
          );
          canvas.drawRect(labelAnnotation, labelColorPaint..style = PaintingStyle.stroke);
          canvas.drawRect(labelAnnotation, labelColorPaint..style = PaintingStyle.fill);
          textPainter.paint(
            canvas,
            Offset(labelAnnotation.left + labelAnnotation.width * 5 / 88, labelAnnotation.top + labelAnnotation.height / 16)
          );
        }
      }
    }
    else{
      for (tflite.DetectedObject element in annotations) {
        for (tflite.Label label in element.labels) {
          geti.Label? getiLabel = mapper.getGetiLabel(label);
          if(getiLabel != null){
            Paint labelColorPaint = Paint()
              ..color = hexStringInterpreter(getiLabel.color)
              ..strokeCap = StrokeCap.round
              ..strokeWidth = strokeWidth;
            Paint labelFillPaint = Paint()
              ..color = hexStringInterpreter(getiLabel.color).withOpacity(0.4)
              ..style = PaintingStyle.fill
              ..strokeCap = StrokeCap.round
              ..strokeWidth = strokeWidth;
 
            Rect uiAnnotation = rotatedRect(element.boundingBox, displaySize);
            // print("UI - $uiAnnotation; RAW - ${element.boundingBox}; IMG - $absoluteImageSize; RENDERrrrrr - $displaySize");
            TextStyle textStyle = (labelStyle ?? const TextStyle()).copyWith(color: Colors.black, fontSize: 25.0, fontWeight: FontWeight.w600);
            TextSpan textSpan = TextSpan(text: '${getiLabel.name} ${(label.confidence * 100).round()}%', style: textStyle);
            TextPainter textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
            textPainter.layout(minWidth: 0.0, maxWidth: double.infinity);
            // Draw Annotation ROI
            canvas.drawRect(uiAnnotation, labelColorPaint..style = PaintingStyle.stroke);
            canvas.drawRect(uiAnnotation, labelFillPaint);
            // Draw Annotation Label
            Rect labelAnnotation = Rect.fromLTWH(
              uiAnnotation.left,
              uiAnnotation.top - (6 * (1- zoom)) - textPainter.height,
              (66 * (1- zoom)) + textPainter.width,
              (6 * (1- zoom)) + textPainter.height
            );
            canvas.drawRect(labelAnnotation, labelColorPaint..style = PaintingStyle.stroke);
            canvas.drawRect(labelAnnotation, labelColorPaint..style = PaintingStyle.fill);
            textPainter.paint(
              canvas,
              Offset(labelAnnotation.left + labelAnnotation.width * 5 / 88, labelAnnotation.top + labelAnnotation.height / 16)
            );
          }
        }
      }
    }
  }
 
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
