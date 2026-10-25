import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/core/env/app_config.dart';
import 'package:legal_link/features/sos/data/channel_registry.dart';
import 'package:legal_link/features/sos/data/noop_sos_realtime_repository.dart';
import 'package:legal_link/features/sos/data/sos_alert_mapper.dart';
import 'package:legal_link/features/sos/domain/entities/sos_alert.dart';
import 'package:legal_link/features/sos/domain/sos_channels.dart';
import 'package:legal_link/features/sos/presentation/providers/sos_realtime_provider.dart';

void main() {
  group('sos channel naming (TRD §6.5, §8.3)', () {
    test('topic is sos:{district}', () {
      expect(sosChannelTopic('Dhaka'), 'sos:Dhaka');
    });

    test('districts are trimmed, de-duplicated and empty ones dropped', () {
      expect(sosDistricts([' Dhaka', 'Dhaka', '', '  ', 'Sylhet ']), {
        'Dhaka',
        'Sylhet',
      });
    });
  });

  group('ChannelRegistry — exactly one channel per key', () {
    late List<String> opened;
    late List<String> closed;
    late ChannelRegistry<String> registry;

    setUp(() {
      opened = [];
      closed = [];
      registry = ChannelRegistry<String>(
        open: (key) {
          opened.add(key);
          return key;
        },
        close: closed.add,
      );
    });

    test('syncing the same keys twice opens each channel once', () {
      registry.sync({'sos:Dhaka'});
      registry.sync({'sos:Dhaka'});

      expect(opened, ['sos:Dhaka']);
      expect(registry.keys, {'sos:Dhaka'});
    });

    test('adding a district opens only the new channel', () {
      registry.sync({'sos:Dhaka'});
      registry.sync({'sos:Dhaka', 'sos:Sylhet'});

      expect(opened, ['sos:Dhaka', 'sos:Sylhet']);
      expect(closed, isEmpty);
    });

    test('removing a district closes only that channel', () {
      registry.sync({'sos:Dhaka', 'sos:Sylhet'});
      registry.sync({'sos:Sylhet'});

      expect(closed, ['sos:Dhaka']);
      expect(registry.keys, {'sos:Sylhet'});
    });

    test('closeAll closes every open channel', () {
      registry.sync({'sos:Dhaka', 'sos:Sylhet'});
      registry.closeAll();

      expect(closed..sort(), ['sos:Dhaka', 'sos:Sylhet']);
      expect(registry.keys, isEmpty);
    });
  });

  group('sosAlertFromRecord (sos_requests row)', () {
    test('maps an inserted row', () {
      final alert = sosAlertFromRecord({
        'id': '55555555-5555-5555-5555-555555555501',
        'district': 'Dhaka',
        'thana': 'Ramna',
        'court': 'Dhaka CMM Court 1',
        'status': 'open',
        'urgency': 'high',
        'created_at': '2026-10-25T09:15:00Z',
      });

      expect(alert.id, '55555555-5555-5555-5555-555555555501');
      expect(alert.district, 'Dhaka');
      expect(alert.status, 'open');
      expect(alert.court, 'Dhaka CMM Court 1');
      expect(alert.createdAt, DateTime.utc(2026, 10, 25, 9, 15));
    });

    test('tolerates missing optional fields', () {
      final alert = sosAlertFromRecord({
        'id': 'x',
        'district': 'Sylhet',
        'thana': 'Kotwali',
        'status': 'open',
      });

      expect(alert.court, isNull);
      expect(alert.createdAt, isNull);
    });

    test('rejects a row without id or district', () {
      expect(
        () => sosAlertFromRecord({'district': 'Dhaka'}),
        throwsFormatException,
      );
      expect(() => sosAlertFromRecord({'id': 'x'}), throwsFormatException);
    });
  });

  test('without Supabase config, di.dart binds the no-op realtime stub', () {
    final container = ProviderContainer(
      overrides: appOverridesFor(const AppConfig()),
    );
    addTearDown(container.dispose);

    final repo = container.read(sosRealtimeRepositoryProvider);
    expect(repo, isA<NoopSosRealtimeRepository>());
    expect(repo.watchDistricts(['Dhaka']), emitsDone);
  });

  test('SosChange carries the event type', () {
    const alert = SosAlert(
      id: 'x',
      district: 'Dhaka',
      thana: 'Ramna',
      status: 'accepted',
    );
    const change = SosChange(SosChangeType.updated, alert);

    expect(change.type, SosChangeType.updated);
    expect(change.alert.status, 'accepted');
  });
}
