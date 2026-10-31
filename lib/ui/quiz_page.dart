import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/grader.dart';
import '../core/models.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import 'theme.dart';
import 'widgets/md_view.dart';
import 'widgets/token_text.dart';

enum _Outcome { none, correct, near, wrong, revealed }

/// Soru çözme ekranı. Tüm soru tiplerini ve kademeli ipucunu yönetir.
class QuizPage extends StatefulWidget {
  final String title;
  final List<Question> questions;
  const QuizPage({super.key, required this.title, required this.questions});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _Result {
  final Question q;
  final bool correct;
  final int hints;
  _Result(this.q, this.correct, this.hints);
}

class _QuizPageState extends State<QuizPage> {
  int index = 0;
  int hintLevel = 0; // 0..3 (3 = cevap gösterildi)
  int? chosen;
  _Outcome outcome = _Outcome.none;
  bool lookedUp = false; // kelime anlamına baktı mı (kelime sorularında ipucu sayılır)
  String? inputError;
  bool aiLoading = false;
  WritingFeedback? ai;
  String? aiError;
  final input = TextEditingController();
  final results = <_Result>[];

  Question get q => widget.questions[index];
  bool get answered => outcome != _Outcome.none;

  @override
  void dispose() {
    input.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  int get _effectiveHints => hintLevel + (lookedUp ? 1 : 0);

  void _finish(bool correct, {String answer = ''}) {
    final hints = _effectiveHints;
    appStore.recordAnswer(q, correct: correct, hintsUsed: hints, answer: answer);
    results.add(_Result(q, correct, hints));
  }

  void _chooseOption(int i) {
    if (answered) return;
    final ok = i == q.answerIndex;
    setState(() {
      chosen = i;
      outcome = ok ? _Outcome.correct : _Outcome.wrong;
    });
    _finish(ok, answer: q.options[i]);
  }

  void _checkShort() {
    if (answered) return;
    final txt = input.text.trim();
    if (txt.isEmpty) {
      setState(() => inputError = 'Önce bir cevap yaz.');
      return;
    }
    final g = gradeShort(txt, q.accepted);
    setState(() {
      outcome = switch (g) {
        GradeResult.correct => _Outcome.correct,
        GradeResult.nearMiss => _Outcome.near,
        GradeResult.wrong => _Outcome.wrong,
      };
    });
    _finish(g == GradeResult.correct, answer: txt);
  }

  Future<void> _checkWriting() async {
    if (answered || aiLoading) return;
    final txt = input.text.trim();
    final wc = countWords(txt);
    if (wc == 0) {
      setState(() => inputError = 'Önce cevabını yaz.');
      return;
    }
    if (q.minWords > 0 && wc < (q.minWords * 0.6).round()) {
      setState(() => inputError =
          'Biraz daha yaz: en az ${q.minWords} kelime hedefleniyor ($wc yazdın).');
      return;
    }
    final s = appStore.state.settings;
    if (s.apiKey.trim().isEmpty) {
      // Anahtar yoksa: örnek cevabı göster, kendin değerlendir.
      setState(() {
        ai = null;
        aiError = 'API anahtarı yok. Örnek cevapla karşılaştırıp kendin değerlendir.';
        outcome = _Outcome.revealed;
      });
      return;
    }
    setState(() {
      aiLoading = true;
      aiError = null;
    });
    try {
      final titles = q.topics
          .map((t) => appStore.content.topicById[t]?.title ?? t)
          .toList();
      final fb = await AiService.evaluate(
        apiKey: s.apiKey.trim(),
        model: s.model.trim().isEmpty ? 'gemini-2.5-flash' : s.model.trim(),
        level: q.level,
        task: q.prompt,
        answer: txt,
        topicTitles: titles,
      );
      if (!mounted) return;
      setState(() {
        ai = fb;
        aiLoading = false;
        outcome = fb.passed ? _Outcome.correct : _Outcome.wrong;
      });
      _finish(fb.passed, answer: txt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        aiLoading = false;
        aiError = 'Değerlendirilemedi: $e\nÖrnek cevapla karşılaştırıp kendin değerlendirebilirsin.';
        outcome = _Outcome.revealed;
      });
    }
  }

