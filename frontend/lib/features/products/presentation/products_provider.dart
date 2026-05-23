import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/products_repository.dart';

final productsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAll();
});
