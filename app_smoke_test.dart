import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/core/app.dart';
import '../lib/services/api_client.dart';
import '../lib/services/auth_store.dart';
import '../lib/services/local_vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final baseUrl = const String.fromEnvironment('CAREER_AI_API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

  testWidgets('ミチシルベ end-to-end smoke flow', (tester) async {
    await tester.pumpWidget(CareerAiApp(api: ApiClient(baseUrl), authStore: AuthStore(), vault: LocalVault()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('ミチシルベ'), findsOneWidget);

    final suffix = Random().nextInt(1 << 30);
    final email = 'mobile-test-$suffix@example.invalid';
    const password = 'TestPassword123!';

    await tester.tap(find.text('新規アカウントを作成'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.text('アカウント作成'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('相談'), findsOneWidget);
    expect(find.text('プロフィール'), findsOneWidget);

    await tester.tap(find.text('プロフィール'));
    await tester.pumpAndSettle();
    expect(find.text('個人プロフィール・カルテ'), findsOneWidget);
    final profileFields = find.byType(TextField);
    await tester.enterText(profileFields.at(0), '地方都市');
    await tester.enterText(profileFields.at(1), '慎重・分析好き');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    await tester.tap(find.text('プライバシー'));
    await tester.pumpAndSettle();
    expect(find.text('ZERO-CONTEXT'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final privacyFields = find.byType(TextField);
    await tester.enterText(privacyFields.at(0), '株式会社山田商事');
    await tester.enterText(privacyFields.at(1), '[現職のA社]');
    await tester.tap(find.text('仮名化ルールを追加'));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    expect(find.text('株式会社山田商事'), findsOneWidget);

    await tester.tap(find.text('相談'));
    await tester.pumpAndSettle();
    expect(find.text('ZERO-CONTEXT'), findsOneWidget);
    expect(find.text('ステップ1'), findsOneWidget);
    expect(find.text('ステップ2'), findsOneWidget);
    expect(find.text('優しく励ます'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '今の仕事にモヤモヤしています。');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 8));
    expect(find.textContaining('モヤモヤ'), findsWidgets);
  });
}
