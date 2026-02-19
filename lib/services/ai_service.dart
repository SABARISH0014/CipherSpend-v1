import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  // Singleton instance
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  List<String>? _labels;

  // These MUST match your Python training script configuration
  final int _maxSentenceLength = 20;
  final String _oovToken = "<OOV>";

  /// Loads the TFLite model and supporting JSON files from assets
  Future<void> loadModel() async {
    try {
      // 1. Load the Model
      // inside lib/services/ai_service.dart
      _interpreter = await Interpreter.fromAsset('assets/sms_model.tflite');

      // 2. Load Vocabulary (Word -> Index)
      final String vocabData = await rootBundle.loadString('assets/vocab.json');
      _vocab = Map<String, int>.from(json.decode(vocabData));

      // 3. Load Labels (Index -> Category Name)
      final String labelData =
          await rootBundle.loadString('assets/labels.json');
      final Map<String, dynamic> rawLabels = json.decode(labelData);

      // Ensure labels are sorted by their index key
      _labels = List.generate(
          rawLabels.length, (index) => rawLabels[index.toString()] ?? "Others");

      print("✅ AI Engine: Model and Vocab loaded successfully.");
    } catch (e) {
      print("❌ AI Engine Error: $e");
    }
  }

  /// Predicts the category of a given SMS body
  String predictCategory(String text) {
    if (_interpreter == null || _vocab == null || _labels == null) {
      return "Uncategorized";
    }

    // 1. Preprocess the text
    List<double> inputSequence = _tokenizeAndPad(text);

    // 2. Prepare input and output tensors
    // Input shape: [1, 20] (Batch size 1, Sequence length 20)
    var input = [inputSequence];
    // Output shape: [1, Number of Categories]
    var output =
        List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

    // 3. Run Inference
    _interpreter!.run(input, output);

    // 4. Find the index with the highest probability
    List<double> probabilities = output[0];
    int bestIndex = 0;
    double maxProb = -1.0;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    return _labels![bestIndex];
  }

  /// Converts raw text into a fixed-length numerical sequence
  List<double> _tokenizeAndPad(String text) {
    // Basic cleanup: lowercase and remove special characters
    String cleanText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    List<String> words = cleanText.split(' ');

    List<double> sequence = List.filled(_maxSentenceLength, 0.0);

    for (int i = 0; i < _maxSentenceLength && i < words.length; i++) {
      String word = words[i];
      if (_vocab!.containsKey(word)) {
        sequence[i] = _vocab![word]!.toDouble();
      } else {
        // Use index for <OOV> (usually 1 if using standard Keras tokenizer)
        sequence[i] = _vocab![_oovToken]?.toDouble() ?? 1.0;
      }
    }

    return sequence;
  }

  void dispose() {
    _interpreter?.close();
  }
}
