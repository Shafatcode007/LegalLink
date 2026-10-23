// Barrel export for Admin feature (Role B2)
// Clean Architecture: domain → data → presentation
export 'domain/entities/advocate_verification_item.dart';
export 'domain/repositories/verification_repository.dart';
export 'data/repositories/verification_repository_impl.dart';
export 'presentation/notifiers/admin_verification_notifier.dart';
export 'screens/admin_verification_queue_screen.dart';
export 'screens/advocate_profile_view_screen.dart';
export 'widgets/verification_status_chip.dart';
