// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'আইন সহায়';

  @override
  String get phoneTitle => 'আপনার মোবাইল নম্বর দিন';

  @override
  String get phoneSubtitle =>
      'এই নম্বরে আমরা ৬ সংখ্যার একটি যাচাইকরণ কোড পাঠাব।';

  @override
  String get phoneLabel => 'মোবাইল নম্বর';

  @override
  String get phoneHint => '১XXXXXXXXX';

  @override
  String get sendOtp => 'ওটিপি পাঠান';

  @override
  String get invalidPhone => 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন';

  @override
  String get phonePrivacy =>
      'আপনার নম্বর শুধুমাত্র অ্যাকাউন্ট যাচাইয়ের জন্য ব্যবহার করা হবে।';

  @override
  String get somethingWentWrong => 'কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get otpTitle => 'মোবাইল নম্বর যাচাই করুন';

  @override
  String get otpSubtitle => 'এই নম্বরে পাঠানো ৬ সংখ্যার যাচাইকরণ কোডটি লিখুন';

  @override
  String get otpLabel => 'যাচাইকরণ কোড';

  @override
  String get otpHint => '৬ সংখ্যার ওটিপি';

  @override
  String get verifyOtp => 'ওটিপি যাচাই করুন';

  @override
  String get invalidOtp => 'যাচাইকরণ কোডটি সঠিক নয়';

  @override
  String get otpLengthError => 'সম্পূর্ণ ৬ সংখ্যার কোড লিখুন';

  @override
  String get otpHelp => 'ডেভেলপমেন্টের জন্য মক যাচাইকরণ কোড ব্যবহার করুন।';

  @override
  String get roleTitle => 'আপনি কীভাবে আইন সহায় ব্যবহার করবেন?';

  @override
  String get roleSubtitle => 'আপনার জন্য উপযুক্ত ভূমিকাটি নির্বাচন করুন।';

  @override
  String get clientRole => 'ক্লায়েন্ট';

  @override
  String get clientRoleDescription =>
      'আমি আইনি সহায়তা, মামলার আপডেট, কাগজপত্র বা আইনজীবী খুঁজছি।';

  @override
  String get advocateRole => 'আইনজীবী';

  @override
  String get advocateRoleDescription =>
      'আমি একজন আইনজীবী এবং ক্লায়েন্ট ও মামলা পরিচালনা করতে চাই।';

  @override
  String get continueText => 'এগিয়ে যান';

  @override
  String get selectRoleError => 'এগিয়ে যেতে একটি ভূমিকা নির্বাচন করুন';

  @override
  String get profileTitle => 'আপনার প্রোফাইল সম্পূর্ণ করুন';

  @override
  String get profileSubtitle => 'এগিয়ে যেতে কিছু মৌলিক তথ্য দিন।';

  @override
  String get fullName => 'পূর্ণ নাম';

  @override
  String get fullNameHint => 'আপনার পূর্ণ নাম লিখুন';

  @override
  String get nameRequired => 'আপনার পূর্ণ নাম লিখুন';

  @override
  String get verifiedPhone => 'যাচাইকৃত মোবাইল নম্বর';

  @override
  String get verifiedPhoneHint => 'ওটিপির মাধ্যমে যাচাই করা হয়েছে';

  @override
  String get language => 'পছন্দের ভাষা';

  @override
  String get bangla => 'বাংলা';

  @override
  String get english => 'ইংরেজি';

  @override
  String get saveContinue => 'সংরক্ষণ করে এগিয়ে যান';

  @override
  String get profilePrivacy =>
      'যাচাইকৃত মোবাইল নম্বর এখান থেকে পরিবর্তন করা যাবে না।';

  @override
  String get welcome => 'আইন সহায়ে স্বাগতম';

  @override
  String get profileComplete => 'আপনার অ্যাকাউন্ট সেটআপ সম্পূর্ণ হয়েছে।';

  @override
  String get role => 'ভূমিকা';

  @override
  String get phone => 'মোবাইল';

  @override
  String get signOut => 'লগআউট';
}
