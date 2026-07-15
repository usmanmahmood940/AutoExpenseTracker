import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';
import 'package:nova_spend/features/budgets/domain/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetsProvider extends ChangeNotifier {
  BudgetsProvider({
    required BudgetRepository budgetRepository,
    required AnalyticsRepository analyticsRepository,
    required NotificationService notificationService,
    required SharedPreferences prefs,
  })  : _budgetRepository = budgetRepository,
        _analyticsRepository = analyticsRepository,
        _notificationService = notificationService,
        _prefs = prefs;

  final BudgetRepository _budgetRepository;
  final AnalyticsRepository _analyticsRepository;
  final NotificationService _notificationService;
  final SharedPreferences _prefs;

  StreamSubscription<List<BudgetEntity>>? _budgetsSub;
  StreamSubscription<MonthlySummaryEntity?>? _summarySub;

  List<BudgetEntity> budgets = [];
  MonthlySummaryEntity? summary;
  bool isLoading = true;
  String? error;
  String? _uid;

  /// Optional l10n callbacks set by the page before starting.
  String Function(String category, String percent)? alertNearBuilder;
  String Function(String category)? alertOverBuilder;
  String? alertTitle;

  void start(String uid) {
    _uid = uid;
    _budgetsSub?.cancel();
    _summarySub?.cancel();
    isLoading = true;
    notifyListeners();

    final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());

    _budgetsSub = _budgetRepository.watchBudgets(uid).listen((list) {
      budgets = list;
      isLoading = false;
      notifyListeners();
      unawaited(_checkThresholds());
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });

    _summarySub =
        _analyticsRepository.watchSummary(uid, yearMonth).listen((value) {
      summary = value;
      notifyListeners();
      unawaited(_checkThresholds());
    });
  }

  Future<void> saveBudget(BudgetEntity budget) async {
    final uid = _uid;
    if (uid == null) return;
    await _budgetRepository.saveBudget(uid, budget);
  }

  Future<void> deleteBudget(String budgetId) async {
    final uid = _uid;
    if (uid == null) return;
    await _budgetRepository.deleteBudget(uid, budgetId);
  }

  double spentFor(String category) {
    return summary?.byCategory[category] ?? 0;
  }

  Future<void> _checkThresholds() async {
    if (summary == null || budgets.isEmpty) return;
    final yearMonth = summary!.yearMonth;

    for (final budget in budgets) {
      if (budget.limit <= 0) continue;
      final spent = spentFor(budget.category);
      final ratio = spent / budget.limit;
      final key =
          '${AppConstants.prefBudgetAlerted}${budget.category}_$yearMonth';

      if (ratio >= 1.0) {
        final marker = '${key}_over';
        if (_prefs.getBool(marker) == true) continue;
        final title = alertTitle;
        final body = alertOverBuilder?.call(budget.category);
        if (title == null || body == null) continue;
        await _prefs.setBool(marker, true);
        await _notificationService.showBudgetAlert(
          title: title,
          body: body,
          id: budget.category.hashCode,
        );
      } else if (ratio >= 0.8) {
        final marker = '${key}_near';
        if (_prefs.getBool(marker) == true) continue;
        final title = alertTitle;
        final body = alertNearBuilder?.call(
          budget.category,
          (ratio * 100).round().toString(),
        );
        if (title == null || body == null) continue;
        await _prefs.setBool(marker, true);
        await _notificationService.showBudgetAlert(
          title: title,
          body: body,
          id: budget.category.hashCode + 1,
        );
      }
    }
  }

  @override
  void dispose() {
    _budgetsSub?.cancel();
    _summarySub?.cancel();
    super.dispose();
  }
}
