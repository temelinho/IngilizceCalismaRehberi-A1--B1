import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/lesson.dart';
import '../core/models.dart';
import 'theme.dart';
import 'widgets/inline_question.dart';
import 'widgets/md_view.dart';

/// Tek bir konunun etkileşimli dersi: adım adım anlatım + aralara pratik soru.
class LessonPage extends StatefulWidget {
  final String topicId;
  const LessonPage({super.key, required this.topicId});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late Lesson lesson;
  int index = 0;
  bool answeredCurrent = false;
  int correct = 0;
  int practiceTotal = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    lesson = appStore.buildLessonFor(widget.topicId);
    practiceTotal = lesson.questionCount;
  }

  LessonStep get step => lesson.steps[index];
  double get score => practiceTotal == 0 ? 1.0 : correct / practiceTotal;

  void _next() {
    if (index + 1 >= lesson.steps.length) return;
    setState(() {
      index++;
      answeredCurrent = false;
    });
  }

  void _onAnswered(bool ok, int hints) {
    if (ok && hints == 0) correct++;
    setState(() => answeredCurrent = true);
  }

  void _finish() {
    appStore.completeLesson(widget.topicId, score: score);
    setState(() => finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = lesson.topic;
    final progress = (index + 1) / lesson.steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: step.kind == StepKind.done
            ? _doneView(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(children: [
                    LevelBadge(topic.level),
                    const SizedBox(width: 8),
                    Text('Adım ${index + 1} / ${lesson.steps.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                  const SizedBox(height: 14),
                  _stepBody(context),
                ],
              ),
      ),
      bottomNavigationBar: step.kind == StepKind.done
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: (step.kind == StepKind.explain || answeredCurrent)
                      ? _next
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(step.kind == StepKind.explain
                      ? 'Devam'
                      : (answeredCurrent ? 'Devam' : 'Önce cevapla')),
                ),
              ),
            ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final theme = Theme.of(context);
    switch (step.kind) {
      case StepKind.explain:
        return AppCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.menu_book_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Anlatım', style: theme.textTheme.labelLarge),
              ]),
              const SizedBox(height: 10),
              MdView(step.markdown),
            ],
          ),
        );
      case StepKind.question:
      case StepKind.review:
        return AppCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          borderColor: step.kind == StepKind.review
              ? AppColors.amber.withOpacity(0.5)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                    step.kind == StepKind.review
                        ? Icons.history_rounded
                        : Icons.edit_rounded,
                    size: 18,
                    color: step.kind == StepKind.review
                        ? AppColors.amber
                        : theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                    step.kind == StepKind.review
                        ? 'Önceki konudan tekrar'
                        : 'Pratik',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: step.kind == StepKind.review
                            ? AppColors.amber
                            : theme.colorScheme.primary)),
              ]),
              const SizedBox(height: 12),
              InlineQuestion(
                key: ValueKey('ls-${index}-${step.question!.id}'),
                q: step.question!,
                onAnswered: _onAnswered,
              ),
            ],
          ),
        );
      case StepKind.done:
        return const SizedBox.shrink();
    }
  }

  Widget _doneView(BuildContext context) {
    final theme = Theme.of(context);
    final again = appStore.topicProgress(widget.topicId)?.reviews ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(child: ProgressRing(value: score, size: 96)),
        const SizedBox(height: 20),
        Text(
          score >= 0.85
              ? 'Konuyu çok iyi kavradın'
              : score >= 0.6
                  ? 'İyi iş, biraz daha pekiştir'
                  : 'Bu konu tekrar ister',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          practiceTotal == 0
              ? 'Anlatımı tamamladın.'
              : '$practiceTotal sorudan $correct tanesi ipucusuz doğru.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (!finished)
          AppCard(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderColor: theme.colorScheme.primary.withOpacity(0.4),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dersi bitirince bu konu "öğrenildi" sayılır ve unutma eğrisine göre '
                    'tekrar için sıraya girer.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            color: AppColors.success.withOpacity(0.10),
            borderColor: AppColors.success.withOpacity(0.4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    again <= 1
                        ? 'Konu öğrenildi olarak işaretlendi. Tekrar zamanı geldiğinde "Öğren" sekmesinde çıkacak.'
                        : 'Tekrar kaydedildi. Bir sonraki tekrar daha ileri bir tarihe ertelendi.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (!finished)
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Dersi bitir'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kapat'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            lesson = appStore.buildLessonFor(widget.topicId);
            index = 0;
            answeredCurrent = false;
            correct = 0;
            practiceTotal = lesson.questionCount;
            finished = false;
          }),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Baştan çöz'),
        ),
      ],
    );
  }
}

