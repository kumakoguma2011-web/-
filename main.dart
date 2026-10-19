import 'package:flutter/material.dart';
import 'core/app.dart';
import 'services/api_client.dart';
import 'services/auth_store.dart';
import 'services/local_vault.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CareerAiApp(
    api: ApiClient(const String.fromEnvironment('CAREER_AI_API_BASE_URL', defaultValue: '')),
    authStore: AuthStore(),
    vault: LocalVault(),
  ));
}
