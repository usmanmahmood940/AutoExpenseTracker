import 'package:flutter/widgets.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';

import 'app_localizations.dart';

extension AppStringsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

String paymentMethodLabel(AppLocalizations l10n, String key) {
  switch (normalizePaymentMethod(key)) {
    case 'debit_card':
      return l10n.paymentMethodDebitCard;
    case 'credit_card':
      return l10n.paymentMethodCreditCard;
    case 'bank_transfer':
      return l10n.paymentMethodBankTransfer;
    case 'wallet':
      return l10n.paymentMethodWallet;
    case 'cash':
      return l10n.paymentMethodCash;
    case 'cheque':
      return l10n.paymentMethodCheque;
    case 'atm_withdrawal':
      return l10n.paymentMethodAtmWithdrawal;
    case 'qr':
      return l10n.paymentMethodQr;
    case 'other':
      return l10n.paymentMethodOther;
    case 'unknown':
    default:
      return l10n.paymentMethodUnknown;
  }
}

