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
    test('upscale ×2 les petites images et produit une image valide', () {
      final input = jpegBytes(64, 32);
      final output = preprocessor.process(input);

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull, reason: 'La sortie doit être une image valide');
      // 64×32 < 1600 px de large → upscale ×2.
      expect(decoded!.width, 128);
      expect(decoded.height, 64);
    });

    test('conserve les dimensions des grandes images (≥ 1600 px)', () {
      final input = jpegBytes(2000, 200);
      final output = preprocessor.process(input);

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2000);
      expect(decoded.height, 200);
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
