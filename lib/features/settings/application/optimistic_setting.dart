/// Publish immediately, persist in order, and roll back only the latest request.
class OptimisticSetting<T> {
  Future<void> _pending = Future.value();
  T? _confirmed;
  int _revision = 0;

  Future<void> select(
    T value, {
    required T previous,
    required void Function(T) publish,
    required Future<void> Function(T) save,
  }) async {
    if (value == previous) return;
    _confirmed ??= previous;
    final revision = ++_revision;
    publish(value);
    final operation = _pending.then((_) => save(value));
    _pending = operation.then<void>(
      (_) => _confirmed = value,
      onError: (Object _, StackTrace _) {},
    );
    try {
      await operation;
    } on Object {
      if (revision != _revision) return;
      publish(_confirmed as T);
      rethrow;
    }
  }
}
