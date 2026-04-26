import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  final String label;
  final double confidence;
  final List<double> scores;

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.scores,
  });
}

class ModelService {
  Interpreter? _interpreter;

  // Change this only if your exported model uses a different class order.
  final List<String> labels = const ['overripe', 'ready', 'unripe'];

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    _interpreter ??=
        await Interpreter.fromAsset('assets/model/tflite_learn_968734_5.tflite');
  }

  Future<PredictionResult> predictImage(File imageFile) async {
    if (_interpreter == null) {
      throw Exception('Model is not loaded');
    }

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Failed to decode image');
    }

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    final inputShape = inputTensor.shape; // Usually [1, 96, 96, 3]
    final outputShape = outputTensor.shape; // Usually [1, 3]

    final int inputHeight = inputShape[1];
    final int inputWidth = inputShape[2];
    final int classCount = outputShape.last;

    final resized = img.copyResize(
      decoded,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.average,
    );

    // Float32 input: normalize to 0..1
    final input = List.generate(
      1,
      (_) => List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          },
        ),
      ),
    );

    final output = List.generate(
      1,
      (_) => List<double>.filled(classCount, 0.0),
    );

    _interpreter!.run(input, output);

    final scores = List<double>.from(output[0]);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);

    return PredictionResult(
      label: labels[maxIndex],
      confidence: maxScore,
      scores: scores,
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}