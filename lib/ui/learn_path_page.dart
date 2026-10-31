import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/lesson.dart';
import '../core/models.dart';
import 'lesson_page.dart';
import 'theme.dart';

/// Öğren: müfredat sırasıyla konular, her biri etkileşimli ders + unutma
/// eğrisine göre konu tekrarı.
class LearnPathPage extends StatelessWidget {
  const LearnPathPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final theme = Theme.of(context);
        final ordered = appStore.orderedTopicList;
        final total = ordered.length;
        final learned = appStore.learnedCount;
        final due = appStore.topicsDueForReview();
        final next = appStore.nextTopicToLearn();

        // Seviyeye göre grupla (sıra korunur)
        final groups = <String, List<Topic>>{};
        for (final t in ordered) {
          groups.putIfAbsent(t.level, () => []).add(t);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Öğren')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _overall(context, learned, total),
              if (due.isNotEmpty) _reviewCard(context, due),
              if (next != null) _nextCard(context, next),
              for (final e in groups.entries) _levelSection(context, e.key, e.value),
            ],
          ),
        );
      },
    );
  }

  Widget _overall(BuildContext context, int learned, int total) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ProgressRing(
              value: total == 0 ? 0 : learned / total,
              size: 60,
              color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İlerleme', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('$learned / $total konu öğrenildi',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(BuildContext context, List<Topic> due) {
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.amber.withOpacity(0.12),
      borderColor: AppColors.amber.withOpacity(0.5),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.schedule_rounded, color: AppColors.amber),
            const SizedBox(width: 8),
            Text('Tekrar zamanı', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 4),
          Text(
            '${due.length} konunun unutma zamanı geldi. Kısa bir hatırlatma ve birkaç soruyla pekiştir.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: const Color(0xFF3A2606)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TopicReviewPage(topics: due))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Konu tekrarı (${due.length})'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextCard(BuildContext context, Topic next) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.school_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text('Sıradaki ders',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: Colors.white70)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  LevelBadge(next.level, large: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(next.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary),
                    onPressed: () => _openLesson(context, next),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Derse başla'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelSection(BuildContext context, String level, List<Topic> topics) {
    final theme = Theme.of(context);
    final learned = topics.where((t) => appStore.isLearned(t.id)).length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: level == 'A1',
          leading: LevelBadge(level, large: true),
          title: Text('$level seviyesi', style: theme.textTheme.titleSmall),
          subtitle: Text('$learned / ${topics.length} öğrenildi',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (var i = 0; i < topics.length; i++)
              _topicRow(context, topics[i], i + 1),
          ],
        ),
      ),
    );
  }

  Widget _topicRow(BuildContext context, Topic t, int order) {
    final theme = Theme.of(context);
    final learned = appStore.isLearned(t.id);
    final prog = appStore.topicProgress(t.id);
    final due = learned && (prog?.card.isDue ?? false);

    Widget leading;
    if (learned) {
      leading = Icon(
          due ? Icons.history_rounded : Icons.check_circle_rounded,
          color: due ? AppColors.amber : AppColors.success);
    } else {
      leading = Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text('$order',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      );
    }

    return InkWell(
      onTap: () => _openLesson(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          learned ? FontWeight.w400 : FontWeight.w600)),
            ),
            if (due)
              const Pill('tekrar', color: AppColors.amber, icon: Icons.schedule_rounded)
            else if (!learned)
              Text('başla',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  void _openLesson(BuildContext context, Topic t) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LessonPage(topicId: t.id)));
  }
}
