class PointsEvent {
  const PointsEvent({
    required this.id,
    required this.pointsAdded,
    required this.createdAtMillis,
    required this.receiptId,
    required this.amount,
  });

  final String id;
  final int pointsAdded;
  final int createdAtMillis;
  final String? receiptId;
  final double? amount;
}

