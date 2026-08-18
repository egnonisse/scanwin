/// Niveau de contributeur selon le nombre de reçus validés.
enum ContributorTier {
  bronze,
  silver,
  gold;

  static ContributorTier fromContributions(int contributions) {
    if (contributions >= 100) return ContributorTier.gold;
    if (contributions >= 25) return ContributorTier.silver;
    return ContributorTier.bronze;
  }

  String get label => switch (this) {
        ContributorTier.bronze => 'Bronze',
        ContributorTier.silver => 'Argent',
        ContributorTier.gold => 'Or',
      };

  /// Seuil suivant (null = niveau maximum atteint).
  int? get nextThreshold => switch (this) {
        ContributorTier.bronze => 25,
        ContributorTier.silver => 100,
        ContributorTier.gold => null,
      };
}

/// Profil contributeur (points + reçus validés).
class ContributorProfile {
  const ContributorProfile({
    required this.points,
    required this.contributions,
  });

  final int points;
  final int contributions;

  ContributorTier get tier =>
      ContributorTier.fromContributions(contributions);
}