  void _selfAssess(bool ok) {
    setState(() => outcome = ok ? _Outcome.correct : _Outcome.wrong);
    _finish(ok, answer: input.text.trim());
  }

  void _nextHint() {
    if (answered) return;
    final textHints = q.hints.length;
    setState(() {
      if (hintLevel < textHints) {
        hintLevel++;
      } else {
        hintLevel = 3;
        outcome = _Outcome.revealed;
      }
    });
    if (outcome == _Outcome.revealed && q.type != QType.write) {
      _finish(false, answer: '(cevap gösterildi)');
    }
    if (hintLevel == 1 && q.replay != null && q.textId != null) {
      _replay();
    }
  }

  void _replay() {
    final t = q.textId == null ? null : appStore.content.textById[q.textId];
    if (t == null || q.replay == null) return;
    TtsService.instance.setSpeed(appStore.state.settings.speed);
    TtsService.instance.play(t, from: q.replay!, only: true);
  }

  void _next() {
    TtsService.instance.stop();
    if (index + 1 >= widget.questions.length) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => _SummaryPage(title: widget.title, results: results),
      ));
      return;
    }
    setState(() {
      index++;
      hintLevel = 0;
      chosen = null;
      outcome = _Outcome.none;
      lookedUp = false;
      inputError = null;
      ai = null;
      aiError = null;
      aiLoading = false;
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Bu seçimle eşleşen soru yok. Filtreleri genişletmeyi dene.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final topicTitles = q.topics
        .map((t) => appStore.content.topicById[t])
        .whereType<Topic>()
        .toList();
    final textItem =
        q.textId == null ? null : appStore.content.textById[q.textId];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Soruyu kaydet',
            icon: Icon(appStore.isSaved(q.prompt)
                ? Icons.bookmark
                : Icons.bookmark_border),
            onPressed: () {
              appStore.saveItem(
                text: q.prompt,
                kind: 'question',
                meaning: q.correctText,
                context: q.explain,
                sourceId: q.id,
              );
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Soru kaydedildi')));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                    end: (index + (answered ? 1 : 0)) / widget.questions.length),
                duration: const Duration(milliseconds: 350),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                Text('Soru ${index + 1}',
                    style: theme.textTheme.titleSmall),
                Text(' / ${widget.questions.length}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const Spacer(),
                LevelBadge(q.level),
                const SizedBox(width: 6),
                Pill(qTypeLabel(q.type)),
              ],
            ),
            const SizedBox(height: 6),
            if (topicTitles.isNotEmpty)
              Text(topicTitles.map((t) => t.title).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            if (textItem != null) _passage(context, textItem),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: TokenText(
              key: ValueKey('p${q.id}'),
              sentences: [q.prompt],
              text: textItem,
              style: theme.textTheme.titleLarge
                  ?.copyWith(height: 1.45, fontWeight: FontWeight.w600, fontSize: 20),
              onLookup: () {
                final asksMeaning = q.prompt.contains(' mean') ||
                    q.prompt.contains('ne demek') ||
                    q.prompt.contains('anlamı');
                if (!answered && !lookedUp && asksMeaning) {
                  // kelime anlamı soran sorularda sözlüğe bakmak ipucu sayılır
                  setState(() => lookedUp = true);
                }
              },
            ),
            ),
            const SizedBox(height: 4),
            ..._answerArea(context),
            const SizedBox(height: 12),
            ..._hintArea(context),
            if (answered) ...[
              const SizedBox(height: 12),
              _feedback(context),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (q.type == QType.write &&
                        outcome == _Outcome.revealed)
                    ? null
                    : _next,
                icon: Icon(index + 1 >= widget.questions.length
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded),
                label: Text(index + 1 >= widget.questions.length
                    ? 'Bitir'
                    : 'Sonraki soru'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passage(BuildContext context, TextItem t) {
    return AppCard(
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
        leading: Icon(
            t.kind == 'dialog' ? Icons.forum_rounded : Icons.auto_stories_rounded,
            color: levelColor(t.level)),
        title: Text(t.title),
        subtitle: Text('${t.kindLabel} · metni göster'),
        trailing: IconButton(
          tooltip: 'Metni baştan dinle',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () {
            TtsService.instance.setSpeed(appStore.state.settings.speed);
            TtsService.instance.play(t);
          },
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListenableBuilder(
            listenable: TtsService.instance,
            builder: (context, _) => TokenText(
              sentences: t.sentences.map((s) => s.text).toList(),
              speakers: t.kind == 'dialog'
                  ? t.sentences.map((s) => s.speaker).toList()
                  : const [],
              text: t,
              highlightSentence: TtsService.instance.textId == t.id
                  ? TtsService.instance.current
                  : -1,
              onSentenceTap: (i) {
                TtsService.instance.setSpeed(appStore.state.settings.speed);
                TtsService.instance.play(t, from: i, only: true);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  List<Widget> _answerArea(BuildContext context) {
    final theme = Theme.of(context);
    switch (q.type) {
      case QType.mcq:
      case QType.tf:
        return [
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _optionButton(context, i),
            ),
        ];
      case QType.short:
        return [
          TextField(
            controller: input,
            enabled: !answered,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkShort(),
            onChanged: (_) {
              if (inputError != null) setState(() => inputError = null);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Cevabın',
              errorText: inputError,
            ),
          ),
          const SizedBox(height: 8),
          if (!answered)
            FilledButton.tonal(
                onPressed: _checkShort, child: const Text('Kontrol et')),
        ];
      case QType.write:
        final wc = countWords(input.text);
        return [
          TextField(
            controller: input,
            enabled: !answered && !aiLoading,
            minLines: 5,
            maxLines: 12,
            onChanged: (_) => setState(() => inputError = null),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'İngilizce yaz...',
              errorText: inputError,
              helperText:
                  '$wc kelime${q.minWords > 0 ? ' · hedef ${q.minWords}' : ''}',
            ),
          ),
          const SizedBox(height: 8),
          if (!answered)
            FilledButton.tonalIcon(
              onPressed: aiLoading ? null : _checkWriting,
              icon: aiLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(aiLoading ? 'Değerlendiriliyor...' : 'Değerlendir'),
            ),
          if (!appStore.hasApiKey && !answered)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Yapay zekâ değerlendirmesi için Ayarlar\'dan Gemini API anahtarını gir. '
                'Anahtar yoksa örnek cevapla kendin karşılaştırırsın.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ];
    }
  }

  Widget _optionButton(BuildContext context, int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCorrect = i == q.answerIndex;
    final isChosen = i == chosen;
    Color border = scheme.outlineVariant.withOpacity(0.7);
    Color bg = scheme.surfaceContainerLow;
    Color badgeBg = scheme.surfaceContainerHigh;
    Color badgeFg = scheme.onSurfaceVariant;
    IconData? trailing;
    if (answered && isCorrect) {
      border = AppColors.success;
      bg = AppColors.success.withOpacity(0.10);
      badgeBg = AppColors.success;
      badgeFg = Colors.white;
      trailing = Icons.check_circle_rounded;
    } else if (answered && isChosen) {
      border = AppColors.danger;
      bg = AppColors.danger.withOpacity(0.08);
      badgeBg = AppColors.danger;
      badgeFg = Colors.white;
      trailing = Icons.cancel_rounded;
    }
    final letter = q.type == QType.tf
        ? (i == 0 ? 'D' : 'Y')
        : String.fromCharCode(65 + i);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: answered && (isCorrect || isChosen) ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: answered ? null : () => _chooseOption(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(letter,
                      style: TextStyle(
                          color: badgeFg, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(q.options[i],
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                if (trailing != null)
                  Icon(trailing,
                      color: isCorrect ? AppColors.success : AppColors.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _hintArea(BuildContext context) {
    final theme = Theme.of(context);
    final shown = <Widget>[];
    for (var i = 0; i < hintLevel && i < q.hints.length; i++) {
      shown.add(AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 2),
        color: theme.colorScheme.tertiaryContainer,
        borderColor: AppColors.amber.withOpacity(0.5),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.lightbulb_rounded,
              color: theme.colorScheme.onTertiaryContainer),
          title: Text(q.hints[i],
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
          trailing: (i == 0 && q.replay != null && q.textId != null)
              ? IconButton(
                  tooltip: 'İlgili cümleyi dinle',
                  icon: const Icon(Icons.replay),
                  onPressed: _replay,
                )
              : null,
        ),
      ));
    }
    if (!answered) {
      final total = q.hints.length + 1;
      final label = hintLevel < q.hints.length
          ? 'İpucu (${hintLevel + 1}/$total)'
          : 'Cevabı göster';
      shown.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _nextHint,
          icon: Icon(hintLevel < q.hints.length
              ? Icons.lightbulb_outline
              : Icons.visibility_outlined),
          label: Text(label),
        ),
      ));
      if (_effectiveHints > 0) {
        shown.add(Text(
          'İpucu kullandın: doğru cevaplasan da bu soru hata defterine "zorlandım" olarak düşer.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ));
      }
    }
    return shown;
  }

  Widget _feedback(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    late final String head;
    late final Color color;
    late final IconData icon;
    switch (outcome) {
      case _Outcome.correct:
        head = _effectiveHints > 0 ? 'Doğru (ipucuyla)' : 'Doğru!';
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case _Outcome.near:
        head = 'Çok yakın, ama tam değil';
        color = AppColors.amber;
        icon = Icons.error_outline_rounded;
        break;
      case _Outcome.wrong:
        head = 'Yanlış';
        color = AppColors.danger;
        icon = Icons.cancel_rounded;
        break;
      case _Outcome.revealed:
        head = q.type == QType.write ? 'Örnek cevap' : 'Cevap gösterildi';
        color = theme.colorScheme.primary;
        icon = Icons.visibility_rounded;
        break;
      case _Outcome.none:
        head = '';
        color = theme.colorScheme.primary;
        icon = Icons.info_outline;
    }
    return AppCard(
      margin: EdgeInsets.zero,
      color: color.withOpacity(dark ? 0.14 : 0.07),
      borderColor: color.withOpacity(0.45),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 8),
                Text(head,
                    style: theme.textTheme.titleLarge?.copyWith(color: color)),
              ],
            ),
            if (outcome == _Outcome.near)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Bir-iki harf farkı var. Gramerde tek harf bile kuralı değiştirebilir (work / works).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (q.type != QType.write) ...[
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'Doğru cevap: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                TextSpan(
                    text: q.correctText,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ])),
              if (q.type == QType.short && q.accepted.length > 1)
                Text('Kabul edilenler: ${q.accepted.join(' · ')}',
                    style: theme.textTheme.bodySmall),
            ],
            if (q.type == QType.write) ..._writingFeedback(context),
            if (q.explain.isNotEmpty) ...[
              const SizedBox(height: 10),
              MdView(q.explain),
            ],
            if (q.topics.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tid in q.topics)
                    if (appStore.content.topicById[tid] != null)
                      ActionChip(
                        avatar: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(appStore.content.topicById[tid]!.title,
                            overflow: TextOverflow.ellipsis),
                        onPressed: () => showTopicNotes(
                            context, appStore.content.topicById[tid]!),
                      ),
                ],
              ),
            ],
          ],
        ),
    );
  }

  List<Widget> _writingFeedback(BuildContext context) {
    final theme = Theme.of(context);
    final out = <Widget>[];
    final fb = ai;
    if (fb != null) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Puan: ${fb.score} / 10', style: theme.textTheme.titleSmall),
      ));
      if (fb.feedback.isNotEmpty) out.add(Text(fb.feedback));
      for (final e in fb.errors) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: e['wrong'],
                style: const TextStyle(decoration: TextDecoration.lineThrough)),
            const TextSpan(text: '  →  '),
            TextSpan(
                text: e['right'],
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((e['why'] ?? '').isNotEmpty)
              TextSpan(text: '\n${e['why']}', style: theme.textTheme.bodySmall),
          ])),
        ));
      }
      if (fb.corrected.isNotEmpty) {
        out.add(const SizedBox(height: 8));
        out.add(Text('Düzeltilmiş hâli:', style: theme.textTheme.labelLarge));
        out.add(SelectableText(fb.corrected));
      }
    }
    if (aiError != null) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(aiError!, style: theme.textTheme.bodySmall),
      ));
    }
    if (q.model.isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(Text('Örnek cevap:', style: theme.textTheme.labelLarge));
      out.add(SelectableText(q.model));
    }
    if (outcome == _Outcome.revealed) {
      out.add(const SizedBox(height: 10));
      out.add(Text('Kendi cevabını nasıl buldun?', style: theme.textTheme.labelLarge));
      out.add(const SizedBox(height: 4));
      out.add(Wrap(spacing: 8, children: [
        FilledButton.tonal(
            onPressed: () => _selfAssess(true), child: const Text('Doğruydu')),
        OutlinedButton(
            onPressed: () => _selfAssess(false),
            child: const Text('Hatalarım vardı')),
      ]));
    }
    return out;
  }
}

