import 'package:flutter/material.dart';

import '../services/image_upload_service.dart';

/// Champ d'image partagé (upload Storage + aperçu), utilisé par les pages
/// Campagnes et Notifications.
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.prefix,
    required this.initialUrl,
    this.onChanged,
  });

  final String prefix;
  final String? initialUrl;
  final ValueChanged<String?>? onChanged;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  static const _uploadService = ImageUploadService();

  String? _url;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  Future<void> _pick() async {
    setState(() => _uploading = true);
    try {
      final result = await _uploadService.pickAndUpload(
        prefix: widget.prefix,
        existingUrl: _url,
      );
      if (!mounted) return;
      if (result == null) {
        // Échec silencieux de l'upload : informer l'utilisateur.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload de l\'image impossible. Vérifie ta connexion et '
              'réessaie (Ctrl+F5 si le problème persiste).',
            ),
          ),
        );
      } else if (result != _url) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image téléversée ✅')),
        );
      }
      setState(() {
        _url = result;
        _uploading = false;
      });
      widget.onChanged?.call(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload : $e')),
      );
    }
  }

  Future<void> _remove() async {
    await _uploadService.deleteByUrl(_url);
    if (!mounted) return;
    setState(() => _url = null);
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image (optionnelle)', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_url != null && _url!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  _url!,
                  width: 96,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 96,
                    height: 64,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                width: 96,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pick,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(_uploading ? 'Upload…' : 'Choisir une image'),
                  ),
                  if (_url != null && _url!.isNotEmpty)
                    TextButton(
                      onPressed: _remove,
                      child: const Text('Retirer l\'image'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
