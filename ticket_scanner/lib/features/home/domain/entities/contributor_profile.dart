/// Niveau de contributeur selon les points accumulés.
enum ContributorTier {
  bronze,
  silver,
  gold;

  String get label => switch (this) {
        ContributorTier.bronze => 'Bronze',
        ContributorTier.silver => 'Argent',
        ContributorTier.gold => 'Or',
      };
}

/// Seuils par défaut (remplacés par pointsConfig dans le dashboard).
const defaultBronzeThreshold = 50;
const defaultSilverThreshold = 200;
const defaultGoldThreshold = 500;

/// Profil contributeur (points + reçus validés + seuils de niveaux).
class ContributorProfile {
  const ContributorProfile({
    required this.points,
    required this.contributions,
    this.bronzeThreshold = defaultBronzeThreshold,
    this.silverThreshold = defaultSilverThreshold,
    this.goldThreshold = defaultGoldThreshold,
  });

  final int points;
  final int contributions;

  /// Seuils configurables depuis le dashboard (pointsConfig).
  final int bronzeThreshold;
  final int silverThreshold;
  final int goldThreshold;

  ContributorTier get tier {
    if (points >= goldThreshold) return ContributorTier.gold;
    if (points >= silverThreshold) return ContributorTier.silver;
    return ContributorTier.bronze;
  }

  /// Seuil de points du niveau suivant (null = niveau maximum atteint).
  int? get nextThreshold => switch (tier) {
        ContributorTier.bronze => silverThreshold,
        ContributorTier.silver => goldThreshold,
        ContributorTier.gold => null,
      };

  /// Points restants avant le niveau suivant.
  int? get pointsToNext {
    final next = nextThreshold;
    if (next == null) return null;
    return (next - points).clamp(0, next);
  }
}
