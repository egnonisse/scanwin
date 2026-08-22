/// Annonce (popup in-app) pilotée depuis le dashboard admin.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.ctaLabel,
    this.ctaUrl,
    this.oncePerUser = true,
  });

  final String id;
  final String title;
  final String message;

  /// 'promo' | 'rappel' | 'info'.
  final String type;

  final String? ctaLabel;
  final String? ctaUrl;

  /// true = affichée une seule fois par utilisateur (mémorisé localement).
  final bool oncePerUser;

  bool get hasCta =>
      ctaLabel != null && ctaLabel!.isNotEmpty && ctaUrl != null && ctaUrl!.isNotEmpty;
}
