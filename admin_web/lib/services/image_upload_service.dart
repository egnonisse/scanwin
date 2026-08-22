import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Service d'upload d'images vers Firebase Storage (dashboard admin).
class ImageUploadService {
  const ImageUploadService();

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Choisit une image (galerie) et l'uploade dans `prefix`.
  /// Retourne l'URL de téléchargement, ou `existingUrl` si annulé, ou null.
  Future<String?> pickAndUpload({
    required String prefix,
    String? existingUrl,
  }) async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return existingUrl;

    final bytes = await picked.readAsBytes();
    return uploadBytes(bytes: bytes, prefix: prefix, fileName: picked.name);
  }

  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String prefix,
    required String fileName,
  }) async {
    // Nom unique pour éviter les collisions de cache.
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final safeName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref('$prefix/$safeName');
    try {
      final task = await ref.putData(bytes);
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Supprime une ancienne image (si l'URL appartient au bucket).
  Future<void> deleteByUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // L'image n'existe plus ou n'appartient pas au bucket : ignorer.
    }
  }
}
