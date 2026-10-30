/// Pure Dart domain failures for Admin operations (Sprint 2, Role B2).
///
/// Follows Clean Architecture: pure Dart, zero imports of Flutter, Supabase, or Hive.
sealed class AdminFailure implements Exception {
  const AdminFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

/// Thrown when Row-Level Security (RLS) denies access to admin queue or operations.
class AdminPermissionDeniedFailure extends AdminFailure {
  const AdminPermissionDeniedFailure({
    String message =
        'যাচাইকরণ তালিকা দেখার প্রশাসনিক অনুমতি নেই (RLS Access Denied).',
    String? code = '42501',
  }) : super(message, code: code);
}

/// Thrown when network connectivity or socket failure occurs.
class AdminNetworkFailure extends AdminFailure {
  const AdminNetworkFailure({
    String message =
        'সার্ভারের সাথে সংযোগ স্থাপন করা যায়নি। ইন্টারনেট সংযোগ পরীক্ষা করুন।',
    String? code = 'NETWORK_ERROR',
  }) : super(message, code: code);
}

/// Thrown on generic backend, PostgREST, or RPC server failures.
class AdminServerFailure extends AdminFailure {
  const AdminServerFailure({
    required String message,
    String? code = 'SERVER_ERROR',
  }) : super(message, code: code);
}
