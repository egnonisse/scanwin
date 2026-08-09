import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/services/receipt_parser.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({required ReceiptParser parser})
      : _parser = parser,
        super(const ScannerState.initial());

  final ReceiptParser _parser;

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
      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer();
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final extraction = _parser.parse(rawText: recognizedText.text);
        emit(state.copyWith(isLoading: false, extraction: extraction));
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
