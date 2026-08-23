import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/firebase_campaign_repository.dart';
import '../../domain/entities/campaign.dart';

/// Carrousel de bannières (campagnes pilotées depuis le dashboard admin).
///
/// - PageView horizontal avec auto-scroll (5 s) quand > 1 bannière
/// - Style moderne : aperçu des slides avant/après (viewportFraction),
///   pleine largeur, radius 5px, ombre légère (comme le bloc pharmacies)
/// - Indicateur de position (points)
/// - Clic → ouvre l'URL de la campagne
class CampaignCarousel extends StatefulWidget {
  const CampaignCarousel({super.key});

  @override
  State<CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<CampaignCarousel> {
  static const _repository = FirebaseCampaignRepository();

  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  void _startAutoScroll(int count) {
    _autoScrollTimer?.cancel();
    if (count <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_currentPage + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCampaign(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Campaign>>(
      stream: _repository.watchActiveCampaigns(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final campaigns = snapshot.data!;
        if (campaigns.isEmpty) return const SizedBox.shrink();

        _startAutoScroll(campaigns.length);

        return Column(
          children: [
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _controller,
                itemCount: campaigns.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return _Banner(
                    campaign: campaigns[index],
                    onTap: () =>
                        _openCampaign(campaigns[index].url),
                  );
                },
              ),
            ),
            if (campaigns.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < campaigns.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentPage ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.campaign, required this.onTap});

  final Campaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Léger espace horizontal pour laisser entrevoir les slides voisins.
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              // Bannière IMAGE SEULE (sans fond coloré ni texte) quand une
              // image est fournie. Fallback minimal sinon.
              child: campaign.imageUrl != null && campaign.imageUrl!.isNotEmpty
                  ? Image.network(
                      campaign.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(context),
                    )
                  : _fallback(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Fallback minimal : bandeau sans image (titre seul, fond neutre).
  Widget _fallback(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        campaign.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
