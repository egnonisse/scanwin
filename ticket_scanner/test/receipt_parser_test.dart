import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_scanner/features/scanner/domain/services/receipt_parser.dart';

void main() {
  const parser = ReceiptParser();

  group('ReceiptParser.parse', () {
    test('extrait un reçu type LAOULO (somme des items + heure)', () {
      const raw = 'PHARMACIE LAOULO\n'
          'THERMOMETRE MED MERC 1500\n'
          'Montant Versé 2000\n'
          '26-07-2026 21:18';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, 'PHARMACIE LAOULO');
      expect(result.items, hasLength(1));
      expect(result.items[0].name, 'THERMOMETRE MED MERC');
      expect(result.items[0].price, 1500);
      // Pas de TOTAL explicite → somme des items (1500, PAS le versé 2000).
      expect(result.montantTotal, 1500);
      expect(result.dateTicket, '26-07-2026');
      expect(result.heureTicket, '21:18');
    });

    test('ignore « Montant Versé » comme total', () {
      const raw = 'PHARMACIE X\n'
          'PARACETAMOL 500\n'
          'Montant Versé 2000';

      final result = parser.parse(rawText: raw);

      expect(result.montantTotal, 500);
      expect(result.items, hasLength(1));
    });

    test('parse le vrai format ML Kit du reçu LAOULO (colonnes)', () {
      const raw = 'THERMOMETRE MED MERC1300\n'
          '1 500\n'
          'Net à payer: Especes 1 500 F CFA\n'
          '-07-2026 21 15 39\n'
          'PHARMACIE LAOULO';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, 'PHARMACIE LAOULO');
      // Nom sans prix + prix sur la ligne suivante (reçus à colonnes).
      expect(result.items, hasLength(1));
      expect(result.items[0].name, 'THERMOMETRE MED MERC1300');
      expect(result.items[0].price, 1500);
      // "Net à payer" (avec à accentué) → 1500, pas le Versé.
      expect(result.montantTotal, 1500);
      // Heure "21 15" avec espaces → normalisée "21:15".
      expect(result.heureTicket, '21:15');
    });

    test('rejette Règlement/F CFA et capte MERC1500 (reçu réel ML Kit)', () {
      const raw = 'PHARMACIE LAOULO\n'
          'Montant Versė\n'
          'Règlement.\n'
          '2 000\n'
          'F CFA\n'
          'Especes\n'
          'Net à payer:\n'
          '1500\n'
          'F CFA\n'
          'THERMOMETRE MED\n'
          'MERC1500\n'
          '1\n'
          '500\n'
          'QTE\n'
          'ARTICLES\n'
          'PU\n'
          'MMONTANT\n'
          'Ticket N° 1639547227\n'
          '26-07-2026 21 15 39';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, 'PHARMACIE LAOULO');
      // Un seul item : le thermomètre (MERC + 1500 collés).
      expect(result.items, hasLength(1));
      expect(result.items[0].name, 'MERC');
      expect(result.items[0].price, 1500);
      expect(result.montantTotal, 1500);
      expect(result.heureTicket, '21:15');
    });

    test('extrait un reçu ivoirien typique', () {
      const raw = 'PHARMACIE DU PLATEAU\n'
          '31/03/2025\n'
          'PARACETAMOL 500MG 500\n'
          'AMOXICILLINE 1G 2000 FCFA\n'
          'TOTAL: 2500';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, 'PHARMACIE DU PLATEAU');
      expect(result.dateTicket, '31/03/2025');
      expect(result.montantTotal, 2500);
      expect(result.items, hasLength(2));
      expect(result.items[0].name, 'PARACETAMOL 500MG');
      expect(result.items[0].price, 500);
      expect(result.items[1].name, 'AMOXICILLINE 1G');
      expect(result.items[1].price, 2000);
      expect(result.isValidForMvp, isTrue);
    });

    test('détecte la quantité (2X)', () {
      const raw = 'PHARMACIE X\n'
          '2X DOLIPRANE 500 1000\n'
          'TOTAL 1000';

      final result = parser.parse(rawText: raw);

      expect(result.items, hasLength(1));
      expect(result.items[0].name, 'DOLIPRANE 500');
      expect(result.items[0].price, 1000);
      expect(result.items[0].quantity, 2);
    });

    test('montant avec point décimal', () {
      const raw = 'PHARMACIE Y\n'
          'SIROP TUSSIDEX 1500.50\n'
          'MONTANT TOTAL 1500.50';

      final result = parser.parse(rawText: raw);

      expect(result.items[0].price, 1500.5);
      expect(result.montantTotal, 1500.5);
    });

    test('ignore les lignes non-médicament', () {
      const raw = 'PHARMACIE Z\n'
          'MERCI DE VOTRE VISITE\n'
          'N 123456\n'
          '01-04-2025\n'
          'PARACETAMOL 300\n'
          'TOTAL 300';

      final result = parser.parse(rawText: raw);

      expect(result.items, hasLength(1));
      expect(result.items[0].name, 'PARACETAMOL');
      expect(result.montantTotal, 300);
    });

    test('rejette les prix non plausibles (inférieurs à 50 FCFA)', () {
      const raw = 'PHARMACIE A\n'
          'VITAMINE C 10\n'
          'TOTAL 10';

      final result = parser.parse(rawText: raw);

      expect(result.items, isEmpty);
    });

    test('ne détecte rien sur un texte sans reçu', () {
      const raw = '1234 5678\n8901';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, isNull);
      expect(result.montantTotal, isNull);
      expect(result.dateTicket, isNull);
      expect(result.items, isEmpty);
      expect(result.isValidForMvp, isFalse);
    });

    test('extrait la date avec tirets', () {
      const raw = 'PHARMACIE B\n'
          '01-04-2025\n'
          'ASPIRINE 100\n'
          'TOTAL 100';

      final result = parser.parse(rawText: raw);

      expect(result.dateTicket, '01-04-2025');
    });

    test('pharmacie sans le mot "pharmacie"', () {
      const raw = 'GRAND AIR\n'
          '02/04/2025\n'
          'QUININE 250\n'
          'TOTAL 250';

      final result = parser.parse(rawText: raw);

      expect(result.pharmacyName, 'GRAND AIR');
    });
  });
}
