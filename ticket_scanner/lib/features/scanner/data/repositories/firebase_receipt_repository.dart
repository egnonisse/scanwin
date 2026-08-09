import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_repository.dart';

class FirebaseReceiptRepository implements ReceiptRepository {
  const FirebaseReceiptRepository();

  @override
  Future<int> submitReceipt({
    required String pharmacyName,
    required String dateTicket,
    required double montant,
    required List<ReceiptItem> items,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('submitReceipt');

    try {
      final result = await callable.call({
        'pharmacyName': pharmacyName,
        'dateTicket': dateTicket,
        'montant': montant,
        'items': [
          for (final item in items)
            {'name': item.name, 'price': item.price, 'quantity': item.quantity},
        ],
      });
      final data = result.data;
      if (data is Map && data['pointsAdded'] is num) {
        return (data['pointsAdded'] as num).toInt();
      }
      throw const ReceiptSubmissionException();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw const ReceiptAlreadySubmittedException();
      }
      throw const ReceiptSubmissionException();
    }
  }
}
