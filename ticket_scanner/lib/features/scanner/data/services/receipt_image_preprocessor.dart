import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prétraite la photo d'un reçu avant OCR (ML Kit).
///
/// Les reçus thermiques sont pâles, petits et souvent froissés. Pipeline :
/// 1. Upscale ×2 si l'image est trop petite (meilleure reconnaissance)
/// 2. Niveau de gris + normalisation (ravive les contrastes faibles)
/// 3. Netteté (kernel sharpen 3×3) — ravive les caractères fanés
/// 4. Binarisation par luminance — noir/blanc net pour l'OCR
/// 5. Ré-encodage JPEG qualité 92
class ReceiptImagePreprocessor {
  const ReceiptImagePreprocessor();

  Uint8List process(Uint8List bytes) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (image == null) return bytes;

    // 1. Upscale ×2 si trop petit (reçus photographiés de loin).
    if (image.width < 1600) {
      image = img.copyResize(
        image,
        width: image.width * 2,
        height: image.height * 2,
        interpolation: img.Interpolation.cubic,
      );
    }

    // 2. Niveau de gris (l'OCR n'a besoin que de luminance).
    image = img.grayscale(image);

    // 3. Netteté : kernel sharpen classique.
    image = img.convolution(
      image,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
    );

    // 4. Binarisation : seuil de luminance 50% → noir/blanc net.
    // Piège connu (15/08/2026) : ne PAS utiliser adjustColor avec
    // `saturation` — bug du package image qui noircit l'image.
    image = img.luminanceThreshold(image, threshold: 0.5);

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }
}
