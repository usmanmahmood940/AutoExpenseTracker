import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/provider/safe_change_notifier.dart';

void main() {
  test('notifyListeners after dispose does not throw', () {
    final notifier = SafeChangeNotifier();
    var notified = 0;
    notifier.addListener(() => notified++);

    notifier.notifyListeners();
    expect(notified, 1);

    notifier.dispose();
    expect(notifier.isDisposed, isTrue);
    expect(notifier.notifyListeners, returnsNormally);
    expect(notified, 1);
  });
}
