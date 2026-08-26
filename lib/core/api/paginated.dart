/// A page of results plus the opaque cursor for the next page (or null).
class Paginated<T> {
  const Paginated({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
