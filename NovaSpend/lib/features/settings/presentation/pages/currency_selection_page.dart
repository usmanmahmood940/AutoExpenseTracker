import 'package:flutter/material.dart';

import '../../../../core/constants/currencies.dart';
import '../../../../l10n/app_strings.dart';

/// Currency picker; returns selected ISO code via [Navigator.pop].
class CurrencySelectionPage extends StatelessWidget {
  const CurrencySelectionPage({required this.selected, super.key});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final current = normalizeCurrency(selected);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsCurrency),
      ),
      body: ListView(
        children: [
          for (final code in kCurrencies)
            ListTile(
              title: Text(currencyDisplayLabel(code)),
              trailing: code == current
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(code),
            ),
        ],
      ),
    );
  }
}
