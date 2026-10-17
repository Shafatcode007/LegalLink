// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Ain Sohay';

  @override
  String get phoneTitle => 'Enter your phone number';

  @override
  String get phoneSubtitle =>
      'We will send a 6-digit verification code to this number.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHint => '1XXXXXXXXX';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get invalidPhone => 'Enter a valid Bangladeshi mobile number';

  @override
  String get phonePrivacy =>
      'Your number is used only for account verification.';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get otpTitle => 'Verify your phone';

  @override
  String get otpSubtitle => 'Enter the 6-digit verification code sent to';

  @override
  String get otpLabel => 'Verification code';

  @override
  String get otpHint => '6-digit OTP';

  @override
  String get verifyOtp => 'Verify OTP';

  @override
  String get invalidOtp => 'The verification code is incorrect';

  @override
  String get otpLengthError => 'Enter the complete 6-digit code';

  @override
  String get otpHelp => 'For development, use the mock verification code.';

  @override
  String get roleTitle => 'Choose how you will use Ain Sohay';

  @override
  String get roleSubtitle => 'Select the option that best describes you.';

  @override
  String get clientRole => 'Client';

  @override
  String get clientRoleDescription =>
      'I need legal help, case updates, documents, or an advocate.';

  @override
  String get advocateRole => 'Advocate';

  @override
  String get advocateRoleDescription =>
      'I am a legal professional and want to manage clients and cases.';

  @override
  String get continueText => 'Continue';

  @override
  String get selectRoleError => 'Please select a role to continue';

  @override
  String get profileTitle => 'Complete your profile';

  @override
  String get profileSubtitle => 'Add a few basic details to continue.';

  @override
  String get fullName => 'Full name';

  @override
  String get fullNameHint => 'Enter your full name';

  @override
  String get nameRequired => 'Please enter your full name';

  @override
  String get verifiedPhone => 'Verified phone number';

  @override
  String get verifiedPhoneHint => 'Verified through OTP';

  @override
  String get language => 'Preferred language';

  @override
  String get bangla => 'Bangla';

  @override
  String get english => 'English';

  @override
  String get saveContinue => 'Save and continue';

  @override
  String get profilePrivacy =>
      'Your verified phone number cannot be changed here.';

  @override
  String get welcome => 'Welcome to Ain Sohay';

  @override
  String get profileComplete => 'Your account setup is complete.';

  @override
  String get role => 'Role';

  @override
  String get phone => 'Phone';

  @override
  String get signOut => 'Sign out';
}
