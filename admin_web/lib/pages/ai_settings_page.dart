import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page « Paramètres IA » — configuration du LLM de structuration des reçus.
///
/// Stockée dans aiSettings/default (règles Firestore : admin uniquement).
/// La Cloud Function parseReceiptWithAI lit ce doc à chaque appel.
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();

  String _provider = 'deepseek';
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('aiSettings')
        .doc('default')
        .get();
    if (!doc.exists || !mounted) return;
    final data = doc.data() ?? const {};
    setState(() {
      _provider = data['provider']?.toString() ?? 'deepseek';
      _enabled = data['enabled'] as bool? ?? true;
      _apiKeyController.text = data['apiKey']?.toString() ?? '';
      _modelController.text = data['model']?.toString() ?? '';
      _baseUrlController.text = data['baseUrl']?.toString() ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('aiSettings')
          .doc('default')
          .set({
        'enabled': _enabled,
        'provider': _provider,
        'model': _modelController.text.trim(),
        'baseUrl': _baseUrlController.text.trim(),
        'apiKey': _apiKeyController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Réglages IA enregistrés. Teste depuis l\'app en scannant '
                'un reçu.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Paramètres IA', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'L\'IA structure les reçus scannés (montants, dates, items, '
          'quantités) à partir du texte OCR. L\'image du reçu n\'est jamais '
          'envoyée — texte seul.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('IA activée'),
                    subtitle: const Text(
                        'Désactivée → l\'app utilise le parser local (moins fiable)'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur IA',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'deepseek',
                          child: Text('DeepSeek (recommandé)')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom (URL OpenAI-compatible)')),
                    ],
                    onChanged: (v) =>
                        setState(() => _provider = v ?? 'deepseek'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Modèle',
                      hintText: 'deepseek-chat, gpt-4o-mini…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'URL de l\'API (optionnel — pour custom)',
                      hintText: _provider == 'custom'
                          ? 'https://…/chat/completions'
                          : 'Laissé vide = URL officielle du fournisseur',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Clé API',
                      hintText: 'sk-…',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (_enabled && (v == null || v.trim().isEmpty))
                            ? 'Clé requise quand l\'IA est activée'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La clé est stockée dans Firestore, lisible uniquement '
                    'par les administrateurs (règles de sécurité).',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}
