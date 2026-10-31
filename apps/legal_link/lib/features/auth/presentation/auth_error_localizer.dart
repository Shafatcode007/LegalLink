import '../../../l10n/app_localizations.dart';

String localizedAuthError(AppLocalizations l10n, String? error) {
  switch (error) {
    case 'Session restore failed':
      return l10n.sessionRestoreError;
    case 'Unsupported account':
      return l10n.unsupportedAccount;
    case 'Phone number not found':
      return l10n.phoneNotFound;

    case 'Invalid OTP':
    case 'Exception: Invalid OTP':
      return l10n.invalidOtp;

    case 'Please select a role':
      return l10n.selectRoleError;

    case 'Please confirm your role':
      return l10n.confirmRoleError;

    case 'Unable to complete profile':
      return l10n.profileCompletionError;

    case 'Failed to send OTP':
    case 'SMS provider not configured':
    case 'Failed to send verification code':
      return l10n.smsSendFailed;

    default:
      return l10n.somethingWentWrong;
  }
}
