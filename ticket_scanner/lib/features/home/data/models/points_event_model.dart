import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/points_event.dart';

class PointsEventModel {
  const PointsEventModel({
    required this.id,
    required this.pointsAdded,
    required this.createdAt,
    required this.receiptId,
    required this.amount,
  });

  final String id;
  final int pointsAdded;
  final Timestamp? createdAt;
  final String? receiptId;
  final num? amount;

  PointsEvent toEntity() {
    return PointsEvent(
      id: id,
      pointsAdded: pointsAdded,
      createdAtMillis: (createdAt?.millisecondsSinceEpoch) ?? 0,
      receiptId: receiptId,
      amount: amount?.toDouble(),
    );
  }

  static PointsEventModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PointsEventModel(
      id: doc.id,
      pointsAdded: (data['pointsAdded'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
      receiptId: data['receiptId'] as String?,
      amount: data['amount'] as num?,
    );
  }
}

