import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prétraite la photo d'un reçu avant OCR (ML Kit).
///
/// Les reçus thermiques sont souvent pâles : un contraste renforcé améliore
/// nettement la reconnaissance des caractères. L'image est re-encodée en JPEG
/// (qualité 92) pour être relue par [InputImage.fromFilePath].
class ReceiptImagePreprocessor {
  const ReceiptImagePreprocessor();

  /// Contraste appliqué (1.0 = aucun, 1.4 = renforcé).
  static const double contrast = 1.4;

  Uint8List process(Uint8List bytes) {
    final img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      // Bytes illisibles (ex: fichier corrompu) → on laisse l'OCR tenter seul.
      return bytes;
    }
    if (image == null) return bytes;

    img.adjustColor(
      image,
      contrast: contrast,
      saturation: 1.0,
      brightness: 0,
    );

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }
}
