import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../data/services/receipt_ai_parser.dart';
import '../../data/services/receipt_image_preprocessor.dart';
import '../../domain/services/receipt_parser.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({
    required ReceiptParser parser,
    ReceiptImagePreprocessor? preprocessor,
    ReceiptAiParser? aiParser,
    AppAnalytics? analytics,
  })  : _parser = parser,
        _preprocessor = preprocessor ?? const ReceiptImagePreprocessor(),
        _aiParser = aiParser ?? ReceiptAiParser(),
        _analytics = analytics ?? AppAnalytics(),
        super(const ScannerState.initial());

  final ReceiptParser _parser;
  final ReceiptImagePreprocessor _preprocessor;
  final ReceiptAiParser _aiParser;
  final AppAnalytics _analytics;

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> scanFromCamera() async {
    emit(state.copyWith(isLoading: true, errorMessage: null, extraction: null));
    await _analytics.logScanStarted(source: 'camera');

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) {
      await _analytics.logScanFailed(reason: 'cancelled');
      emit(state.copyWith(isLoading: false, errorMessage: 'Scan annulé.'));
      return;
    }

    await _processPhoto(photo);
  }

  Future<void> scanFromGallery() async {
    emit(state.copyWith(isLoading: true, errorMessage: null, extraction: null));
    await _analytics.logScanStarted(source: 'gallery');

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (photo == null) {
      await _analytics.logScanFailed(reason: 'cancelled');
      emit(state.copyWith(isLoading: false, errorMessage: 'Scan annulé.'));
      return;
    }

    await _processPhoto(photo);
  }

  Future<void> clear() async {
    emit(const ScannerState.initial());
  }

  Future<void> _processPhoto(XFile photo) async {
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

        // 1. IA d'abord (reconstruction fiable des reçus thermiques).
        final aiExtraction = await _aiParser.parse(rawText: rawText);
        if (aiExtraction != null && aiExtraction.isValidForMvp) {
          await _analytics.logScanSuccess(
              itemCount: aiExtraction.items.length);
          emit(
            state.copyWith(
              isLoading: false,
              extraction: aiExtraction,
              imagePath: tmpFile.path,
            ),
          );
          return;
        }

        // 2. Fallback : parser local (règles heuristiques).
        final extraction = _parser.parse(rawText: rawText);
        await _analytics.logScanSuccess(itemCount: extraction.items.length);
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
      await _analytics.logScanFailed(reason: 'ocr_error');
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'OCR impossible. Vérifie l’image et réessaie.',
        ),
      );
    }
  }
}
