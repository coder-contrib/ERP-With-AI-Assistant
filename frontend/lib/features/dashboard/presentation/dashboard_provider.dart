import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getSummary();
});
