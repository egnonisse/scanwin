import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reçu en attente de soumission (scan effectué hors ligne).
class PendingReceipt {
  const PendingReceipt({
    required this.pharmacyName,
    required this.dateTicket,
    required this.montant,
    required this.items,
  });

  final String pharmacyName;
  final String dateTicket;
  final double montant;

  /// Liste de [name, price, quantity].
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> toJson() => {
        'pharmacyName': pharmacyName,
        'dateTicket': dateTicket,
        'montant': montant,
        'items': items,
      };

  factory PendingReceipt.fromJson(Map<String, dynamic> json) {
    return PendingReceipt(
      pharmacyName: json['pharmacyName'] as String? ?? '',
      dateTicket: json['dateTicket'] as String? ?? '',
      montant: (json['montant'] as num?)?.toDouble() ?? 0,
      items: (json['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }
}

/// File d'attente locale (shared_preferences) des reçus scannés hors ligne.
class PendingReceiptStore {
  PendingReceiptStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'pending_receipts_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PendingReceipt>> loadAll() async {
    final prefs = await _instance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PendingReceipt.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(PendingReceipt receipt) async {
    final all = await loadAll();
    all.add(receipt);
    await _save(all);
  }

  Future<void> removeAt(int index) async {
    final all = await loadAll();
    if (index >= 0 && index < all.length) {
      all.removeAt(index);
      await _save(all);
    }
  }

  Future<void> _save(List<PendingReceipt> all) async {
    final prefs = await _instance();
    await prefs.setString(
      _key,
      jsonEncode([for (final r in all) r.toJson()]),
    );
  }
}
