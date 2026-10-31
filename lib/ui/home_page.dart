import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/models.dart';
import 'lesson_page.dart';
import 'mistakes_page.dart';
import 'quiz_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';
import 'test_setup_page.dart';
import 'texts_page.dart';
import 'theme.dart';
import 'widgets/md_view.dart';

const _trMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];
const _trDays = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
];

/// Ana sayfa: günlük tekrar + seviye ilerlemesi + konu haritası.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String level = 'A1';

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String _date() {
    final n = DateTime.now();
    return '${n.day} ${_trMonths[n.month - 1]}, ${_trDays[n.weekday - 1]}';
  }

  /// Seviyedeki konuların ortalama başarısı ve çalışılmış konu oranı.
  ({double? mastery, int studied, int total}) _levelStats(String lv) {
    final topics = appStore.content.topics.where((t) => t.level == lv).toList();
    var sum = 0.0;
    var n = 0;
    for (final t in topics) {
      final m = appStore.sessions.topicMastery(t.id);
      if (m != null) {
        sum += m;
        n++;
      }
    }
    return (mastery: n == 0 ? null : sum / n, studied: n, total: topics.length);
  }

  void _startDaily() {
    final qs = appStore.sessions.buildDaily();
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Şimdilik tekrar edilecek soru yok. Önce birkaç test çöz.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPage(title: 'Günlük tekrar', questions: qs)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final theme = Theme.of(context);
        final due = appStore.dueCards;
        final openMistakes = appStore.openMistakes.length;
        final solved = appStore.state.qstats.length;
        final weak = appStore.sessions.weakTopics().take(4).toList();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Kapak + selam
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1100 / 614,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset('assets/images/cover.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppColors.primary)),
                        Positioned(
                          left: 20,
                          top: 20,
                          right: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_date(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.75),
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${_greeting()} 👋',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                      color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Material(
                            color: Colors.black.withOpacity(0.28),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Ayarlar',
                              icon: const Icon(Icons.tune_rounded,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsPage())),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (appStore.loadError != null)
                  AppCard(
                    color: theme.colorScheme.errorContainer,
                    child: Text(appStore.loadError!),
                  ),
                _DailyHero(
                  openMistakes: openMistakes,
                  dueCards: due.length,
                  onQuestions: _startDaily,
                  onCards: due.isEmpty
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FlashcardPage(cards: due))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StatTile(
                      icon: Icons.task_alt_rounded,
                      value: '$solved',
                      label: 'çözülen soru',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      icon: Icons.error_outline_rounded,
                      value: '$openMistakes',
                      label: 'açık hata',
                      color: AppColors.coral,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MistakesPage())),
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      icon: Icons.bookmark_rounded,
                      value: '${appStore.state.saved.length}',
                      label: 'kayıt',
                      color: AppColors.amber,
                    ),
                  ],
                ),
                if (weak.isNotEmpty) ...[
                  const SectionTitle('Zayıf konular'),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        for (final id in weak)
                          _topicRow(context, appStore.content.topicById[id]!),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('Bunlardan test oluştur'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => TestSetupPage(
                                        initialTopics: weak.toSet()))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SectionTitle('Seviyeler'),
                Row(
                  children: [
                    for (final lv in ['A1', 'A2', 'B1']) ...[
                      Expanded(child: _levelCard(context, lv)),
                      if (lv != 'B1') const SizedBox(width: 10),
                    ],
                  ],
                ),
                SectionTitle('$level konuları',
                    trailing: Text(
                      'renk = başarı',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    )),
                ..._topicList(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _levelCard(BuildContext context, String lv) {
    final theme = Theme.of(context);
    final s = _levelStats(lv);
    final selected = lv == level;
    final c = levelColor(lv);
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      color: selected ? c.withOpacity(0.10) : null,
      borderColor: selected ? c.withOpacity(0.6) : null,
      onTap: () => setState(() => level = lv),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(lv,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: c, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                s.mastery == null ? '' : '%${(s.mastery! * 100).round()}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.total == 0 ? 0 : s.studied / s.total,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
          const SizedBox(height: 6),
          Text('${s.studied}/${s.total} konu',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _topicRow(BuildContext context, Topic t) {
    final theme = Theme.of(context);
    final m = appStore.sessions.topicMastery(t.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TopicPage(topic: t))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ProgressRing(value: m, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(t.group,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            LevelBadge(t.level),
          ],
        ),
      ),
    );
  }

  List<Widget> _topicList(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<Topic>>{};
    for (final t in appStore.content.topics) {
      if (t.level != level) continue;
      groups.putIfAbsent(t.group, () => []).add(t);
    }
    final out = <Widget>[];
    for (final e in groups.entries) {
      out.add(AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('home-${e.key}'),
            initiallyExpanded: groups.length == 1,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            title: Text(e.key, style: theme.textTheme.titleSmall),
            subtitle: Text('${e.value.length} konu',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            children: [
              for (final t in e.value) _topicTile(context, t),
            ],
          ),
        ),
      ));
    }
    return out;
  }

  Widget _topicTile(BuildContext context, Topic t) {
    final theme = Theme.of(context);
    final m = appStore.sessions.topicMastery(t.id);
    final attempts = appStore.sessions.topicAttempts(t.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TopicPage(topic: t))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: masteryColor(m, theme.colorScheme),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            if (m != null)
              Text('%${(m * 100).round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: masteryColor(m, theme.colorScheme)))
            else
              Text(attempts == 0 ? 'yeni' : '',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Günlük tekrar kartı (ana sayfanın odağı).
class _DailyHero extends StatelessWidget {
  final int openMistakes;
  final int dueCards;
  final VoidCallback onQuestions;
  final VoidCallback? onCards;

  const _DailyHero({
    required this.openMistakes,
    required this.dueCards,
    required this.onQuestions,
    required this.onCards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF15463A) : AppColors.primary;
    final empty = openMistakes == 0 && dueCards == 0;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text('Günlük tekrar',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  empty
                      ? 'Bugün tertemiz.'
                      : '$openMistakes hata · $dueCards kart',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  empty
                      ? 'Bir test çöz ya da metin dinle; hataların ve kaydettiklerin buraya gelir.'
                      : 'Hatalarının konularından yeni sorular ve tekrar zamanı gelen kartların.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.82)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: bg,
                        ),
                        onPressed: onQuestions,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Soru tekrarı'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white38,
                          side: BorderSide(
                              color: Colors.white
                                  .withOpacity(onCards == null ? 0.2 : 0.5)),
                        ),
                        onPressed: onCards,
                        icon: const Icon(Icons.style_rounded),
                        label: Text('Kartlar ($dueCards)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konu sayfası: kural notu + bu konudan test.
class TopicPage extends StatelessWidget {
  final Topic topic;
  const TopicPage({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qs = appStore.content.questions
        .where((q) => q.textId == null && q.topics.contains(topic.id))
        .toList();
    final texts = appStore.content.texts
        .where((t) => t.topics.contains(topic.id))
        .toList();
    final m = appStore.sessions.topicMastery(topic.id);
    return Scaffold(
      appBar: AppBar(title: Text(topic.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      LevelBadge(topic.level, large: true),
                      const SizedBox(width: 8),
                      Pill(topic.group),
                    ]),
                    const SizedBox(height: 10),
                    Text(topic.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('${qs.length} soru',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(value: m, size: 56),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LessonPage(topicId: topic.id))),
              icon: const Icon(Icons.school_rounded),
              label: Text(appStore.isLearned(topic.id)
                  ? 'Dersi tekrar et'
                  : 'Etkileşimli ders'),
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle('Kural notu',
              padding: const EdgeInsets.only(bottom: 8)),
          AppCard(
            child: MdView(
                topic.notes.isEmpty ? 'Bu konu için henüz not yok.' : topic.notes),
          ),
          if (texts.isNotEmpty) ...[
            const SectionTitle('Bu konunun geçtiği metinler'),
            for (final t in texts)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReaderPage(text: t))),
                child: Row(
                  children: [
                    Icon(
                        t.kind == 'dialog'
                            ? Icons.forum_rounded
                            : Icons.auto_stories_rounded,
                        color: levelColor(t.level)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t.title, style: theme.textTheme.titleSmall),
                    ),
                    Text('${t.kindLabel} · ${t.lengthLabel}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: qs.isEmpty
                      ? null
                      : () {
                          final pick = (List.of(qs)..shuffle()).take(10).toList();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                QuizPage(title: topic.title, questions: pick),
                          ));
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Bu konudan 10 soru'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 50,
                child: IconButton.outlined(
                  tooltip: 'Testi özelleştir',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TestSetupPage(initialTopics: {topic.id}),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
