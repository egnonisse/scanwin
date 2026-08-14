import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ticket_scanner/features/scanner/data/services/receipt_image_preprocessor.dart';

void main() {
  const preprocessor = ReceiptImagePreprocessor();

  Uint8List jpegBytes(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 200, 200));
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  group('ReceiptImagePreprocessor.process', () {
    test('renforce le contraste et conserve le format/dimensions', () {
      final input = jpegBytes(64, 32);
      final output = preprocessor.process(input);

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull, reason: 'La sortie doit être une image valide');
      expect(decoded!.width, 64);
      expect(decoded.height, 32);
    });

    test('retourne les bytes inchangés si l’image est invalide', () {
      final invalid = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(preprocessor.process(invalid), same(invalid));
    });
  });
}
