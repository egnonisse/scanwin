import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_scanner/features/home/domain/entities/contributor_profile.dart';

void main() {
  group('ContributorTier.fromContributions', () {
    test('Bronze jusqu\'à 24 reçus', () {
      expect(ContributorTier.fromContributions(0), ContributorTier.bronze);
      expect(ContributorTier.fromContributions(1), ContributorTier.bronze);
      expect(ContributorTier.fromContributions(24), ContributorTier.bronze);
    });

    test('Argent à partir de 25', () {
      expect(ContributorTier.fromContributions(25), ContributorTier.silver);
      expect(ContributorTier.fromContributions(99), ContributorTier.silver);
    });

    test('Or à partir de 100', () {
      expect(ContributorTier.fromContributions(100), ContributorTier.gold);
      expect(ContributorTier.fromContributions(500), ContributorTier.gold);
    });

    test('seuils suivants', () {
      expect(ContributorTier.bronze.nextThreshold, 25);
      expect(ContributorTier.silver.nextThreshold, 100);
      expect(ContributorTier.gold.nextThreshold, isNull);
    });
  });

  group('ContributorProfile', () {
    test('tier depuis les contributions', () {
      const bronze = ContributorProfile(points: 10, contributions: 3);
      const gold = ContributorProfile(points: 500, contributions: 120);
      expect(bronze.tier, ContributorTier.bronze);
      expect(gold.tier, ContributorTier.gold);
    });
  });
}
