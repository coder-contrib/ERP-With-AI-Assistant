import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/suppliers_repository.dart';

final suppliersProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final repo = ref.read(suppliersRepositoryProvider);
  return repo.getAll();
});
