import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/features/sos/data/channel_registry.dart';
import 'package:legal_link/features/sos/data/repositories/noop_sos_realtime_repository.dart';
import 'package:legal_link/features/sos/domain/domain.dart';

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

  test('a change carries the shared SosRequestItem model', () {
    const request = SosRequestItem(
      id: 'x',
      clientId: 'c',
      personName: 'p',
      thana: 'Ramna',
      district: 'Dhaka',
      contactPhone: '+8801700000001',
      status: SosStatus.accepted,
    );
    const change = SosChange(SosChangeType.updated, request);

    expect(change.type, SosChangeType.updated);
    expect(change.request.status.isAccepted, isTrue);
  });

  test('without Supabase config, di.dart binds the no-op realtime feed', () {
    final container = ProviderContainer(overrides: createDiOverrides());
    addTearDown(container.dispose);

    final repo = container.read(sosRealtimeRepositoryProvider);
    expect(repo, isA<NoopSosRealtimeRepository>());
    expect(repo.watchDistricts(['Dhaka']), emitsDone);
  });
}
