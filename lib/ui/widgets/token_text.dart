import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_store.dart';
import '../../core/models.dart';
import '../../services/tts_service.dart';

/// Bir metindeki tek bir kelime (token).
class Tok {
  final int sentence;
  final String text; // görünen hâli (noktalamayla)
  Tok(this.sentence, this.text);
}

List<Tok> tokenize(List<String> sentences) {
  final out = <Tok>[];
  for (var s = 0; s < sentences.length; s++) {
    for (final w in sentences[s].split(RegExp(r'\s+'))) {
      if (w.isNotEmpty) out.add(Tok(s, w));
    }
  }
  return out;
}

/// Dokunulabilir metin:
///  - kelimeye dokun → anlam kartı
///  - basılı tut → seçim başlar; başka kelimeye dokunarak seçimi genişlet → Kaydet
class TokenText extends StatefulWidget {
  final List<String> sentences;
  final List<String> speakers; // diyalog için; boş olabilir
  final TextItem? text; // sözlükçe ve kaynak için
  final int highlightSentence;
  final TextStyle? style;
  final void Function(int sentence)? onSentenceTap;
  final VoidCallback? onLookup; // sınavda kelimeye bakmak ipucu sayılabilir

  const TokenText({
    super.key,
    required this.sentences,
    this.speakers = const [],
    this.text,
    this.highlightSentence = -1,
    this.style,
    this.onSentenceTap,
    this.onLookup,
  });

  @override
  State<TokenText> createState() => _TokenTextState();
}

class _TokenTextState extends State<TokenText> {
  late List<Tok> toks;
  int? selA;
  int? selB;
  OverlayEntry? _selBar;

  @override
  void initState() {
    super.initState();
    toks = tokenize(widget.sentences);
  }

