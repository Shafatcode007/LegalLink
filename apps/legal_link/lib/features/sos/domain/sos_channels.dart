/// Realtime channel naming is fixed by TRD §6.5 (push&commit_rules §1.3).
String sosChannelTopic(String district) => 'sos:$district';

/// Stable, de-duplicated district set (TRD §8.3): equal inputs map to the
/// same channels. Values stay case-sensitive because they must match
/// `sos_requests.district` exactly.
Set<String> sosDistricts(Iterable<String> districts) => {
  for (final d in districts)
    if (d.trim().isNotEmpty) d.trim(),
};
