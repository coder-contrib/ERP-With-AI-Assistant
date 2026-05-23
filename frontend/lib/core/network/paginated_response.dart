class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  PaginatedResponse({required this.items, required this.total, required this.page, required this.pageSize});

  bool get hasMore => (page * pageSize) < total;
  int get totalPages => (total / pageSize).ceil();
}
