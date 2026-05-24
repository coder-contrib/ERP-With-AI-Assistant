import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/opening_balance_repository.dart';

final openingBalancesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(openingBalanceRepositoryProvider);
  return repo.getOpeningBalances();
});

final openingBalancesTabProvider = StateProvider<int>((ref) => 0);
