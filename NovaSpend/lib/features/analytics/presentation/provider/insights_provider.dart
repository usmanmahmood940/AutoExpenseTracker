import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';

class InsightsProvider extends ChangeNotifier {
  InsightsProvider({required AnalyticsRepository repository})
      : _repository = repository;

  final AnalyticsRepository _repository;

  StreamSubscription<MonthlySummaryEntity?>? _summarySub;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  MonthlySummaryEntity? summary;
  bool isLoading = true;
  String? error;
  String? _uid;

  DateTime get month => _month;
  String get yearMonth => DateFormat('yyyy-MM').format(_month);

  void start(String uid) {
    _uid = uid;
    _listen();
  }

  void previousMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    _listen();
    notifyListeners();
  }

  void nextMonth() {
    final now = DateTime.now();
    final candidate = DateTime(_month.year, _month.month + 1);
    if (candidate.isAfter(DateTime(now.year, now.month))) return;
    _month = candidate;
    _listen();
    notifyListeners();
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    _summarySub?.cancel();
    isLoading = true;
    notifyListeners();

    _summarySub = _repository.watchSummary(uid, yearMonth).listen(
      (value) {
        summary = value;
        isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );

  }

  @override
  void dispose() {
    _summarySub?.cancel();
    super.dispose();
  }
}
