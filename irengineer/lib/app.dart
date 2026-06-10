import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/settings_provider.dart';
import 'features/practice/practice_page.dart';
import 'features/review/review_page.dart';
import 'features/settings/settings_page.dart';
import 'services/coach_provider.dart';

class IracingCoachApp extends ConsumerStatefulWidget {
  const IracingCoachApp({super.key});

  @override
  ConsumerState<IracingCoachApp> createState() => _IracingCoachAppState();
}

class _IracingCoachAppState extends ConsumerState<IracingCoachApp> {
  int _index = 0;

  static const _pages = [
    ReviewPage(),
    PracticePage(),
    SettingsPage(),
  ];

  Future<void> _onModeChanged(int i) async {
    final coach = ref.read(coachLoopProvider.notifier);
    if (i == 0) {
      // KTD-9: Review mode pauses SDK polling and cancels TTS.
      await coach.pausePractice();
    } else if (i == 1) {
      final gate = ref.read(readyGateProvider);
      if (gate.ready) {
        await coach.startPractice();
      }
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    return MaterialApp(
      title: 'iREngineer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onModeChanged,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: '复盘',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_motorsports_outlined),
              selectedIcon: Icon(Icons.sports_motorsports),
              label: '练车',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
