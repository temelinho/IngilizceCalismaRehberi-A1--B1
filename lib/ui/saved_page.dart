import 'package:flutter/material.dart';

import '../app_store.dart';
import '../core/models.dart';
import '../core/user_state.dart';
import '../services/tts_service.dart';
import 'quiz_page.dart';
import 'theme.dart';

/// Kaydettiklerim: kelime, kalıp, cümle ve sorular.
class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  String filter = 'all';
  String query = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final theme = Theme.of(context);
        final items = appStore.state.saved.where((s) {
          if (filter != 'all' && s.kind != filter) return false;
          if (query.isNotEmpty &&
              !s.text.toLowerCase().contains(query) &&
              !s.meaning.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        }).toList();
        final due = appStore.dueCards;
        final savedQuestions = appStore.state.saved
            .where((s) => s.kind == 'question' && s.sourceId != null)
            .map((s) => appStore.content.questionById[s.sourceId])
            .whereType<Question>()
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Kaydettiklerim')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: due.isEmpty
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => FlashcardPage(cards: due))),
                      icon: const Icon(Icons.style_outlined),
                      label: Text('Kartları çalış (${due.length})'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: savedQuestions.isEmpty
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => QuizPage(
                                  title: 'Kaydettiğim sorular',
                                  questions: savedQuestions))),
                      icon: const Icon(Icons.quiz_outlined),
                      label: Text('Sorular (${savedQuestions.length})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Ara',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final f in const [
                  ['all', 'Hepsi'],
                  ['word', 'Kelime'],
                  ['phrase', 'Kalıp'],
                  ['sentence', 'Cümle'],
                  ['question', 'Soru'],
                ])
                  ChoiceChip(
                    label: Text(f[1]),
                    selected: filter == f[0],
                    onSelected: (_) => setState(() => filter = f[0]),
                  ),
              ]),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.bookmark_add_rounded,
                    title: 'Henüz kayıt yok',
                    message:
                        'Metinlerde ve sorularda bir kelimeye dokunup "Kaydet" de ya da basılı tutup kalıp/cümle seç.',
                  ),
                ),
              for (final s in items)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  onTap: () => _edit(context, s),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _kindColor(s.kind),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (s.meaning.isNotEmpty)
                              Text(s.meaning,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Row(children: [
                              Pill(s.kindLabel, color: _kindColor(s.kind)),
                              const SizedBox(width: 6),
                              if (s.kind != 'question')
                                Pill(
                                    s.card.isDue
                                        ? 'bugün tekrar'
                                        : 'sonraki: ${_fmt(s.card.due)}',
                                    icon: Icons.schedule_rounded),
                            ]),
                          ],
                        ),
                      ),
                      if (s.kind != 'question')
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded),
                          onPressed: () => TtsService.instance.say(s.text),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _kindColor(String k) {
    switch (k) {
      case 'phrase':
        return const Color(0xFF3577C9);
      case 'sentence':
        return const Color(0xFF7A55C7);
      case 'question':
        return AppColors.coral;
      default:
        return AppColors.primary;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  Future<void> _edit(BuildContext context, SavedItem s) async {
    final ctl = TextEditingController(text: s.meaning);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.kindLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.text, style: Theme.of(ctx).textTheme.titleMedium),
              if (s.context.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s.context,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.kind == 'question' ? 'Doğru cevap / not' : 'Anlam / not',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, '__delete'),
            child: const Text('Sil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (r == null) return;
    if (r == '__delete') {
      appStore.removeSaved(s);
    } else {
      appStore.updateSavedMeaning(s, r);
    }
  }
}

/// Aralıklı tekrar kartları.
class FlashcardPage extends StatefulWidget {
  final List<SavedItem> cards;
  const FlashcardPage({super.key, required this.cards});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  late final List<SavedItem> queue = List.of(widget.cards)..shuffle();
  int done = 0;
  bool revealed = false;
  bool reverse = false; // Türkçeden İngilizceye

  void _grade(int g) {
    final c = queue.removeAt(0);
    appStore.reviewSaved(c, g);
    if (g < 3) {
      // yanlış: oturum sonunda tekrar göster
      queue.add(c);
    } else {
      done++;
    }
    setState(() => revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kartlar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$done kart tamamlandı.',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final c = queue.first;
    final front = reverse && c.meaning.isNotEmpty ? c.meaning : c.text;
    final back = reverse && c.meaning.isNotEmpty ? c.text : c.meaning;
    return Scaffold(
      appBar: AppBar(
        title: Text('Kartlar · kalan ${queue.length}'),
        actions: [
          IconButton(
            tooltip: 'Yönü değiştir',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              reverse = !reverse;
              revealed = false;
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => revealed = true),
                  child: AppCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.kindLabel, style: theme.textTheme.labelMedium),
                          const SizedBox(height: 12),
                          Text(front,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall),
                          if (!reverse || c.meaning.isEmpty)
                            IconButton(
                              icon: const Icon(Icons.volume_up_outlined),
                              onPressed: () => TtsService.instance.say(c.text),
                            ),
                          const SizedBox(height: 24),
                          if (revealed) ...[
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(back.isEmpty ? '(anlam yazılmamış)' : back,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge),
                            if (c.context.isNotEmpty && c.context != c.text) ...[
                              const SizedBox(height: 16),
                              Text(c.context,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontStyle: FontStyle.italic)),
                            ],
                          ] else
                            Text('Cevabı görmek için dokun',
                                style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (revealed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => _grade(0),
                          child: const Text('Bilemedim')),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => _grade(3), child: const Text('Zor')),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton.tonal(
                          onPressed: () => _grade(4), child: const Text('İyi')),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton(
                          onPressed: () => _grade(5),
                          child: const Text('Kolay')),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: () => setState(() => revealed = true),
                  child: const Text('Göster'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
