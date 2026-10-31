#!/usr/bin/env python3
"""İçerik derleyici.

content/ klasöründeki referans notlarını, soru dosyalarını (questions_*.txt)
ve metin dosyalarını (texts_*.txt) okuyup doğrular ve
assets/content/content.json dosyasını üretir.

Kullanım:  python tool/build_content.py

SORU FORMATI (questions_*.txt)
  @A2.28 [A2.05 ...]            -> sonraki soruların konuları (ilki ana konu)
  M | soru | şık1 / şık2* / şık3 | ipucu1 | ipucu2 | açıklama
  T | ifade | D veya Y | ipucu1 | ipucu2 | açıklama
  S | soru (___ boşluklu) | cevap1 / cevap2 | ipucu1 | ipucu2 | açıklama
  W | yazma görevi | min kelime | örnek cevap | ipucu1 | ipucu2 | açıklama
  # ile başlayan satırlar yorumdur.

METİN FORMATI (texts_*.txt)
  #TEXT id | seviye | story/dialog | short/medium/long | başlık | konu1 konu2
  > Cümle.                (hikaye)
  > Ali: Cümle.           (diyalog)
  %G
  kelime = anlam
  %Q
  (soru satırları; isteğe bağlı son alan r3 = 3. cümleyi tekrar çal)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / 'content'
OUT = ROOT / 'assets' / 'content' / 'content.json'

errors = []
warnings = []


def err(msg):
    errors.append(msg)


# ---------------------------------------------------------------- konular

def split_sections(md, level_prefix, start_header=None, stop_headers=()):
    """'## N. Başlık' bölümlerini (numara, başlık, gövde, grup) olarak döndürür."""
    group = 'Gramer'
    out = []
    cur = None
    for line in md.splitlines():
        if line.startswith('# ') and not line.startswith('## '):
            h = line[2:].strip().upper()
            if 'KONUŞMA' in h:
                group = 'Konuşma'
            elif 'KELİME' in h:
                group = None
            elif 'GRAMER' in h:
                group = 'Gramer'
            if cur:
                out.append(cur)
                cur = None
            continue
        m = re.match(r'^## (\d+)\.\s*(.+)$', line)
        if m and group:
            if cur:
                out.append(cur)
            cur = {'num': int(m.group(1)), 'title': m.group(2).strip(),
                   'body': [], 'group': group}
            continue
        if line.startswith('## ') and cur:
            out.append(cur)
            cur = None
            continue
        if cur is not None:
            cur['body'].append(line)
    if cur:
        out.append(cur)
    topics = []
    for s in out:
        body = '\n'.join(s['body']).strip()
        body = re.sub(r'\n-{3,}\s*$', '', body).strip()
        topics.append({
            'id': f"{level_prefix}.{s['num']:02d}",
            'level': level_prefix,
            'group': s['group'],
            'title': s['title'],
            'notes': body,
        })
    return topics


def parse_table_rows(md_block):
    rows = []
    for line in md_block.splitlines():
        line = line.strip()
        if not line.startswith('|') or set(line.replace('|', '').strip()) <= set('-: '):
            continue
        cells = [c.strip() for c in line.strip('|').split('|')]
        rows.append(cells)
    return rows


def load_topics():
    topics = []
    a1 = (CONTENT / 'ref' / 'A1_ANA_REFERANS.md').read_text(encoding='utf-8')
    topics += split_sections(a1, 'A1')
    a2 = (CONTENT / 'ref' / 'A2_ANA_REFERANS.md').read_text(encoding='utf-8')
    topics += split_sections(a2, 'A2')

    # Eksik konular + yazılmış notları
    extra = {}
    notes_file = CONTENT / 'extra_notes.md'
    if notes_file.exists():
        cur = None
        for line in notes_file.read_text(encoding='utf-8').splitlines():
            m = re.match(r'^## ((?:A1|A2|B1)\.[A-Z]?\d+)\s*(.*)$', line)
            if m:
                cur = m.group(1)
                extra[cur] = {'title': m.group(2).strip(), 'body': []}
                continue
            if cur:
                extra[cur]['body'].append(line)

    eksik = (CONTENT / 'ref' / 'EKSIK_KONULAR_A1_A2.md').read_text(encoding='utf-8')
    for cells in parse_table_rows(eksik):
        if not re.match(r'^(A1|A2)\.G\d+$', cells[0]):
            continue
        tid, title = cells[0], cells[1]
        e = extra.get(tid)
        notes = '\n'.join(e['body']).strip() if e else ''
        if not notes:
            notes = f'Bu konu henüz çalışılmadı.\n\n{cells[3] if len(cells) > 3 else ""}'.strip()
        topics.append({'id': tid, 'level': tid[:2], 'group': 'Eksik',
                       'title': (e['title'] if e and e['title'] else title),
                       'notes': notes})

    b1 = (CONTENT / 'ref' / 'B1_MUFREDAT.md').read_text(encoding='utf-8')
    section = 'B1'
    for line in b1.splitlines():
        m = re.match(r'^## \d+\.\s*(.+)$', line)
        if m:
            section = m.group(1).strip().title()
        if not line.startswith('| B1.G'):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        tid, title, ex = cells[0], cells[1], cells[2]
        e = extra.get(tid)
        notes = '\n'.join(e['body']).strip() if e else ''
        if not notes:
            notes = f'**Yapı / örnek:** {ex}' if ex else ''
        topics.append({'id': tid, 'level': 'B1', 'group': 'B1 · ' + section,
                       'title': re.sub(r'\s*—\s*B1\+', ' (B1+)', title),
                       'notes': notes})
    # extra_notes içinde tabloda olmayan özel konular (ör. A1.R okuma)
    known = {t['id'] for t in topics}
    for tid, e in extra.items():
        if tid not in known:
            topics.append({'id': tid, 'level': tid[:2], 'group': 'Ek',
                           'title': e['title'], 'notes': '\n'.join(e['body']).strip()})
    return topics


def load_vocab():
    a2 = (CONTENT / 'ref' / 'A2_ANA_REFERANS.md').read_text(encoding='utf-8')
    idx = a2.find('# KELİME')
    vocab = []
    seen = set()

    def add(en, tr, level):
        en = re.sub(r'\*\*', '', en).strip()
        tr = re.sub(r'\*\*', '', tr).strip()
        if not en or not tr or en.lower() in ('i̇ngilizce', 'ingilizce', 'kelime'):
            return
        key = en.lower()
        if key in seen:
            return
        seen.add(key)
        vocab.append({'en': en, 'tr': tr, 'level': level})

    for cells in parse_table_rows(a2[idx:]):
        if len(cells) >= 2:
            add(cells[0], cells[1], 'A2')
    # Pets kelime tablosu
    m = re.search(r'### Kelimeler\n(.*?)\n\n', a2, re.S)
    if m:
        for cells in parse_table_rows(m.group(1)):
            if len(cells) >= 2:
                add(cells[0], cells[1], 'A2')
    extra = CONTENT / 'vocab_extra.tsv'
    if extra.exists():
        for line in extra.read_text(encoding='utf-8').splitlines():
            if not line.strip() or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) >= 3:
                add(parts[1], parts[2], parts[0])
    return vocab


def load_common():
    d = {}
    f = CONTENT / 'common_words.tsv'
    if f.exists():
        for line in f.read_text(encoding='utf-8').splitlines():
            if not line.strip() or line.startswith('#'):
                continue
            k, _, v = line.partition('\t')
            if v:
                d[k.strip().lower()] = v.strip()
    return d


# ---------------------------------------------------------------- sorular

def parse_question(line, qid, level, topics, where, text_id=None):
    parts = [p.strip() for p in line.split('|')]
    kind = parts[0].upper()
    q = {'id': qid, 'level': level, 'topics': topics}
    if text_id:
        q['text'] = text_id
    replay = None
    if parts and re.match(r'^r\d+$', parts[-1]):
        replay = int(parts[-1][1:]) - 1
        parts = parts[:-1]
    if kind == 'W':
        if len(parts) < 4:
            err(f'{where}: W için en az 4 alan gerekli')
            return None
        q.update({'type': 'write', 'prompt': parts[1],
                  'minWords': int(parts[2]) if parts[2].isdigit() else 30,
                  'model': parts[3]})
        hints = [h for h in parts[4:6] if h]
        q['hints'] = hints
        q['explain'] = parts[6] if len(parts) > 6 else ''
        return q
    if len(parts) < 3:
        err(f'{where}: en az 3 alan gerekli -> {line[:60]}')
        return None
    prompt, ans = parts[1], parts[2]
    hints = [h for h in parts[3:5] if h]
    explain = parts[5] if len(parts) > 5 else ''
    q.update({'prompt': prompt, 'hints': hints, 'explain': explain})
    if replay is not None:
        q['replay'] = replay
    if kind == 'M':
        opts = [o.strip() for o in ans.split(' / ')]
        correct = [i for i, o in enumerate(opts) if o.endswith('*')]
        if len(correct) != 1:
            err(f'{where}: tam bir doğru şık (*) olmalı -> {ans}')
            return None
        opts = [o.rstrip('*').strip() for o in opts]
        if len(opts) < 2 or len(set(o.lower() for o in opts)) != len(opts):
            err(f'{where}: şıklar eksik ya da tekrarlı -> {ans}')
            return None
        q.update({'type': 'mcq', 'options': opts, 'answer': correct[0]})
    elif kind == 'T':
        a = ans.strip().upper()
        if a not in ('D', 'Y', 'T', 'F'):
            err(f'{where}: T cevabı D ya da Y olmalı -> {ans}')
            return None
        q.update({'type': 'tf', 'options': ['Doğru', 'Yanlış'],
                  'answer': 0 if a in ('D', 'T') else 1})
    elif kind == 'S':
        acc = [a.strip() for a in ans.split(' / ') if a.strip()]
        if not acc:
            err(f'{where}: S cevabı boş')
            return None
        q.update({'type': 'short', 'accepted': acc})
    else:
        err(f'{where}: bilinmeyen tür {kind}')
        return None
    return q


def load_questions(topic_ids):
    qs = []
    counters = {}
    for f in sorted(CONTENT.glob('questions_*.txt')):
        topics = None
        for n, raw in enumerate(f.read_text(encoding='utf-8').splitlines(), 1):
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            where = f'{f.name}:{n}'
            if line.startswith('@'):
                topics = line[1:].split()
                for t in topics:
                    if t not in topic_ids:
                        err(f'{where}: bilinmeyen konu {t}')
                continue
            if topics is None:
                err(f'{where}: konu satırı (@...) yok')
                continue
            main = topics[0]
            counters[main] = counters.get(main, 0) + 1
            qid = f'{main}-{counters[main]:02d}'
            q = parse_question(line, qid, main[:2], list(topics), where)
            if q:
                qs.append(q)
    return qs


# ---------------------------------------------------------------- metinler

def load_texts(topic_ids):
    texts = []
    for f in sorted(CONTENT.glob('texts_*.txt')):
        cur = None
        mode = None
        for n, raw in enumerate(f.read_text(encoding='utf-8').splitlines(), 1):
            line = raw.strip()
            where = f'{f.name}:{n}'
            if not line or (line.startswith('#') and not line.startswith('#TEXT')):
                continue
            if line.startswith('#TEXT'):
                parts = [p.strip() for p in line[5:].split('|')]
                if len(parts) < 6:
                    err(f'{where}: #TEXT alanları eksik')
                    continue
                tid, level, kind, length, title, tps = parts[:6]
                tps = tps.split()
                for t in tps:
                    if t not in topic_ids:
                        err(f'{where}: bilinmeyen konu {t}')
                cur = {'id': tid, 'level': level, 'kind': kind, 'length': length,
                       'title': title, 'topics': tps, 'sentences': [],
                       'glossary': {}, 'questions': []}
                texts.append(cur)
                mode = 'body'
                continue
            if cur is None:
                continue
            if line == '%G':
                mode = 'gloss'
                continue
            if line == '%Q':
                mode = 'q'
                continue
            if mode == 'body' and line.startswith('>'):
                s = line[1:].strip()
                m = re.match(r'^([A-Z][a-zA-Z]+):\s+(.+)$', s)
                if cur['kind'] == 'dialog' and m:
                    cur['sentences'].append({'s': m.group(1), 't': m.group(2)})
                else:
                    cur['sentences'].append({'s': '', 't': s})
            elif mode == 'gloss':
                k, _, v = line.partition('=')
                if v.strip():
                    cur['glossary'][k.strip().lower()] = v.strip()
            elif mode == 'q':
                i = len(cur['questions']) + 1
                q = parse_question(line, f"{cur['id']}-q{i:02d}", cur['level'],
                                   list(cur['topics']), where, cur['id'])
                if q:
                    if 'replay' in q and not (0 <= q['replay'] < len(cur['sentences'])):
                        err(f'{where}: replay cümle numarası metinde yok')
                    cur['questions'].append(q)
    return texts


WORD_RE = re.compile(r"[^\W\d_][^\W\d_']*(?:'[^\W\d_]+)?")


def stem_candidates(w):
    out = []
    def add(s):
        if len(s) >= 2 and s not in out:
            out.append(s)
    if w.endswith("'s"): add(w[:-2])
    if w.endswith('ies'): add(w[:-3] + 'y')
    if w.endswith('es'): add(w[:-2])
    if w.endswith('s'): add(w[:-1])
    if w.endswith('ied'): add(w[:-3] + 'y')
    if w.endswith('ed'):
        add(w[:-2]); add(w[:-1])
        b = w[:-2]
        if len(b) > 2 and b[-1] == b[-2]: add(b[:-1])
    if w.endswith('ing'):
        b = w[:-3]
        add(b); add(b + 'e')
        if len(b) > 2 and b[-1] == b[-2]: add(b[:-1])
    if w.endswith('er'): add(w[:-2])
    if w.endswith('est'): add(w[:-3])
    if w.endswith('ly'): add(w[:-2])
    return out


def check_glossary(texts, dictionary):
    for t in texts:
        missing = []
        for s in t['sentences']:
            for w in WORD_RE.findall(s['t']):
                lw = w.lower().replace('’', "'")
                if lw in t['glossary'] or lw in dictionary:
                    continue
                if any(c in t['glossary'] or c in dictionary for c in stem_candidates(lw)):
                    continue
                if w[0].isupper() and lw not in dictionary and s['t'].find(w) > 0:
                    continue  # özel isim
                if w[0].isupper():
                    # cümle başı: büyük harf; yine de kontrol et
                    pass
                missing.append(lw)
        missing = sorted(set(missing))
        if missing:
            warnings.append(f"{t['id']}: sözlükte yok -> {', '.join(missing)}")


def main():
    topics = load_topics()
    ids = [t['id'] for t in topics]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        err(f'tekrarlı konu kimliği: {dup}')
    topic_ids = set(ids)
    vocab = load_vocab()
    common = load_common()
    questions = load_questions(topic_ids)
    texts = load_texts(topic_ids)

    dictionary = dict(common)
    for v in vocab:
        for e in v['en'].split('/'):
            e = re.sub(r'\(.*?\)', '', e).strip().lower()
            if e:
                dictionary.setdefault(e, v['tr'])
    check_glossary(texts, dictionary)

    qids = [q['id'] for q in questions] + [q['id'] for t in texts for q in t['questions']]
    if len(qids) != len(set(qids)):
        err('tekrarlı soru kimliği')
    tids = [t['id'] for t in texts]
    if len(tids) != len(set(tids)):
        err('tekrarlı metin kimliği')

    data = {'version': 1, 'topics': topics, 'questions': questions,
            'texts': texts, 'vocab': vocab, 'common': common}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                   encoding='utf-8')

    per_level = {}
    for q in questions:
        per_level[q['level']] = per_level.get(q['level'], 0) + 1
    covered = {t for q in questions for t in q['topics']}
    uncovered = [t['id'] for t in topics if t['id'] not in covered]
    print(f'Konu: {len(topics)}  Soru: {len(questions)} {per_level}  '
          f'Metin: {len(texts)} (soru: {sum(len(t["questions"]) for t in texts)})  '
          f'Kelime: {len(vocab)}  Ortak sözlük: {len(common)}')
    print(f'Sorusu olmayan konu ({len(uncovered)}): {" ".join(uncovered)}')
    for w in warnings:
        print('UYARI', w)
    for e in errors:
        print('HATA', e)
    print(f'-> {OUT}  ({OUT.stat().st_size // 1024} KB)')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