/// Unutma eğrisine göre konu tekrarı. Sırayla gelen her konu için kısa bir
/// hatırlatma + birkaç pratik soru; performansa göre tekrar tarihi güncellenir.
class TopicReviewPage extends StatefulWidget {
  final List<Topic> topics;
  const TopicReviewPage({super.key, required this.topics});

  @override
  State<TopicReviewPage> createState() => _TopicReviewPageState();
}

class _TopicReviewPageState extends State<TopicReviewPage> {
  int tIndex = 0;

  void _onGraded() {
    if (tIndex + 1 >= widget.topics.length) {
      Navigator.of(context).pop();
    } else {
      setState(() => tIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.topics.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konu tekrarı')),
        body: const EmptyState(
          icon: Icons.verified_rounded,
          title: 'Tekrar edilecek konu yok',
          message: 'Unutma zamanı gelen konular burada çıkar.',
        ),
      );
    }
    final topic = widget.topics[tIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konu tekrarı'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (tIndex + 1) / widget.topics.length,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
      body: _TopicReviewStep(
        key: ValueKey('rev-${topic.id}'),
        topic: topic,
        position: tIndex + 1,
        total: widget.topics.length,
        onGraded: _onGraded,
      ),
    );
  }
}

class _TopicReviewStep extends StatefulWidget {
  final Topic topic;
  final int position;
  final int total;
  final VoidCallback onGraded;
  const _TopicReviewStep({
    super.key,
    required this.topic,
    required this.position,
    required this.total,
    required this.onGraded,
  });

  @override
  State<_TopicReviewStep> createState() => _TopicReviewStepState();
}

class _TopicReviewStepState extends State<_TopicReviewStep> {
  late List<Question> qs;
  int answered = 0;
  int correct = 0;
  bool graded = false;

  @override
  void initState() {
    super.initState();
    qs = appStore.content.questions
        .where((q) =>
            q.textId == null &&
            q.type != QType.write &&
            q.topics.contains(widget.topic.id))
        .toList()
      ..shuffle();
    qs = qs.take(3).toList();
  }

  void _onAnswered(bool ok, int hints) {
    if (ok && hints == 0) correct++;
    answered++;
    if (answered >= qs.length) {
      final ratio = qs.isEmpty ? 1.0 : correct / qs.length;
      final grade = ratio >= 0.9
          ? 5
          : ratio >= 0.66
              ? 4
              : ratio >= 0.34
                  ? 3
                  : 0;
      appStore.reviewTopic(widget.topic.id, grade);
      setState(() => graded = true);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.topic;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          LevelBadge(t.level),
          const SizedBox(width: 8),
          Text('Konu ${widget.position} / ${widget.total}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        const SizedBox(height: 8),
        Text(t.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(Icons.menu_book_rounded,
                  color: theme.colorScheme.primary),
              title: Text('Hatırlatma', style: theme.textTheme.titleSmall),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                MdView(t.notes.isEmpty ? 'Not yok.' : t.notes),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (qs.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Text('Bu konuda pratik soru yok.'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    appStore.reviewTopic(widget.topic.id, 4);
                    widget.onGraded();
                  },
                  child: const Text('Okudum, sonraki'),
                ),
              ],
            ),
          )
        else
          ...List.generate(qs.length, (i) {
            if (i > answered) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Soru ${i + 1} / ${qs.length}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 8),
                    InlineQuestion(
                      key: ValueKey('rq-${qs[i].id}'),
                      q: qs[i],
                      onAnswered: _onAnswered,
                    ),
                  ],
                ),
              ),
            );
          }),
        if (graded) ...[
          AppCard(
            color: AppColors.success.withOpacity(0.10),
            borderColor: AppColors.success.withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Bu konu: $correct / ${qs.length}',
                      style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Tekrar tarihi performansına göre güncellendi.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.onGraded,
            icon: Icon(widget.position >= widget.total
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded),
            label: Text(
                widget.position >= widget.total ? 'Bitir' : 'Sonraki konu'),
          ),
        ],
      ],
    );
  }
}
