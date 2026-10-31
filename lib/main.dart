import 'package:flutter/material.dart';

import 'app_store.dart';
import 'ui/home_page.dart';
import 'ui/learn_path_page.dart';
import 'ui/saved_page.dart';
import 'ui/test_setup_page.dart';
import 'ui/texts_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appStore.init();
  runApp(const KelimelikApp());
}

class KelimelikApp extends StatefulWidget {
  const KelimelikApp({super.key});

  @override
  State<KelimelikApp> createState() => _KelimelikAppState();
}

class _KelimelikAppState extends State<KelimelikApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana geçerken ilerlemeyi hemen kaydet
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      appStore.saveNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimelik',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  static const _pages = <Widget>[
    LearnPathPage(),
    HomePage(),
    TestSetupPage(),
    TextsPage(),
    SavedPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Öğren'),
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Bugün'),
          NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Test'),
          NavigationDestination(
              icon: Icon(Icons.headphones_outlined),
              selectedIcon: Icon(Icons.headphones),
              label: 'Dinle'),
          NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'Kayıtlar'),
        ],
      ),
    );
  }
}