  @override
  void didUpdateWidget(covariant TokenText old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.sentences, widget.sentences)) {
      toks = tokenize(widget.sentences);
      selA = selB = null;
      _hideBar();
    }
  }

  bool get selecting => selA != null;

  int get _lo => selA! < selB! ? selA! : selB!;
  int get _hi => selA! < selB! ? selB! : selA!;

  String _selectedText() =>
      toks.sublist(_lo, _hi + 1).map((t) => t.text).join(' ');

  void _tap(int i) {
    if (selecting) {
      setState(() => selB = i);
      HapticFeedback.selectionClick();
      _selBar?.markNeedsBuild();
      return;
    }
    widget.onLookup?.call();
    _showMeaning(i);
  }

  void _longPress(int i) {
    HapticFeedback.mediumImpact();
    setState(() {
      selA = i;
      selB = i;
    });
    _showBar();
  }

  void _selectSentence() {
    if (!selecting) return;
    final s = toks[selA!].sentence;
    final first = toks.indexWhere((t) => t.sentence == s);
    final last = toks.lastIndexWhere((t) => t.sentence == s);
    setState(() {
      selA = first;
      selB = last;
    });
    _selBar?.markNeedsBuild();
  }

  void _cancelSelection() {
    setState(() => selA = selB = null);
    _hideBar();
  }

  void _showBar() {
    _hideBar();
    final overlay = Overlay.of(context);
    _selBar = OverlayEntry(builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      return Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: SafeArea(
          top: false,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(18),
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields_rounded,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('"${_selectedText()}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Başka kelimelere dokunarak seçimi genişlet.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveSelection,
                          icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                          label: const Text('Kaydet'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _selectSentence,
                        child: const Text('Cümle'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'İptal',
                        onPressed: _cancelSelection,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(_selBar!);
  }

  void _hideBar() {
    _selBar?.remove();
    _selBar = null;
  }

  @override
  void dispose() {
    _hideBar();
    super.dispose();
  }

    /// Dokunulan kelimeyi içeren 2–3 kelimelik kalıpları önce dener.
  ({String phrase, String? meaning}) _phraseAt(int i) {
    final store = appStore;
    final s = toks[i].sentence;
    for (final len in [4, 3, 2]) {
      for (var start = i - len + 1; start <= i; start++) {
        if (start < 0 || start + len > toks.length) continue;
        final part = toks.sublist(start, start + len);
        if (part.any((t) => t.sentence != s)) continue;
        final phrase = part.map((t) => cleanWord(t.text)).join(' ');
        final g = widget.text?.glossary[phrase];
        final m = g ?? store.content.dictionary[phrase];
        if (m != null) {
          return (phrase: part.map((t) => _strip(t.text)).join(' '), meaning: m);
        }
      }
    }
    final w = _strip(toks[i].text);
    return (phrase: w, meaning: store.lookup(w, text: widget.text));
  }

  String _strip(String t) =>
      t.replaceAll(RegExp(r'''^[^\p{L}']+|[^\p{L}']+$''', unicode: true), '');

  String _sentenceOf(int i) => widget.sentences[toks[i].sentence];

  Future<void> _showMeaning(int i) async {
    final r = _phraseAt(i);
    final word = _strip(toks[i].text);
    final multi = r.phrase.toLowerCase() != word.toLowerCase();
    final req = await showModalBottomSheet<SaveRequest>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => WordSheet(
        phrase: r.phrase,
        meaning: r.meaning,
        altWord: multi ? word : null,
        altMeaning: multi ? appStore.lookup(word, text: widget.text) : null,
        sentence: _sentenceOf(i),
      ),
    );
    if (req == null || !mounted) return;
    final saved = await showSaveDialog(context,
        text: req.text,
        kind: req.kind,
        meaning: req.meaning,
        contextSentence: _sentenceOf(i),
        sourceId: widget.text?.id);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    }
  }

  Future<void> _saveSelection() async {
    final txt = _selectedText();
    final n = _hi - _lo + 1;
    final sentence = _sentenceOf(_lo);
    final isWholeSentence = toks[_lo].sentence == toks[_hi].sentence &&
        n == tokenize([sentence]).length;
    final spansSentences = toks[_lo].sentence != toks[_hi].sentence;
    final kind = (isWholeSentence || spansSentences)
        ? 'sentence'
        : (n == 1 ? 'word' : 'phrase');
    final clean = kind == 'sentence' ? txt : _strip(txt);
    final meaning =
        kind == 'sentence' ? '' : (appStore.lookupPhrase(clean, text: widget.text) ?? '');
    final saved = await showSaveDialog(context,
        text: clean,
        kind: kind,
        meaning: meaning,
        contextSentence: sentence,
        sourceId: widget.text?.id);
    if (!mounted) return;
    setState(() => selA = selB = null);
    _hideBar();
    if (saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = widget.style ??
        theme.textTheme.bodyLarge!.copyWith(height: 1.5, fontSize: 17);
    final hl = theme.colorScheme.tertiaryContainer;
    final selColor = theme.colorScheme.primaryContainer;

    final children = <Widget>[];
    var lastSentence = -1;
    final isDialog = widget.speakers.isNotEmpty;

    List<Widget> run = [];
    void flushRun() {
      if (run.isEmpty) return;
      children.add(Wrap(spacing: 0, runSpacing: 2, children: run));
      run = [];
    }

    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      if (isDialog && t.sentence != lastSentence) {
        flushRun();
        final sp = t.sentence < widget.speakers.length
            ? widget.speakers[t.sentence]
            : '';
        children.add(Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10, bottom: 2),
          child: GestureDetector(
            onTap: widget.onSentenceTap == null
                ? null
                : () => widget.onSentenceTap!(t.sentence),
            child: Text(sp,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
        ));
      }
      lastSentence = t.sentence;
      final selected = selecting && i >= _lo && i <= _hi;
      final current = t.sentence == widget.highlightSentence;
      run.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        onLongPress: () => _longPress(i),
        onDoubleTap: widget.onSentenceTap == null
            ? null
            : () => widget.onSentenceTap!(t.sentence),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
          decoration: BoxDecoration(
            color: selected ? selColor : (current ? hl : null),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(t.text, style: base),
        ),
      ));
    }
    flushRun();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class SaveRequest {
  final String text;
  final String kind;
  final String meaning;
  const SaveRequest(this.text, this.kind, this.meaning);
}

/// Kelimeye dokununca açılan anlam kartı. Kaydet'e basılırsa SaveRequest döner.
class WordSheet extends StatelessWidget {
  final String phrase;
  final String? meaning;
  final String? altWord;
  final String? altMeaning;
  final String sentence;

  const WordSheet({
    super.key,
    required this.phrase,
    required this.meaning,
    this.altWord,
    this.altMeaning,
    required this.sentence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(phrase, style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Dinle',
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () => TtsService.instance.say(phrase),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meaning ??
                  'Sözlükte bulunamadı. Kaydedip anlamını kendin yazabilirsin.',
              style: meaning == null
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)
                  : theme.textTheme.titleMedium,
            ),
            if (altWord != null) ...[
              const SizedBox(height: 10),
              Text('Tek kelime: $altWord — ${altMeaning ?? '?'}',
                  style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Text(sentence,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(phrase.contains(' ')
                      ? 'Kalıbı kaydet'
                      : 'Kelimeyi kaydet'),
                  onPressed: () => Navigator.pop(
                      context,
                      SaveRequest(phrase, phrase.contains(' ') ? 'phrase' : 'word',
                          meaning ?? '')),
                ),
                if (altWord != null)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context,
                        SaveRequest(altWord!, 'word', altMeaning ?? '')),
                    child: Text('"$altWord" kaydet'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kaydetmeden önce anlamı düzenlemeye izin veren diyalog.
Future<bool> showSaveDialog(
  BuildContext context, {
  required String text,
  required String kind,
  required String meaning,
  required String contextSentence,
  String? sourceId,
}) async {
  final meaningCtl = TextEditingController(text: meaning);
  var k = kind;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Kaydet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'word', label: Text('Kelime')),
                  ButtonSegment(value: 'phrase', label: Text('Kalıp')),
                  ButtonSegment(value: 'sentence', label: Text('Cümle')),
                ],
                selected: {k},
                onSelectionChanged: (v) => setSt(() => k = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: meaningCtl,
                decoration: const InputDecoration(
                  labelText: 'Anlamı / notun (Türkçe)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  if (ok == true) {
    appStore.saveItem(
      text: text,
      kind: k,
      meaning: meaningCtl.text.trim(),
      context: contextSentence,
      sourceId: sourceId,
    );
    return true;
  }
  return false;
}
