import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  List<String>? _labels;

  final String _oovToken = "<OOV>";

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/sms_model.tflite');

      final String vocabData = await rootBundle.loadString('assets/vocab.json');
      _vocab = Map<String, int>.from(json.decode(vocabData));

      final String labelData =
          await rootBundle.loadString('assets/labels.json');
      final Map<String, dynamic> rawLabels = json.decode(labelData);

      _labels = List.generate(
          rawLabels.length, (index) => rawLabels[index.toString()] ?? "Others");

      // Verify the dynamic shapes
      print("✅ AI Engine Loaded.");
      print(
          "🔍 Model Input expects: ${_interpreter!.getInputTensors().first.shape}");
      print(
          "🔍 Model Output gives: ${_interpreter!.getOutputTensors().first.shape}");
    } catch (e) {
      print("❌ AI Engine Error: $e");
    }
  }

  String predictCategory(String text) {
    if (_interpreter == null || _vocab == null || _labels == null) {
      return "Uncategorized";
    }

    // 1. DYNAMICALLY ask the model what input shape it needs (e.g., [1, 20] or [1, 60])
    final inputTensor = _interpreter!.getInputTensors().first;
    final expectedInputShape = inputTensor.shape;
    final requiredSequenceLength = expectedInputShape[1];

    // 2. Preprocess text to exactly match the required length
    List<double> inputSequence = _tokenizeAndPad(text, requiredSequenceLength);

    // 3. Build the input tensor mapping perfectly to memory
    var input = Float32List.fromList(inputSequence).reshape(expectedInputShape);

    // 4. DYNAMICALLY ask the model what output shape it returns (e.g., [1, 5])
    final outputTensor = _interpreter!.getOutputTensors().first;
    final expectedOutputShape = outputTensor.shape;

    // Calculate total elements needed for the output buffer
    int totalOutputElements = expectedOutputShape.reduce((a, b) => a * b);
    var output =
        List.filled(totalOutputElements, 0.0).reshape(expectedOutputShape);

    // 5. Run Inference
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print("❌ Inference Error: $e");
      return "Error";
    }

    // 6. Find the highest probability
    // output[0] assumes a batch size of 1, which is standard
    List<double> probabilities = List<double>.from(output[0]);
    int bestIndex = 0;
    double maxProb = -1.0;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    // [NEW] Safety Net: Prevent out-of-bounds crashes
    if (bestIndex >= _labels!.length) {
      print(
          "⚠️ AI predicted unknown index $bestIndex. Defaulting to Uncategorized.");
      return "Uncategorized";
    }

    String result = _labels![bestIndex];
    print(
        "🤖 AI Categorized as: $result (Prob: ${maxProb.toStringAsFixed(2)})");
    return result;
  }

  /// Converts raw text into a numerical sequence dynamically sized to the model's needs
  List<double> _tokenizeAndPad(String text, int targetLength) {
    String cleanText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    List<String> words =
        cleanText.split(' ').where((w) => w.isNotEmpty).toList();

    // Create an exact-sized list of zeros
    List<double> sequence = List.filled(targetLength, 0.0);

    for (int i = 0; i < targetLength && i < words.length; i++) {
      String word = words[i];
      if (_vocab!.containsKey(word)) {
        sequence[i] = _vocab![word]!.toDouble();
      } else {
        sequence[i] = _vocab![_oovToken]?.toDouble() ?? 1.0;
      }
    }

    return sequence;
  }

  void dispose() {
    _interpreter?.close();
  }
}
