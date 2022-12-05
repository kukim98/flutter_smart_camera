import 'dart:async';
 
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_camera/util/tflite_geti_label_mapper.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as tflite;

import '../data_structure/tflite_model.dart';
import '../util/tflite_annotation_painter.dart';
import '../util/tflite_object_detector.dart';
 
enum ScreenMode { liveFeed, gallery }
 
class SmartCamera extends StatefulWidget {
  late TfliteModel model;
  final TfliteGetiLabelMapper mapper;
  final Function(ScreenMode mode)? onScreenModeChanged;
  final CameraLensDirection initialDirection;
  final Function(CameraImage, Size, int, List<tflite.DetectedObject>)? onInference;
  final TfliteObjectDetector objectDetector;
  final List<CameraDescription> cameras;

  SmartCamera({
    Key? key,
    this.onScreenModeChanged,
    this.initialDirection = CameraLensDirection.back,
    required this.mapper,
    String? modelName,
    this.onInference,
    required this.objectDetector,
    required this.cameras
  }) : super(key: key) {
    model = (modelName == null) ? TfliteModelGarden.defaultModel() : TfliteModelGarden.models.firstWhere((element) => element.modelCategory == modelName);
  }
 
  @override
  State<SmartCamera> createState() => SmartCameraState();
}
 
class SmartCameraState extends State<SmartCamera> {
  CameraController? _controller;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  Size? _absoluteImageSize;
  late CameraPreview cam;
  late Widget drawing;
  late DeviceOrientation originalOrientation;
  late DeviceOrientation orientation;
 
  bool _isBusy = false;
 
  XFile? annotatedImage;
 
  StreamController<Uint8List> scon = StreamController<Uint8List>.broadcast();
  StreamController<List<tflite.DetectedObject>> annotationStream = StreamController<List<tflite.DetectedObject>>.broadcast();
 
  @override
  void initState() {
    super.initState();
    if (widget.cameras.any(
      (element) =>
          element.lensDirection == widget.initialDirection &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = widget.cameras.indexOf(
        widget.cameras.firstWhere((element) =>
            element.lensDirection == widget.initialDirection &&
            element.sensorOrientation == 90),
      );
    } else {
      _cameraIndex = widget.cameras.indexOf(
        widget.cameras.firstWhere(
          (element) => element.lensDirection == widget.initialDirection,
        ),
      );
    }

    _startLiveFeed();
  }
 
  Future _startLiveFeed() async {
    final camera = widget.cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
 
      _controller?.lockCaptureOrientation();
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      originalOrientation = _controller!.value.deviceOrientation;
      orientation = originalOrientation;
      setState(() {});
    });
  }
 
  Future _stopLiveFeed() async {
    if (_controller?.value.isStreamingImages == true) {
      await _controller?.stopImageStream();
    }
    await _controller?.dispose();
    _controller = null;
  }
 
  @override
  void dispose() {
    widget.objectDetector.dispose();
    _stopLiveFeed();
    super.dispose();
  }
 
  Future<XFile> getSnapshot() async {
    await _controller!.initialize();
    XFile res = await _controller!.takePicture();
    return res;
  }
 
  Future<void> enableCallback() async {
    await _controller?.startImageStream(_processCameraImage);
  }
 
  Future<void> disableCallback() async {
    await _controller?.stopImageStream();
  }
 
  Widget rotatedWidget(
      {required Widget child, required DeviceOrientation orentation, bool reverse = false}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }
 
    int r = _getQuarterTurns(orentation);
    return RotatedBox(
      quarterTurns: (reverse) ? -1 * r : r,
      child: child,
    );
  }
 
  int _getQuarterTurns(DeviceOrientation orentation) {
    return (turns.length + turns[orentation]! - turns[originalOrientation]!) % turns.length;
  }
 
  Map<DeviceOrientation, int> turns = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeRight: 1,
    DeviceOrientation.portraitDown: 2,
    DeviceOrientation.landscapeLeft: 3,
  };
 
  @override
  Widget build(BuildContext context) {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }
    return StreamBuilder<DeviceOrientationChangedEvent>(
      stream: CameraPlatform.instance.onDeviceOrientationChanged(),
      builder: (BuildContext context, AsyncSnapshot<DeviceOrientationChangedEvent> snapshot){
        if (snapshot.data == null){
          return rotatedWidget(
            child: CameraPreview(
              _controller!,
              child: StreamBuilder<List<tflite.DetectedObject>>(
                stream: annotationStream.stream,
                initialData: const [],
                builder: (BuildContext context, AsyncSnapshot<List<tflite.DetectedObject>> snapshot){
                  if (context.findRenderObject() != null){
                    return CustomPaint(
                      painter: TfliteRawAnnotationPainter(
                        displaySize: (context.findRenderObject() as RenderBox).size,
                        annotations: snapshot.data!,
                        absoluteImageSize: _absoluteImageSize,
                        mapper: widget.mapper,
                        model: widget.model,
                        flipDimension: originalOrientation == DeviceOrientation.portraitDown || originalOrientation == DeviceOrientation.portraitUp
                      ),
                    );
                  }
                  else{
                    return Container();
                  }
                }
              )
            ),
            orentation: originalOrientation
          );
        }
        orientation = snapshot.data!.orientation;
        return rotatedWidget(
          child: CameraPreview(
            _controller!,
            child: rotatedWidget(child: StreamBuilder<List<tflite.DetectedObject>>(
              stream: annotationStream.stream,
              initialData: const [],
              builder: (BuildContext context, AsyncSnapshot<List<tflite.DetectedObject>> snapshot){
                if (context.findRenderObject() != null){
                  return CustomPaint(
                    painter: TfliteRawAnnotationPainter(
                      displaySize: (context.findRenderObject() as RenderBox).size,
                      annotations: snapshot.data!,
                      absoluteImageSize: _absoluteImageSize,
                      mapper: widget.mapper,
                      model: widget.model,
                      flipDimension: orientation == DeviceOrientation.portraitDown || orientation == DeviceOrientation.portraitUp
                    ),
                  );
                }
                else{
                  return Container();
                }
              }
            ), orentation: orientation, reverse: true)
          ),
          orentation: orientation
        );
      }
    );
  }
 
  Future<void> _processCameraImage(CameraImage image) async {
    // If busy with previous processing of camera input, skip.
    if (_isBusy) return;
    // "MUTEX" Lock
    _isBusy = true;
    // Image preparation
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
 
    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
 
    final camera = widget.cameras[_cameraIndex];
    final imageRotation =
        // InputImageRotationValue.fromRawValue(camera.sensorOrientation + 90);
        InputImageRotationValue.fromRawValue((camera.sensorOrientation + (turns[orientation]! * 90)) % 360);
    if (imageRotation == null) return;
    _absoluteImageSize = imageSize;
 
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return;
 
    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();
    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );
    final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    int rotation = (camera.sensorOrientation + turns[orientation]! * 90) % 360;
    // Running object detection and update view.
    List<tflite.DetectedObject> result = await inference(inputImage, image, imageSize, rotation);
    // Custom processing of image.
    if (widget.onInference != null){
      await widget.onInference!(image, imageSize, rotation, result);
    }
    // "MUTEX" Unlock
    _isBusy = false;
  }

  Future<List<tflite.DetectedObject>> inference(tflite.InputImage image, CameraImage ci, Size size, int rot) async {
    List<tflite.DetectedObject> result = await widget.objectDetector.infer(image);
    annotationStream.add(result);
    return result;
  }
}
