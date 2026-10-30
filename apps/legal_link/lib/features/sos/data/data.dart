// Data layer barrel export for SOS feature (Role B2)
// NOTE: Only lib/app/di.dart may import this layer (TRD §8.1).
export 'models/sos_request_dto.dart';
export 'repositories/mock_sos_repository.dart';
export 'repositories/noop_sos_realtime_repository.dart';
export 'repositories/supabase_sos_realtime_repository.dart';
export 'repositories/supabase_sos_repository.dart';
export 'sources/supabase_sos_data_source.dart';
