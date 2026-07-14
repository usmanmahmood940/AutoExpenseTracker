import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';

/// Stub language picker; returns selected language code via [Navigator.pop].
class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  static const supportedLanguages = [
    _LanguageOption(code: 'en', labelKey: 'settingsLanguageEnglish'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsLanguage),
      ),
      body: ListView(
        children: [
          for (final language in supportedLanguages)
            ListTile(
              title: Text(_labelFor(context, language.labelKey)),
              onTap: () => Navigator.of(context).pop(language.code),
            ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, String labelKey) {
    switch (labelKey) {
      case 'settingsLanguageEnglish':
        return context.l10n.settingsLanguageEnglish;
      default:
        return labelKey;
    }
  }
}

class _LanguageOption {
  const _LanguageOption({required this.code, required this.labelKey});

  final String code;
  final String labelKey;
}
