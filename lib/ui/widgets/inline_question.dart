import 'package:flutter/material.dart';

import '../../app_store.dart';
import '../../core/grader.dart';
import '../../core/models.dart';
import '../theme.dart';
import 'md_view.dart';

/// Ders ve konu tekrarı içinde gömülü tek soru. Şıklı / doğru-yanlış / kısa.
/// Cevaplanınca [onAnswered] (doğru mu, kaç ipucu) çağrılır ve istatistiğe işlenir.
class InlineQuestion extends StatefulWidget {
  final Question q;
  final void Function(bool correct, int hints) onAnswered;
  const InlineQuestion({super.key, required this.q, required this.onAnswered});

  @override
  State<InlineQuestion> createState() => _InlineQuestionState();
}

enum _Out { none, correct, near, wrong, revealed }

class _InlineQuestionState extends State<InlineQuestion> {
  int hintLevel = 0;
  int? chosen;
  _Out outcome = _Out.none;
  String? inputError;
  final input = TextEditingController();

  Question get q => widget.q;
  bool get answered => outcome != _Out.none;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _finish(bool correct, String answer) {
    appStore.recordAnswer(q,
        correct: correct, hintsUsed: hintLevel, answer: answer);
    widget.onAnswered(correct, hintLevel);
  }

  void _choose(int i) {
    if (answered) return;
    final ok = i == q.answerIndex;
    setState(() {
      chosen = i;
      outcome = ok ? _Out.correct : _Out.wrong;
    });
    _finish(ok, q.options[i]);
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
        GradeResult.correct => _Out.correct,
        GradeResult.nearMiss => _Out.near,
        GradeResult.wrong => _Out.wrong,
      };
    });
    _finish(g == GradeResult.correct, txt);
  }

  void _nextHint() {
    if (answered) return;
    setState(() {
      if (hintLevel < q.hints.length) {
        hintLevel++;
      } else {
        hintLevel = 3;
        outcome = _Out.revealed;
      }
    });
    if (outcome == _Out.revealed) _finish(false, '(cevap gösterildi)');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(q.prompt,
            style: theme.textTheme.titleMedium?.copyWith(height: 1.4)),
        const SizedBox(height: 14),
        if (q.type == QType.mcq || q.type == QType.tf)
          ...List.generate(q.options.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _option(context, i),
              ))
        else
          _shortField(context),
        const SizedBox(height: 4),
        for (var i = 0; i < hintLevel && i < q.hints.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _hintCard(context, q.hints[i]),
          ),
        if (!answered)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _nextHint,
              icon: Icon(hintLevel < q.hints.length
                  ? Icons.lightbulb_outline_rounded
                  : Icons.visibility_rounded),
              label: Text(hintLevel < q.hints.length
                  ? 'İpucu (${hintLevel + 1}/${q.hints.length + 1})'
                  : 'Cevabı göster'),
            ),
          ),
        if (answered) _feedback(context),
      ],
    );
  }

  Widget _hintCard(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 18, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _shortField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: input,
          enabled: !answered,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _checkShort(),
          onChanged: (_) {
            if (inputError != null) setState(() => inputError = null);
          },
          decoration: InputDecoration(
            labelText: 'Cevabın',
            errorText: inputError,
          ),
        ),
        const SizedBox(height: 8),
        if (!answered)
          FilledButton.tonal(
              onPressed: _checkShort, child: const Text('Kontrol et')),
      ],
    );
  }

  Widget _option(BuildContext context, int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCorrect = i == q.answerIndex;
    final isChosen = i == chosen;
    Color border = scheme.outlineVariant.withOpacity(0.7);
    Color bg = scheme.surfaceContainerLow;
    Color badgeBg = scheme.surfaceContainerHigh;
    Color badgeFg = scheme.onSurfaceVariant;
    IconData? tr;
    if (answered && isCorrect) {
      border = AppColors.success;
      bg = AppColors.success.withOpacity(0.10);
      badgeBg = AppColors.success;
      badgeFg = Colors.white;
      tr = Icons.check_circle_rounded;
    } else if (answered && isChosen) {
      border = AppColors.danger;
      bg = AppColors.danger.withOpacity(0.08);
      badgeBg = AppColors.danger;
      badgeFg = Colors.white;
      tr = Icons.cancel_rounded;
    }
    final letter =
        q.type == QType.tf ? (i == 0 ? 'D' : 'Y') : String.fromCharCode(65 + i);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: border,
            width: answered && (isCorrect || isChosen) ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: answered ? null : () => _choose(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: badgeBg, borderRadius: BorderRadius.circular(9)),
                  child: Text(letter,
                      style: TextStyle(
                          color: badgeFg, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(q.options[i],
                        style: theme.textTheme.bodyLarge)),
                if (tr != null)
                  Icon(tr,
                      color:
                          isCorrect ? AppColors.success : AppColors.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedback(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    late final String head;
    late final Color color;
    late final IconData icon;
    switch (outcome) {
      case _Out.correct:
        head = hintLevel > 0 ? 'Doğru (ipucuyla)' : 'Doğru!';
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case _Out.near:
        head = 'Çok yakın';
        color = AppColors.amber;
        icon = Icons.error_outline_rounded;
        break;
      case _Out.wrong:
        head = 'Yanlış';
        color = AppColors.danger;
        icon = Icons.cancel_rounded;
        break;
      default:
        head = 'Cevap';
        color = theme.colorScheme.primary;
        icon = Icons.visibility_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(dark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(head,
                style: theme.textTheme.titleMedium?.copyWith(color: color)),
          ]),
          if (q.type != QType.write) ...[
            const SizedBox(height: 6),
            Text('Doğru cevap: ${q.correctText}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (q.explain.isNotEmpty) ...[
            const SizedBox(height: 8),
            MdView(q.explain),
          ],
        ],
      ),
    );
  }
}
