import '../../../l10n/app_localizations.dart';

String localizedAuthError(AppLocalizations l10n, String? error) {
  switch (error) {
    case 'Phone number not found':
      return l10n.phoneNotFound;

    case 'Invalid OTP':
      return l10n.invalidOtp;

    case 'Please select a role':
      return l10n.selectRoleError;

    case 'Please confirm your role':
      return l10n.confirmRoleError;

    case 'Unable to complete profile':
      return l10n.profileCompletionError;

    default:
      return l10n.somethingWentWrong;
  }
}
