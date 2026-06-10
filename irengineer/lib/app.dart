import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/agent_fixture.dart';
import 'core/platform/desktop_capabilities.dart';
import 'core/settings/settings_provider.dart';
import 'features/practice/linux_practice_stub_page.dart';
import 'features/practice/practice_page.dart';
import 'features/review/analysis_controller.dart';
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
  bool _fixtureBootstrapDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapAgentFixtures());
  }

  Future<void> _bootstrapAgentFixtures() async {
    if (_fixtureBootstrapDone) {
      return;
    }
    _fixtureBootstrapDone = true;
    final paths = parseFixturePathsFromEnv();
    if (paths.isEmpty) {
      return;
    }
    final review = ref.read(reviewControllerProvider.notifier);
    await review.importFiles(paths);
    if (autoAnalyzeFromEnv()) {
      await review.runAnalysis();
    }
  }

  List<Widget> get _pages => [
        const ReviewPage(),
        supportsLiveCoaching
            ? const PracticePage()
            : const LinuxPracticeStubPage(),
        const SettingsPage(),
      ];

  Future<void> _onModeChanged(int i) async {
    final coach = ref.read(coachLoopProvider.notifier);
    if (i == 0) {
      // KTD-9: Review mode pauses SDK polling and cancels TTS.
      await coach.pausePractice();
    } else if (i == 1 && supportsLiveCoaching) {
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
