import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/receipt_image_preprocessor.dart';
import '../../domain/services/receipt_parser.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({
    required ReceiptParser parser,
    ReceiptImagePreprocessor? preprocessor,
  })  : _parser = parser,
        _preprocessor = preprocessor ?? const ReceiptImagePreprocessor(),
        super(const ScannerState.initial());

  final ReceiptParser _parser;
  final ReceiptImagePreprocessor _preprocessor;

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> scanFromCamera() async {
    emit(state.copyWith(isLoading: true, errorMessage: null, extraction: null));

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Scan annulé.'));
      return;
    }

    try {
      // Prétraitement : contraste renforcé (reçus thermiques pâles).
      final bytes = await photo.readAsBytes();
      final processedBytes = _preprocessor.process(bytes);
      final tmpFile = File(
        '${Directory.systemTemp.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tmpFile.writeAsBytes(processedBytes);

      final inputImage = InputImage.fromFilePath(tmpFile.path);
      final textRecognizer = TextRecognizer();
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text;
        // Log OCR brut : indispensable pour déboguer l'extraction.
        debugPrint('[OCR] rawText:\n$rawText');
        final extraction = _parser.parse(rawText: rawText);
        emit(
          state.copyWith(
            isLoading: false,
            extraction: extraction,
            imagePath: tmpFile.path,
          ),
        );
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'OCR impossible. Vérifie l’image et réessaie.',
        ),
      );
    }
  }

  Future<void> clear() async {
    emit(const ScannerState.initial());
  }
}
