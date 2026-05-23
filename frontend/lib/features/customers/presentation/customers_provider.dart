import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customers_repository.dart';

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final repo = ref.read(customersRepositoryProvider);
  return repo.getAll();
});