/// Konu notlarını alt sayfada gösterir.
void showTopicNotes(BuildContext context, Topic t) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, ctl) => ListView(
        controller: ctl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('${t.id} · ${t.title}',
              style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          MdView(t.notes.isEmpty ? 'Bu konu için not yok.' : t.notes),
        ],
      ),
    ),
  );
}

class _SummaryPage extends StatelessWidget {
  final String title;
  final List<_Result> results;
  const _SummaryPage({required this.title, required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = results.where((r) => r.correct && r.hints == 0).length;
    final hinted = results.where((r) => r.correct && r.hints > 0).length;
    final wrong = results.where((r) => !r.correct).length;
    final wrongOnes = results.where((r) => !r.correct || r.hints > 0).toList();
    final ratio = results.isEmpty ? 0.0 : correct / results.length;
    final msg = ratio >= 0.9
        ? 'Harika gidiyorsun'
        : ratio >= 0.6
            ? 'İyi iş, birkaç eksik var'
            : 'Bu konular tekrar istiyor';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ProgressRing(value: ratio, size: 76),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${results.length} sorudan $correct tanesi ipucusuz doğru',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              StatTile(
                  icon: Icons.check_rounded,
                  value: '$correct',
                  label: 'doğru',
                  color: AppColors.success),
              const SizedBox(width: 10),
              StatTile(
                  icon: Icons.lightbulb_rounded,
                  value: '$hinted',
                  label: 'ipucuyla',
                  color: AppColors.amber),
              const SizedBox(width: 10),
              StatTile(
                  icon: Icons.close_rounded,
                  value: '$wrong',
                  label: 'yanlış',
                  color: AppColors.danger),
            ],
          ),
          if (wrongOnes.isNotEmpty) ...[
            const SectionTitle('Hata defterine eklenenler'),
            for (final r in wrongOnes)
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.correct ? Icons.lightbulb_rounded : Icons.cancel_rounded,
                        size: 20,
                        color: r.correct ? AppColors.amber : AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.q.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Doğrusu: ${r.q.correctText}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Bunları tekrar çöz'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => QuizPage(
                      title: 'Tekrar',
                      questions: wrongOnes.map((r) => r.q).toList()),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Hepsi ipucusuz doğru. Hata defterine bir şey eklenmedi.',
                  textAlign: TextAlign.center),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
