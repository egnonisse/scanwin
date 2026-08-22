import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page générique « Informations légales » : lit le contenu depuis Firestore
/// (piloté par le dashboard) avec un texte par défaut embarqué si absent.
///
/// Clé : privacy | consent | medical | terms | legal.
class LegalPageView extends StatelessWidget {
  const LegalPageView({
    super.key,
    required this.pageKey,
    required this.defaultTitle,
    required this.defaultContent,
  });

  final String pageKey;
  final String defaultTitle;
  final String defaultContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(defaultTitle)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('legalPages')
            .where('key', isEqualTo: pageKey)
            .snapshots(),
        builder: (context, snapshot) {
          String title = defaultTitle;
          String content = defaultContent;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final data = snapshot.data!.docs.first.data() as Map?;
            final customTitle = data?['title']?.toString();
            final customContent = data?['content']?.toString();
            if (customTitle != null && customTitle.trim().isNotEmpty) {
              title = customTitle.trim();
            }
            if (customContent != null && customContent.trim().isNotEmpty) {
              content = customContent.trim();
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...content.split('\n\n').map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraph.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
              if (pageKey == 'legal') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('mailto:contact@pharmascan.app'),
                  ),
                  icon: const Icon(Icons.email),
                  label: const Text('Contacter par email'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
