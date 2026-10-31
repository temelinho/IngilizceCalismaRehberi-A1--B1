import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/models.dart';
import '../core/user_state.dart';
import 'quiz_page.dart';
import 'theme.dart';

/// Hata defteri: yanlış yapılan ve ipucuyla çözülen sorular, konuya göre.
class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});

  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  bool showResolved = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final theme = Theme.of(context);
        final content = appStore.content;
        final all = appStore.state.mistakes.values
            .where((m) => showResolved || !m.resolved)
            .toList()
          ..sort((a, b) => b.last.compareTo(a.last));

        // Konuya göre grupla (ilk konu)
        final byTopic = <String, List<MistakeEntry>>{};
        for (final m in all) {
          final key = m.topics.isEmpty ? '?' : m.topics.first;
          byTopic.putIfAbsent(key, () => []).add(m);
        }
        final keys = byTopic.keys.toList()
          ..sort((a, b) => byTopic[b]!.length.compareTo(byTopic[a]!.length));

        final openQs = appStore.openMistakes
            .map((m) => content.questionById[m.questionId])
            .whereType<Question>()
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hata defteri'),
            actions: [
              IconButton(
                tooltip: showResolved ? 'Çözülenleri gizle' : 'Çözülenleri de göster',
                icon: Icon(showResolved
                    ? Icons.filter_alt_off_outlined
                    : Icons.filter_alt_outlined),
                onPressed: () => setState(() => showResolved = !showResolved),
              ),
            ],
          ),
          body: all.isEmpty
              ? const EmptyState(
                  icon: Icons.verified_rounded,
                  title: 'Hata defterin boş',
                  message:
                      'Yanlış yaptığın ya da ipucuyla çözdüğün sorular burada toplanır.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    AppCard(
                      color: AppColors.coral.withOpacity(0.10),
                      borderColor: AppColors.coral.withOpacity(0.4),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${openQs.length}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                      color: AppColors.coral,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    'açık kayıt\n${keys.length} konuda',
                                    style: theme.textTheme.bodyMedium),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Bir konudan art arda 2 soruyu ipucusuz doğru çözünce kayıt kapanır.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.coral,
                                  foregroundColor: Colors.white),
                              onPressed: openQs.isEmpty
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => QuizPage(
                                            title: 'Hata defteri',
                                            questions: (openQs..shuffle())
                                                .take(20)
                                                .toList(),
                                          ),
                                        ),
                                      ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Hatalarımdan test'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('Konulara göre'),
                    for (final k in keys) _topicGroup(context, k, byTopic[k]!),
                  ],
                ),
        );
      },
    );
  }

  Widget _topicGroup(BuildContext context, String topicId, List<MistakeEntry> list) {
    final topic = appStore.content.topicById[topicId];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.coral.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${list.length}',
              style: const TextStyle(
                  color: AppColors.coral, fontWeight: FontWeight.w800)),
        ),
        title: Text(topic?.title ?? topicId,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('${topic?.level ?? ''} · ${list.length} kayıt'),
        trailing: topic == null
            ? null
            : IconButton(
                tooltip: 'Kuralı göster',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => showTopicNotes(context, topic),
              ),
        children: [
          for (final m in list) _entry(context, m),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bu konudan test'),
                onPressed: () {
                  final qs = appStore.content.questions
                      .where((q) =>
                          q.textId == null &&
                          q.type != QType.write &&
                          q.topics.contains(topicId))
                      .toList()
                    ..shuffle();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuizPage(
                        title: topic?.title ?? 'Konu testi',
                        questions: qs.take(10).toList()),
                  ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, MistakeEntry m) {
    final theme = Theme.of(context);
    final q = appStore.content.questionById[m.questionId];
    if (q == null) return const SizedBox.shrink();
    final tag = m.wrongCount > 0
        ? '${m.wrongCount} kez yanlış'
        : 'ipucuyla çözüldü';
    return ListTile(
      title: Text(q.prompt, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.lastAnswer.isNotEmpty)
            Text('Senin cevabın: ${m.lastAnswer}',
                style: TextStyle(color: theme.colorScheme.error)),
          Text('Doğrusu: ${q.correctText}'),
          Text(m.resolved ? 'Çözüldü' : tag,
              style: theme.textTheme.labelSmall),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'retry') {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => QuizPage(title: 'Tekrar', questions: [q]),
            ));
          } else if (v == 'resolve') {
            appStore.resolveMistake(q.id);
          } else if (v == 'delete') {
            appStore.deleteMistake(q.id);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'retry', child: Text('Tekrar çöz')),
          if (!m.resolved)
            const PopupMenuItem(value: 'resolve', child: Text('Öğrendim, kapat')),
          const PopupMenuItem(value: 'delete', child: Text('Sil')),
        ],
      ),
    );
  }
}
