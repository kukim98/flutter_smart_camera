import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as tflite;
import 'package:intel_geti_api/intel_geti_api.dart' as geti;

class TfliteGetiLabelMapper {
  final Map<tflite.Label, geti.Label> _mapper = const {};

  TfliteGetiLabelMapper();

  /// Add a label pair to [_mapper].
  /// 
  /// This replaces the old pairing if [tfliteLabel]
  /// already exists in [_mapper].
  /// If [tfliteLabel] is newly introduced to [_mapper],
  /// then a new entry is added to [_mapper].
  void updatePair({required tflite.Label tfliteLabel, required geti.Label getiLabel}) => _mapper[tfliteLabel] = getiLabel;
  
  /// Remove a label pair from [_mapper].
  void removePair({required tflite.Label tfliteLabel}) => _mapper.remove(tfliteLabel);

  /// Return GETi label for the TFlite label.
  /// 
  /// If a pair for [tfliteLabel] does not exist,
  /// then null is returned instead.
  geti.Label? getGetiLabel(tflite.Label tfliteLabel) => _mapper[tfliteLabel];

  /// Whether Tflite annotations should be displayed or not.
  /// 
  /// This is done by checking whether [_mapper] is empty.
  bool get isTfliteViewMode => _mapper.isEmpty;
}