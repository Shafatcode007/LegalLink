/// Keeps exactly one open channel per key (TRD §8.3): re-syncing the same
/// keys is a no-op, and only added or removed keys open or close channels.
class ChannelRegistry<T> {
  ChannelRegistry({required this.open, required this.close});

  final T Function(String key) open;
  final void Function(T channel) close;
  final Map<String, T> _channels = {};

  Set<String> get keys => _channels.keys.toSet();

  void sync(Set<String> wanted) {
    for (final key in keys.difference(wanted)) {
      close(_channels.remove(key) as T);
    }
    for (final key in wanted.difference(keys)) {
      _channels[key] = open(key);
    }
  }

  void closeAll() => sync(const {});
}
