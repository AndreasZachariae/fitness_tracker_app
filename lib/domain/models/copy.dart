/// Sentinel for `copyWith` parameters of nullable fields: distinguishes
/// "not passed" from an explicit `null`.
const Object unset = _Unset();

final class _Unset {
  const _Unset();
}

/// Returns [current] if [value] is [unset], otherwise [value] as [T].
T pick<T>(Object? value, T current) =>
    identical(value, unset) ? current : value as T;
