import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';

void main() {
  group('percentChange', () {
    test('returns null when previous is zero', () {
      expect(percentChange(100, 0), isNull);
    });

    test('computes increase and decrease', () {
      expect(percentChange(112, 100), closeTo(12, 0.001));
      expect(percentChange(80, 100), closeTo(-20, 0.001));
    });
  });

  group('shareOfTotal', () {
    test('is fraction of total spent', () {
      expect(shareOfTotal(35, 100), 0.35);
      expect(shareOfTotal(50, 0), 0);
    });
  });

  group('topEntries', () {
    test('sorts descending and respects limit', () {
      final top = topEntries(
        {'a': 10, 'b': 40, 'c': 25, 'd': 1},
        limit: 2,
      );
      expect(top.map((e) => e.key).toList(), ['b', 'c']);
    });
  });

  group('merchantInitials', () {
    test('uses first letters of two words', () {
      expect(merchantInitials('W. Ahmed'), 'WA');
      expect(merchantInitials('Jazz Prepaid'), 'JP');
    });

    test('uses two characters of a single token', () {
      expect(merchantInitials('PSO'), 'PS');
      expect(merchantInitials('X'), 'X');
      expect(merchantInitials('  '), '?');
    });
  });

  group('narrativeFacts', () {
    test('is empty when the period has no spend', () {
      final facts = narrativeFacts(
        spent: 0,
        transactionCount: 0,
        byCategory: const {},
        byMerchant: const {},
        previousSpent: 100,
      );
      expect(facts.hasContent, isFalse);
    });

    test('includes spend change, top category share, and top merchant', () {
      final facts = narrativeFacts(
        spent: 100,
        transactionCount: 4,
        byCategory: const {'Food & Dining': 40, 'Fuel': 10},
        byMerchant: const {'KFC': 25, 'Shell': 10},
        previousSpent: 80,
      );
      expect(facts.spendChangePercent, closeTo(25, 0.001));
      expect(facts.topCategory, 'Food & Dining');
      expect(facts.topCategoryShare, closeTo(0.4, 0.001));
      expect(facts.topMerchant, 'KFC');
      expect(facts.topMerchantAmount, 25);
    });
  });

  group('insightsRange', () {
    final now = DateTime(2026, 8, 27);

    test('this month is the calendar month', () {
      final range = insightsRange(
        preset: InsightsPeriodPreset.thisMonth,
        now: now,
      );
      expect(range.from, DateTime(2026, 8, 1));
      expect(range.to, DateTime(2026, 8, 31));
    });

    test('this year is YTD', () {
      final range = insightsRange(
        preset: InsightsPeriodPreset.thisYear,
        now: now,
      );
      expect(range.from, DateTime(2026, 1, 1));
      expect(range.to, DateTime(2026, 8, 27));
    });

    test('previous this-year range is last YTD', () {
      final previous = previousInsightsRange(
        preset: InsightsPeriodPreset.thisYear,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 8, 27),
      );
      expect(previous.from, DateTime(2025, 1, 1));
      expect(previous.to, DateTime(2025, 8, 27));
    });
  });

  group('yearMonthsInRange', () {
    test('lists months inclusive', () {
      expect(
        yearMonthsInRange(DateTime(2025, 1, 1), DateTime(2025, 8, 27)),
        [
          '2025-01',
          '2025-02',
          '2025-03',
          '2025-04',
          '2025-05',
          '2025-06',
          '2025-07',
          '2025-08',
        ],
      );
    });
  });

  group('mergeMonthlySummaries', () {
    test('sums totals and breakdowns', () {
      const jan = MonthlySummaryEntity(
        yearMonth: '2025-01',
        currency: 'PKR',
        totalDebit: 100,
        totalCredit: 20,
        net: -80,
        transactionCount: 2,
        byCategory: {'Food': 100},
        byMerchant: {'KFC': 100},
      );
      const feb = MonthlySummaryEntity(
        yearMonth: '2025-02',
        currency: 'PKR',
        totalDebit: 50,
        totalCredit: 0,
        net: -50,
        transactionCount: 1,
        byCategory: {'Food': 30, 'Fuel': 20},
        byMerchant: {'KFC': 30, 'PSO': 20},
      );
      final merged = mergeMonthlySummaries(
        [jan, feb],
        from: DateTime(2025, 1, 1),
        to: DateTime(2025, 2, 28),
      );
      expect(merged.totalDebit, 150);
      expect(merged.totalCredit, 20);
      expect(merged.net, -130);
      expect(merged.transactionCount, 3);
      expect(merged.byCategory['Food'], 130);
      expect(merged.byMerchant['KFC'], 130);
      expect(merged.dateFrom, '2025-01-01');
      expect(merged.dateTo, '2025-02-28');
    });
  });
}
