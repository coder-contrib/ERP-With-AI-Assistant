import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/whatsapp_repository.dart';

final whatsappSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(whatsappRepositoryProvider);
  return repo.getSettings();
});

final whatsappSendingProvider = StateProvider<bool>((ref) => false);
