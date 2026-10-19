
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/local_vault.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/survey/survey_screen.dart';
import '../features/interview/interview_screen.dart';
import '../features/privacy/privacy_screen.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.vault, required this.onLogout, required this.onActivity});
  final ApiClient api;
  final LocalVault vault;
  final Future<void> Function() onLogout;
  final VoidCallback onActivity;
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final ValueNotifier<int> _newChatSignal = ValueNotifier<int>(0);
  final labels = const ['相談', 'プロフィール', '診断', '模擬面接', 'プライバシー'];
  final icons = const [
    Icons.chat_bubble_outline, Icons.person_outline, Icons.explore_outlined,
    Icons.record_voice_over_outlined, Icons.shield_outlined
  ];

  Widget _page() {
    switch (index) {
      case 1: return ProfileScreen(api: widget.api, vault: widget.vault, onActivity: widget.onActivity);
      case 2: return SurveyScreen(api: widget.api, vault: widget.vault);
      case 3: return InterviewScreen(api: widget.api, onActivity: widget.onActivity);
      case 4: return PrivacyScreen(api: widget.api, vault: widget.vault, onLogout: widget.onLogout, onActivity: widget.onActivity);
      default: return ChatScreen(api: widget.api, vault: widget.vault, onActivity: widget.onActivity, newChatSignal: _newChatSignal);
    }
  }

  void _newChat() {
    widget.onActivity();
    if (index != 0) {
      setState(() => index = 0);
    }
    _newChatSignal.value++;
  }

  @override
  void dispose() {
    _newChatSignal.dispose();
    super.dispose();
  }

  void _select(int i) {
    widget.onActivity();
    setState(() => index = i);
  }

  Widget _sidebar({bool compact = false}) => Container(
    width: compact ? 78 : 250,
    color: MichishirubeTheme.panel,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 18, compact ? 10 : 16, 12),
            child: compact
              ? const Icon(Icons.route_outlined, color: MichishirubeTheme.accent, size: 30)
              : Row(children: const [
                  Icon(Icons.route_outlined, color: MichishirubeTheme.accent, size: 27),
                  SizedBox(width: 10),
                  Text('ミチシルベ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: MichishirubeTheme.ink)),
                ]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _newChat,
                icon: const Icon(Icons.add, size: 19),
                label: compact ? const SizedBox.shrink() : const Text('新しい相談'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MichishirubeTheme.ink,
                  side: const BorderSide(color: Color(0xFFD2C6B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!compact) const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('メニュー', style: TextStyle(fontSize: 12, color: MichishirubeTheme.muted, fontWeight: FontWeight.w700))),
          ),
          ...List.generate(labels.length, (i) => Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 2),
            child: ListTile(
              dense: true,
              selected: index == i,
              selectedTileColor: const Color(0xFFDCCABD),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              leading: Icon(icons[i], size: 21, color: index == i ? MichishirubeTheme.accentDark : MichishirubeTheme.muted),
              title: compact ? null : Text(labels[i], style: TextStyle(fontWeight: index == i ? FontWeight.w700 : FontWeight.w500)),
              onTap: () => _select(i),
              contentPadding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
            ),
          )),
          const Spacer(),
          if (!compact) Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Text('落ち着いて考えるための\nキャリア相談室', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: MichishirubeTheme.muted, height: 1.5)),
          ),
        ],
      ),
    ),
  );

  @override Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      if (wide) {
        return Scaffold(
          body: Row(children: [
            _sidebar(),
            Expanded(child: _page()),
          ]),
        );
      }
      return Scaffold(
        appBar: AppBar(
          leading: Builder(builder: (c) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(c).openDrawer(),
          )),
          title: Row(children: [
            const Icon(Icons.route_outlined, size: 23, color: MichishirubeTheme.accent),
            const SizedBox(width: 8),
            Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          actions: [
            if (index == 0) IconButton(
              tooltip: '新しい相談',
              onPressed: _newChat,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        drawer: Drawer(child: _sidebar()),
        body: _page(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          destinations: List.generate(labels.length, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
        ),
      );
    });
  }
}
