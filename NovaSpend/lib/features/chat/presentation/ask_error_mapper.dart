import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

abstract final class AskErrorMapper {
  static String message(AppLocalizations l10n, Object error) {
    final code = error is ServerFailure ? error.code : null;
    switch (code) {
      case 'chat_off_topic':
        return l10n.askErrorOffTopic;
      case 'insufficient_data':
        return l10n.askErrorInsufficientData;
      case 'rate_limited':
        return l10n.askErrorRateLimited;
      case 'gemini_unconfigured':
      case 'gemini_unavailable':
      case 'service_unavailable':
        return l10n.askErrorUnavailable;
      default:
        return AppErrorMapper.message(l10n, error);
    }
  }
}

String? navigationFilterTerm(String answer) {
  final match = RegExp('“([^”]+)”|"([^"]+)"').firstMatch(answer);
  return (match?.group(1) ?? match?.group(2))?.trim();
}
