import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/models.dart';
import '../services/tts_service.dart';
import 'quiz_page.dart';
import 'theme.dart';
import 'widgets/token_text.dart';

/// Okuma / dinleme metinleri listesi.
class TextsPage extends StatefulWidget {
  const TextsPage({super.key});

  @override
  State<TextsPage> createState() => _TextsPageState();
}

class _TextsPageState extends State<TextsPage> {
  final levels = <String>{'A1', 'A2', 'B1'};
  String kind = 'all'; // all | story | dialog
  String length = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = appStore.content.texts.where((t) {
      if (!levels.contains(t.level)) return false;
      if (kind != 'all' && t.kind != kind) return false;
      if (length != 'all' && t.length != length) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dinle ve oku')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final l in ['A1', 'A2', 'B1'])
                FilterChip(
                  label: Text(l),
                  selected: levels.contains(l),
                  onSelected: (v) => setState(() {
                    if (v) {
                      levels.add(l);
                    } else if (levels.length > 1) {
                      levels.remove(l);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final k in const [
                ['all', 'Hepsi'],
                ['story', 'Hikaye'],
                ['dialog', 'Diyalog'],
              ])
                ChoiceChip(
                  label: Text(k[1]),
                  selected: kind == k[0],
                  onSelected: (_) => setState(() => kind = k[0]),
                ),
              const SizedBox(width: 8),
              for (final k in const [
                ['all', 'Her uzunluk'],
                ['short', 'Kısa'],
                ['medium', 'Orta'],
                ['long', 'Uzun'],
              ])
                ChoiceChip(
                  label: Text(k[1]),
                  selected: length == k[0],
                  onSelected: (_) => setState(() => length = k[0]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (texts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Bu filtrelerle metin yok.', textAlign: TextAlign.center),
            ),
          for (final t in texts)
            ListenableBuilder(
              listenable: appStore,
              builder: (context, _) {
                final read = appStore.state.readTexts.contains(t.id);
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReaderPage(text: t))),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: levelColor(t.level).withOpacity(0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          t.kind == 'dialog'
                              ? Icons.forum_rounded
                              : Icons.auto_stories_rounded,
                          color: levelColor(t.level),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                LevelBadge(t.level),
                                Pill(t.kindLabel),
                                Pill(t.lengthLabel),
                                Pill('${t.wordCount} kelime'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      read
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.success)
                          : Icon(Icons.play_circle_fill_rounded,
                              size: 32, color: theme.colorScheme.primary),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Dinleme + okuma ekranı: oynatıcı, hız, transkript, kelime anlamı, kaydetme.
class ReaderPage extends StatefulWidget {
  final TextItem text;
  const ReaderPage({super.key, required this.text});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final tts = TtsService.instance;
  late bool showTranscript;
  bool finishedOnce = false;

  TextItem get t => widget.text;

  @override
  void initState() {
    super.initState();
    final mode = appStore.state.settings.transcriptMode;
    showTranscript = mode == 'on';
    tts.setSpeed(appStore.state.settings.speed);
    tts.addListener(_onTts);
  }

  void _onTts() {
    if (!mounted) return;
    if (!tts.playing && tts.textId == t.id && tts.current == -1) {
      // metin sonuna kadar çalındı
      if (!finishedOnce) {
        finishedOnce = true;
        appStore.markRead(t.id);
        if (appStore.state.settings.transcriptMode == 'after') {
          showTranscript = true;
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    tts.removeListener(_onTts);
    tts.stop();
    super.dispose();
  }

  int get _cur => tts.textId == t.id ? tts.current : -1;

  void _playPause() {
    if (tts.playing && tts.textId == t.id) {
      tts.stop();
    } else {
      final from = _cur >= 0 ? _cur : 0;
      tts.play(t, from: from);
    }
  }

  void _jump(int delta) {
    final c = _cur < 0 ? 0 : _cur;
    final n = (c + delta).clamp(0, t.sentences.length - 1).toInt();
    if (tts.playing) {
      tts.play(t, from: n);
    } else {
      tts.play(t, from: n, only: true);
    }
  }

  void _startQuiz() {
    appStore.markRead(t.id);
    tts.stop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizPage(title: t.title, questions: t.questions),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = tts.playing && tts.textId == t.id;
    final speed = appStore.state.settings.speed;
    final topicTitles = t.topics
        .map((id) => appStore.content.topicById[id]?.title)
        .whereType<String>()
        .join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        actions: [
          IconButton(
            tooltip: showTranscript ? 'Metni gizle' : 'Metni göster',
            icon: Icon(showTranscript
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => showTranscript = !showTranscript),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      LevelBadge(t.level, large: true),
                      Pill(t.kindLabel),
                      Pill(t.lengthLabel),
                      Pill('${t.wordCount} kelime'),
                    ],
                  ),
                  if (topicTitles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(topicTitles,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                  const SizedBox(height: 14),
                  if (showTranscript)
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: TokenText(
                        sentences: t.sentences.map((s) => s.text).toList(),
                        speakers: t.kind == 'dialog'
                            ? t.sentences.map((s) => s.speaker).toList()
                            : const [],
                        text: t,
                        highlightSentence: _cur,
                        onSentenceTap: (i) =>
                            tts.play(t, from: i, only: !playing),
                      ),
                    )
                  else
                    _hiddenTranscript(context),
                  if (showTranscript)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 16, color: theme.colorScheme.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Dokun: anlam · Basılı tut: seç ve kaydet · Çift dokun: cümleyi dinle',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: t.questions.isEmpty ? null : _startQuiz,
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text('Bu metinden sınav ol (${t.questions.length} soru)'),
                  ),
                ],
              ),
            ),
            _player(context, playing, speed),
          ],
        ),
      ),
    );
  }

  Widget _hiddenTranscript(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones_rounded,
                size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text('Önce metni görmeden dinle',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cümle ${_cur < 0 ? '–' : _cur + 1} / ${t.sentences.length}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.visibility_rounded),
            onPressed: () => setState(() => showTranscript = true),
            label: const Text('Metni göster'),
          ),
        ],
      ),
    );
  }

  Widget _player(BuildContext context, bool playing, double speed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cur = _cur;
    final progress = t.sentences.isEmpty
        ? 0.0
        : ((cur < 0 ? (finishedOnce ? t.sentences.length : 0) : cur + 1) /
            t.sentences.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(cur < 0 ? '–' : '${cur + 1}',
                  style: theme.textTheme.labelMedium),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${t.sentences.length}', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Baştan',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: () => tts.play(t, from: 0),
              ),
              IconButton(
                tooltip: 'Önceki cümle',
                iconSize: 30,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: () => _jump(-1),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton.filled(
                  iconSize: 36,
                  tooltip: playing ? 'Durdur' : 'Oynat',
                  icon: Icon(playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  onPressed: _playPause,
                ),
              ),
              IconButton(
                tooltip: 'Sonraki cümle',
                iconSize: 30,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: () => _jump(1),
              ),
              IconButton(
                tooltip: 'Bu cümleyi tekrarla',
                icon: const Icon(Icons.replay_rounded),
                onPressed: () =>
                    tts.play(t, from: cur < 0 ? 0 : cur, only: true),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: scheme.outline),
              Expanded(
                child: Slider(
                  min: 0.5,
                  max: 1.5,
                  divisions: 20,
                  value: speed.clamp(0.5, 1.5).toDouble(),
                  label: '${speed.toStringAsFixed(2)}x',
                  onChanged: (v) {
                    appStore.updateSettings((s) => s.speed = v);
                    tts.setSpeed(v);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${speed.toStringAsFixed(2)}x',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
