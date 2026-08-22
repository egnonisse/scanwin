import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page « Pages légales » — CRUD des contenus affichés dans l'app
/// (Réglages → Informations légales).
///
/// Clés fixes : privacy (confidentialité), consent (consentement scan),
/// legal (mentions légales), medical (avertissement médical), terms (CGU).
/// L'app lit ces documents et affiche un texte par défaut si absent.
class LegalPagesPage extends StatefulWidget {
  const LegalPagesPage({super.key});

  @override
  State<LegalPagesPage> createState() => _LegalPagesPageState();
}

class _LegalPagesPageState extends State<LegalPagesPage> {
  static const _collection = 'legalPages';

  static const _pages = [
    ('privacy', 'Politique de confidentialité', Icons.privacy_tip),
    ('consent', 'Consentement scan reçus', Icons.fact_check),
    ('medical', 'Avertissement médical / urgence', Icons.health_and_safety),
    ('terms', 'Conditions d\'utilisation', Icons.description),
    ('legal', 'Mentions légales + contact', Icons.gavel),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_collection)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Pages légales',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Ces contenus s\'affichent dans l\'app (Réglages → Informations '
              'légales). Une page sans contenu s\'affiche avec le texte par '
              'défaut embarqué dans l\'app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final (key, title, icon) in _pages)
              _LegalPageTile(
                keyName: key,
                title: title,
                icon: icon,
                doc: docs
                    .where((d) => (d.data() as Map?)?['key'] == key)
                    .firstOrNull,
              ),
          ],
        );
      },
    );
  }
}

class _LegalPageTile extends StatelessWidget {
  const _LegalPageTile({
    required this.keyName,
    required this.title,
    required this.icon,
    required this.doc,
  });

  final String keyName;
  final String title;
  final IconData icon;
  final QueryDocumentSnapshot? doc;

  Future<void> _edit(BuildContext context) async {
    final data = doc?.data() as Map<String, dynamic>? ?? const {};
    final titleController =
        TextEditingController(text: data['title']?.toString() ?? title);
    final contentController =
        TextEditingController(text: data['content']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: 'Titre', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contentController,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Contenu (texte libre)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laisse vide pour utiliser le texte par défaut de l\'app.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final payload = {
      'key': keyName,
      'title': titleController.text.trim(),
      'content': contentController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (doc == null) {
      await FirebaseFirestore.instance.collection('legalPages').add(payload);
    } else {
      await doc!.reference.update(payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = doc != null &&
        ((doc!.data() as Map?)?['content']?.toString().trim().isNotEmpty ??
            false);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(hasContent
            ? 'Personnalisée (${((doc!.data() as Map?)?['content']?.toString().length ?? 0)} caractères)'
            : 'Texte par défaut de l\'app'),
        trailing: IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(context),
        ),
      ),
    );
  }
}
