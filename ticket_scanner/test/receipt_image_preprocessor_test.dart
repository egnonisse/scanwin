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

    test('ne produit pas une image noire (régression saturation bug)', () {
      // Bug 15/08/2026 : adjustColor(contrast, saturation:1.0) → image noire.
      // Une image grise doit rester grise (luminosité > 100), pas tomber à 0.
      final input = jpegBytes(64, 32);
      final output = preprocessor.process(input);

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      var sum = 0;
      var count = 0;
      for (final p in decoded!) {
        sum += (p.r + p.g + p.b) ~/ 3;
        count++;
      }
      final luminance = sum ~/ count;
      expect(
        luminance,
        greaterThan(100),
        reason: 'Luminosité $luminance : le prétraitement a noirci l\'image '
            '(bug saturation du package image).',
      );
    });
  });
}
