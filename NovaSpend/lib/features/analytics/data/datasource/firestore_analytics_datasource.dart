import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/features/analytics/data/models/monthly_summary_model.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';

class FirestoreAnalyticsDatasource {
  FirestoreAnalyticsDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _summaries(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.monthlySummaries);

  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth) {
    return _summaries(uid).doc(yearMonth).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MonthlySummaryModel.fromFirestore(doc).toEntity();
    });
  }

  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  }) {
    return _summaries(uid)
        .orderBy('yearMonth', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => MonthlySummaryModel.fromFirestore(d).toEntity())
          .toList();
    });
  }
}
