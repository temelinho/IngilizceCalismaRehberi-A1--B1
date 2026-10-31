import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../core/user_state.dart';
import '../services/tts_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController keyCtl;
  late final TextEditingController modelCtl;
  bool hideKey = true;

  Settings get s => appStore.state.settings;

  @override
  void initState() {
    super.initState();
    keyCtl = TextEditingController(text: s.apiKey);
    modelCtl = TextEditingController(text: s.model);
  }

  @override
  void dispose() {
    keyCtl.dispose();
    modelCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Dinleme', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Konuşma hızı: ${s.speed.toStringAsFixed(2)}x'),
            Slider(
              min: 0.5,
              max: 1.5,
              divisions: 20,
              value: s.speed.clamp(0.5, 1.5).toDouble(),
              label: '${s.speed.toStringAsFixed(2)}x',
              onChanged: (v) {
                appStore.updateSettings((x) => x.speed = v);
                TtsService.instance.setSpeed(v);
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Hızı dene'),
                onPressed: () => TtsService.instance
                    .say('This is how fast the stories will be read.'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Transkript (metin) varsayılanı'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'on', label: Text('Açık')),
                ButtonSegment(value: 'after', label: Text('Dinledikten sonra')),
                ButtonSegment(value: 'off', label: Text('Kapalı')),
              ],
              selected: {s.transcriptMode},
              onSelectionChanged: (v) =>
                  appStore.updateSettings((x) => x.transcriptMode = v.first),
            ),
            const Divider(height: 32),
            Text('Günlük tekrar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Günlük soru sayısı: ${s.dailyQuestions}'),
            Slider(
              min: 5,
              max: 40,
              divisions: 7,
              value: s.dailyQuestions.toDouble().clamp(5, 40).toDouble(),
              label: '${s.dailyQuestions}',
              onChanged: (v) =>
                  appStore.updateSettings((x) => x.dailyQuestions = v.round()),
            ),
            const Divider(height: 32),
            Text('Yazma değerlendirmesi (isteğe bağlı)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Uzun yazma sorularını yapay zekâ ile puanlamak için Google AI Studio\'dan '
              'alacağın Gemini API anahtarını gir. Anahtar sadece bu telefonda saklanır. '
              'Boş bırakırsan örnek cevapla kendin karşılaştırırsın.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtl,
              obscureText: hideKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Gemini API anahtarı',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(hideKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hideKey = !hideKey),
                ),
              ),
              onChanged: (v) => appStore.updateSettings((x) => x.apiKey = v.trim()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelCtl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Model adı',
                helperText: 'Varsayılan: gemini-2.5-flash',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => appStore.updateSettings((x) => x.model = v.trim()),
            ),
            const Divider(height: 32),
            Text('Veri', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${appStore.state.qstats.length} soru çözüldü · '
              '${appStore.state.mistakes.length} hata kaydı · '
              '${appStore.state.saved.length} kayıt',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Yedeği panoya kopyala'),
                  onPressed: () async {
                    final data = Map<String, dynamic>.from(appStore.state.toJson());
                    // anahtar yedeğe girmesin
                    (data['settings'] as Map)['key'] = '';
                    await Clipboard.setData(
                        ClipboardData(text: jsonEncode(data)));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Yedek panoya kopyalandı. Bir yere yapıştırıp sakla.')));
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.paste),
                  label: const Text('Panodan geri yükle'),
                  onPressed: () => _restore(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'İçerik: ${appStore.content.topics.length} konu · '
              '${appStore.content.questions.length} soru · '
              '${appStore.content.texts.length} metin',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geri yükle'),
        content: const Text(
            'Panodaki yedek mevcut ilerlemenin yerine geçecek. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Geri yükle')),
        ],
      ),
    );
    if (ok != true) return;
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      final j = jsonDecode(clip?.text ?? '') as Map<String, dynamic>;
      final restored = UserState.fromJson(j);
      final key = appStore.state.settings.apiKey;
      appStore.replaceState(restored..settings.apiKey = key);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geri yüklendi')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Panodaki metin geçerli bir yedek değil.')));
    }
  }
}
