import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_scanner/features/home/domain/entities/contributor_profile.dart';

void main() {
  group('ContributorProfile (tier basé sur les points)', () {
    test('Bronze en dessous de 200 points (défaut)', () {
      const p0 = ContributorProfile(points: 0, contributions: 0);
      const p199 = ContributorProfile(points: 199, contributions: 2);
      expect(p0.tier, ContributorTier.bronze);
      expect(p199.tier, ContributorTier.bronze);
    });

    test('Argent entre 200 et 499 (défauts)', () {
      const p200 = ContributorProfile(points: 200, contributions: 5);
      const p499 = ContributorProfile(points: 499, contributions: 20);
      expect(p200.tier, ContributorTier.silver);
      expect(p499.tier, ContributorTier.silver);
    });

    test('Or à partir de 500 (défaut)', () {
      const p500 = ContributorProfile(points: 500, contributions: 60);
      expect(p500.tier, ContributorTier.gold);
    });

    test('seuils configurables (dashboard)', () {
      const profile = ContributorProfile(
        points: 100,
        contributions: 10,
        bronzeThreshold: 50,
        silverThreshold: 100,
        goldThreshold: 300,
      );
      expect(profile.tier, ContributorTier.silver);
      expect(profile.nextThreshold, 300);
      expect(profile.pointsToNext, 200);
    });

    test('seuils suivants par défaut', () {
      const bronze = ContributorProfile(points: 10, contributions: 1);
      const silver = ContributorProfile(points: 250, contributions: 10);
      const gold = ContributorProfile(points: 600, contributions: 80);
      expect(bronze.tier, ContributorTier.bronze);
      expect(bronze.nextThreshold, 200);
      expect(silver.tier, ContributorTier.silver);
      expect(silver.nextThreshold, 500);
      expect(gold.tier, ContributorTier.gold);
      expect(gold.nextThreshold, isNull);
      expect(gold.pointsToNext, isNull);
    });

    test('pointsToNext clampé (jamais négatif)', () {
      const profile = ContributorProfile(
        points: 250,
        contributions: 30,
        bronzeThreshold: 50,
        silverThreshold: 200,
        goldThreshold: 500,
      );
      expect(profile.pointsToNext, 250);
    });
  });
}
