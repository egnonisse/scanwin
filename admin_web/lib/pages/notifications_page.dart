import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/image_picker_field.dart';

/// Page Notifications — CRUD des popups in-app (annonces).
/// Types : promo, rappel (prise de médicaments), info.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _collection = 'announcements';

  static const _typeIcons = {
    'promo': Icons.local_offer,
    'rappel': Icons.alarm,
    'info': Icons.info,
  };

  static const _typeColors = {
    'promo': Color(0xFF19B28A),
    'rappel': Color(0xFF9C6B30),
    'info': Color(0xFF0E7A5F),
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('createdAt', descending: true)
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
            Row(
              children: [
                Text('Notifications (${docs.length})',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showSendPushDialog(context),
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer un push'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showEditDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle notification'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les notifications actives s\'affichent en popup dans l\'app '
              'au lancement (promo, rappel de prise de médicaments, info). '
              '« Envoyer un push » = notification système immédiate, même '
              'app fermée.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child:
                    Center(child: Text('Aucune notification. Crée la première !')),
              )
            else
              ...docs.map((doc) => _AnnouncementTile(
                    doc: doc,
                    onEdit: () => _showEditDialog(context, doc: doc),
                    onDelete: () => _confirmDelete(context, doc),
                    onToggle: (active) =>
                        doc.reference.update({'active': active}),
                  )),
          ],
        );
      },
    );
  }

  /// Envoi d'un push FCM immédiat à tous les utilisateurs enregistrés.
  Future<void> _showSendPushDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var sending = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Envoyer une notification push'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: 'Titre *', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Message *', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Envoyée immédiatement à tous les appareils (app ouverte '
                    'ou fermée).',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        // Pattern Firestore : le dashboard écrit une
                        // demande, la Cloud Function l'envoie et écrit le
                        // résultat dans le même doc.
                        final ref = await FirebaseFirestore.instance
                            .collection('pushRequests')
                            .add({
                          'title': titleController.text.trim(),
                          'body': bodyController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // ignore: cancel_subscriptions
                        late final StreamSubscription<DocumentSnapshot>
                            subscription;
                        subscription = ref.snapshots().listen((doc) {
                          if (!doc.exists) return;
                          final status = (doc.data()?['status'] as String?) ??
                              'pending';
                          if (status == 'pending') return;
                          subscription.cancel();
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop({
                            'sent': '${doc.data()?['sent'] ?? 0}',
                            'failed': '${doc.data()?['failed'] ?? 0}',
                            if (status == 'error')
                              'error': (doc.data()?['error']?.toString() ??
                                  'Erreur interne'),
                          });
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop({'error': '$e'});
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(sending ? 'Envoi…' : 'Envoyer'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted || !context.mounted) return;
    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec : ${result['error']}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Push envoyé : ${result['sent']} succès, ${result['failed']} échecs'),
        ),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context,
      {QueryDocumentSnapshot? doc}) async {
    final data = doc?.data() as Map<String, dynamic>? ?? const {};
    final formKey = GlobalKey<FormState>();
    final titleController =
        TextEditingController(text: data['title']?.toString() ?? '');
    final messageController =
        TextEditingController(text: data['message']?.toString() ?? '');
    final ctaLabelController =
        TextEditingController(text: data['ctaLabel']?.toString() ?? '');
    final ctaUrlController =
        TextEditingController(text: data['ctaUrl']?.toString() ?? '');
    var type = data['type']?.toString() ?? 'info';
    var active = data['active'] as bool? ?? true;
    var oncePerUser = data['oncePerUser'] as bool? ?? true;
    var imageUrl = data['imageUrl']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(doc == null
              ? 'Nouvelle notification'
              : 'Modifier la notification'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                          labelText: 'Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'promo', child: Text('🎁 Promo')),
                        DropdownMenuItem(
                            value: 'rappel',
                            child: Text('⏰ Rappel (prise de médicaments)')),
                        DropdownMenuItem(
                            value: 'info', child: Text('ℹ️ Info')),
                      ],
                      onChanged: (v) => setDialogState(() => type = v ?? 'info'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                          labelText: 'Titre *', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Message *', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ctaLabelController,
                      decoration: const InputDecoration(
                          labelText: 'Bouton d\'action (ex : Voir l\'offre)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ctaUrlController,
                      decoration: const InputDecoration(
                          labelText: 'URL du bouton (optionnel)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    ImagePickerField(
                      prefix: 'announcementImages',
                      initialUrl: imageUrl,
                      onChanged: (url) => imageUrl = url,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Afficher une seule fois par utilisateur'),
                      subtitle: const Text(
                          'Sinon : réaffichée à chaque lancement de l\'app'),
                      value: oncePerUser,
                      onChanged: (v) =>
                          setDialogState(() => oncePerUser = v),
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
      ),
    );

    if (saved != true || !mounted) return;

    final payload = {
      'title': titleController.text.trim(),
      'message': messageController.text.trim(),
      'type': type,
      'ctaLabel': ctaLabelController.text.trim().isEmpty
          ? null
          : ctaLabelController.text.trim(),
      'ctaUrl': ctaUrlController.text.trim().isEmpty
          ? null
          : ctaUrlController.text.trim(),
      'active': active,
      'oncePerUser': oncePerUser,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };

    if (doc == null) {
      await FirebaseFirestore.instance.collection(_collection).add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await doc.reference.update(payload);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final title = (doc.data() as Map?)?['title'] ?? '?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette notification ?'),
        content: Text('« $title » disparaîtra de l\'app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
    }
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final QueryDocumentSnapshot doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final active = data['active'] as bool? ?? true;
    final type = data['type']?.toString() ?? 'info';
    final icon = _NotificationsPageState._typeIcons[type] ?? Icons.info;
    final color = _NotificationsPageState._typeColors[type] ?? const Color(0xFF0E7A5F);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(data['title']?.toString() ?? '?'),
        subtitle: Text(
          data['message']?.toString() ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: active, onChanged: onToggle),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
