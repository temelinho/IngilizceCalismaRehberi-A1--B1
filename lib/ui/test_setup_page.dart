import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/models.dart';
import '../core/session_builder.dart';
import 'quiz_page.dart';
import 'theme.dart';

/// Serbest test: seviye, konu, soru tipi, kaynak ve soru sayısı seçimi.
class TestSetupPage extends StatefulWidget {
  final Set<String>? initialTopics;
  const TestSetupPage({super.key, this.initialTopics});

  @override
  State<TestSetupPage> createState() => _TestSetupPageState();
}

class _TestSetupPageState extends State<TestSetupPage> {
  final levels = <String>{'A1', 'A2'};
  final topics = <String>{};
  final types = <QType>{QType.mcq, QType.tf, QType.short};
  TestSource source = TestSource.all;
  bool includeTexts = false;
  double count = 20;
  final expanded = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialTopics != null && widget.initialTopics!.isNotEmpty) {
      topics.addAll(widget.initialTopics!);
      levels
        ..clear()
        ..addAll(topics
            .map((t) => appStore.content.topicById[t]?.level)
            .whereType<String>());
    }
  }

  TestFilter get _filter => TestFilter(
        levels: levels,
        topics: topics,
        types: types,
        source: source,
        count: count.round(),
        includeTextQuestions: includeTexts,
      );

  int get _available {
    final f = TestFilter(
      levels: levels,
      topics: topics,
      types: types,
      source: source,
      count: 100000,
      includeTextQuestions: includeTexts,
    );
    return appStore.sessions.buildTest(f).length;
  }

  void _start() {
    final qs = appStore.sessions.buildTest(_filter);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizPage(title: 'Test', questions: qs),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = appStore.content;
    final avail = _available;

    // Seçili seviyelerin konuları, gruba göre
    final groups = <String, List<Topic>>{};
    for (final t in content.topics) {
      if (!levels.contains(t.level)) continue;
      final key = '${t.level} · ${t.group}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Test oluştur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _label(context, 'Seviye'),
          Wrap(spacing: 8, children: [
            for (final l in ['A1', 'A2', 'B1'])
              FilterChip(
                label: Text(l),
                selected: levels.contains(l),
                onSelected: (v) => setState(() {
                  if (v) {
                    levels.add(l);
                  } else if (levels.length > 1) {
                    levels.remove(l);
                    topics.removeWhere(
                        (id) => content.topicById[id]?.level == l);
                  }
                }),
              ),
          ]),
          _label(context, 'Konular'),
          Text(
            topics.isEmpty
                ? 'Hiç konu seçmezsen seçili seviyelerin tüm konuları gelir.'
                : '${topics.length} konu seçili',
            style: theme.textTheme.bodySmall,
          ),
          if (topics.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(topics.clear),
                child: const Text('Konu seçimini temizle'),
              ),
            ),
          for (final e in groups.entries)
            AppCard(
              margin: const EdgeInsets.only(top: 8),
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: LevelBadge(e.value.first.level),
                key: PageStorageKey(e.key),
                initiallyExpanded: expanded.contains(e.key),
                onExpansionChanged: (v) =>
                    v ? expanded.add(e.key) : expanded.remove(e.key),
                title: Text(e.key.split(' · ').skip(1).join(' · '),
                    style: Theme.of(context).textTheme.titleSmall),
                subtitle: Text(
                    '${e.value.where((t) => topics.contains(t.id)).length} / ${e.value.length} seçili'),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: () => setState(
                              () => topics.addAll(e.value.map((t) => t.id))),
                          child: const Text('Hepsini seç'),
                        ),
                        TextButton(
                          onPressed: () => setState(() =>
                              topics.removeAll(e.value.map((t) => t.id))),
                          child: const Text('Hiçbiri'),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in e.value)
                        FilterChip(
                          label: Text(t.title,
                              overflow: TextOverflow.ellipsis),
                          selected: topics.contains(t.id),
                          onSelected: (v) => setState(() =>
                              v ? topics.add(t.id) : topics.remove(t.id)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          _label(context, 'Soru tipi'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final ty in QType.values)
              FilterChip(
                label: Text(qTypeLabel(ty)),
                selected: types.contains(ty),
                onSelected: (v) => setState(() {
                  if (v) {
                    types.add(ty);
                  } else if (types.length > 1) {
                    types.remove(ty);
                  }
                }),
              ),
          ]),
          _label(context, 'Kaynak'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(
              label: const Text('Tüm sorular'),
              selected: source == TestSource.all,
              onSelected: (_) => setState(() => source = TestSource.all),
            ),
            ChoiceChip(
              label: const Text('Sadece hata defterim'),
              selected: source == TestSource.mistakes,
              onSelected: (_) => setState(() => source = TestSource.mistakes),
            ),
            ChoiceChip(
              label: const Text('Okuduğum / dinlediğim metinler'),
              selected: source == TestSource.readTexts,
              onSelected: (_) => setState(() => source = TestSource.readTexts),
            ),
          ]),
          if (source == TestSource.all)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Metin sorularını da kat'),
              subtitle: const Text('Hikaye ve diyaloglara bağlı sorular'),
              value: includeTexts,
              onChanged: (v) => setState(() => includeTexts = v),
            ),
          _label(context, 'Soru sayısı: ${count.round()}'),
          Slider(
            min: 5,
            max: 50,
            divisions: 9,
            value: count,
            label: '${count.round()}',
            onChanged: (v) => setState(() => count = v),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Uygun soru: $avail',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: avail == 0 ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                      'Testi başlat (${avail < count.round() ? avail : count.round()} soru)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(s, style: Theme.of(context).textTheme.titleSmall),
      );
}
