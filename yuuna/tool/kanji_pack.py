"""Builds the kanji pack the app downloads for its kanji sheet.

    python tool/kanji_pack.py SOURCES OUT_DIR

SOURCES holds the downloaded originals (names as published):
  kanjidic2-all-<version>.json.zip   github.com/scriptin/jmdict-simplified (KANJIDIC2, CC BY-SA 4.0)
  kanjivg-<date>.xml.gz              github.com/KanjiVG/kanjivg (CC BY-SA 3.0)
  JMdict_e.gz                        www.edrdg.org (JMdict, CC BY-SA 4.0)
  aozora_characters.csv              github.com/scriptin/kanji-frequency (CC BY 4.0)
  kanji.json                         github.com/davidluzgouveia/kanji-data (MIT; JLPT levels from Tanos)

Writes OUT_DIR/kanji-pack-<FORMAT>.bin.gz and prints its size and SHA-256 for
lib/src/kanji/kanji_pack.dart. The pack, once unzipped:
  b'JDJK', u32 format, u32 count, u32 meta length, meta JSON,
  count x (u32 code point, u32 offset, u32 length) sorted by code point,
  then each kanji's record as UTF-8 JSON (offsets count from the records' start).
Everything little-endian. A record's keys are listed in KanjiInfo.fromJson.
"""
import glob, gzip, hashlib, json, os, re, struct, sys, unicodedata, zipfile
import xml.etree.ElementTree as ET
from datetime import date

FORMAT = 1
KVG = '{http://kanjivg.tagaini.net}'
COMMON = {'news1', 'ichi1', 'spec1', 'spec2', 'gai1'}
WORDS, USED_IN = 40, 60


def one(sources, pattern):
    found = sorted(glob.glob(os.path.join(sources, pattern)))
    if not found:
        sys.exit(f'missing {pattern} in {sources}')
    return found[-1]


def kanjidic(path):
    with zipfile.ZipFile(path) as z:
        data = json.loads(z.read(z.namelist()[0]))
    out = {}
    for c in data['characters']:
        rm = c.get('readingMeaning') or {}
        readings = [r for g in rm.get('groups', []) for r in g['readings']]
        meanings = [m['value'] for g in rm.get('groups', []) for m in g['meanings'] if m['lang'] == 'en']
        misc = c['misc']
        classical = next((r['value'] for r in c['radicals'] if r['type'] == 'classical'), None)
        out[c['literal']] = {
            's': (misc.get('strokeCounts') or [None])[0],
            'g': misc.get('grade'),
            'f': misc.get('frequency'),
            'on': [r['value'] for r in readings if r['type'] == 'ja_on'],
            'kun': [r['value'] for r in readings if r['type'] == 'ja_kun'],
            'hv': [r['value'] for r in readings if r['type'] == 'vietnam'],
            'm': meanings,
            'v': [chr(int(v['value'], 16)) for v in misc.get('variants', []) if v['type'] == 'ucs'],
            'rad': unicodedata.normalize('NFKC', chr(0x2F00 + classical - 1)) if classical else None,
        }
    return data.get('dictDate', ''), out


def kanjivg(path):
    """Stroke paths in order, the parts tree and the radical, per character."""
    root = ET.fromstring(gzip.open(path).read())
    out = {}
    for kanji in root.iter('kanji'):
        if '-' in kanji.get('id', ''):
            continue
        top = kanji.find('g')
        char = top.get(KVG + 'element') if top is not None else None
        if not char or len(char) != 1:
            continue
        strokes = []
        for p in kanji.iter('path'):
            m = re.search(r'-s(\d+)$', p.get('id', ''))
            strokes.append((int(m.group(1)) if m else len(strokes) + 1, p.get('d')))
        strokes.sort()
        radical = [None]

        def parts(g):
            nodes = []
            for child in g.findall('g'):
                element = child.get(KVG + 'element')
                if element and child.get(KVG + 'radical') in ('general', 'tradit') and radical[0] is None:
                    radical[0] = element
                if element and child.get(KVG + 'part') not in (None, '1'):
                    continue
                if element and len(element) == 1:
                    nodes.append([element, parts(child)])
                else:
                    nodes.extend(parts(child))
            return nodes

        out[char] = {'d': [d for _, d in strokes], 'p': parts(top), 'r': radical[0]}
    return out


def jlpt(path):
    with open(path, encoding='utf-8') as f:
        return {k: v['jlpt_new'] for k, v in json.load(f).items() if v.get('jlpt_new')}


def aozora(path):
    ranks = {}
    with open(path, encoding='utf-8') as f:
        next(f)
        for line in f:
            rank, _, char, _ = line.rstrip('\n').split(',', 3)
            if rank != '0':
                ranks[char] = int(rank)
    return ranks


def jmdict(path):
    """Common words per kanji: [rank, word, reading, gloss], most frequent first."""
    words = {}
    for _, entry in ET.iterparse(gzip.open(path), events=('end',)):
        if entry.tag != 'entry':
            continue
        readings = [(r.findtext('reb'), [x.text for x in r.findall('re_restr')], r.find('re_nokanji') is not None,
                     bool(r.findall('re_pri'))) for r in entry.findall('r_ele')]
        senses = entry.findall('sense')
        for k in entry.findall('k_ele'):
            word = k.findtext('keb')
            pri = {p.text for p in k.findall('ke_pri')}
            if not pri & COMMON or any(i.text in ('search-only kanji form', 'sK') for i in k.findall('ke_inf')):
                continue
            nf = [int(p[2:]) for p in pri if p.startswith('nf')]
            rank = min(nf) if nf else 49 if pri & {'news1', 'ichi1', 'spec1'} else 55
            fitting = [r for r in readings if not r[2] and (not r[1] or word in r[1])]
            fitting.sort(key=lambda r: not r[3])
            sense = next((s for s in senses if not s.findall('stagk') or word in [x.text for x in s.findall('stagk')]), None)
            gloss = '; '.join(g.text for g in sense.findall('gloss')[:3] if g.text) if sense is not None else ''
            item = [rank, word, fitting[0][0] if fitting else '', gloss]
            for char in set(word):
                if '㐀' <= char <= '鿿' or '豈' <= char <= '﫿' or ord(char) >= 0x20000:
                    words.setdefault(char, {}).setdefault(word, item)
        entry.clear()
    return {c: sorted(ws.values(), key=lambda w: (w[0], len(w[1]), w[1]))[:WORDS] for c, ws in words.items()}


def main():
    sources, out_dir = sys.argv[1], sys.argv[2]
    dic_path = one(sources, 'kanjidic2-all-*.json.zip')
    kvg_path = one(sources, 'kanjivg-*.xml.gz')
    dict_date, dic = kanjidic(dic_path)
    kvg = kanjivg(kvg_path)
    levels = jlpt(os.path.join(sources, 'kanji.json'))
    ranks = aozora(os.path.join(sources, 'aozora_characters.csv'))
    words = jmdict(os.path.join(sources, 'JMdict_e.gz'))

    def elements(tree):
        for char, children in tree:
            yield char
            yield from elements(children)

    used_in = {}
    for char, data in kvg.items():
        for part in set(elements(data['p'])) - {char}:
            used_in.setdefault(part, []).append(char)
    order = lambda c: (ranks.get(c, 10 ** 6), (dic.get(c) or {}).get('f') or 10 ** 6, c)

    records = {}
    for char in set(dic) | set(kvg):
        if len(char) != 1:
            continue
        d, v = dic.get(char, {}), kvg.get(char, {})
        record = {'k': char, 's': d.get('s') or (len(v['d']) if v else None), 'g': d.get('g'), 'j': levels.get(char),
                  'f': d.get('f'), 'a': ranks.get(char), 'on': d.get('on'), 'kun': d.get('kun'), 'hv': d.get('hv'),
                  'm': d.get('m'), 'v': d.get('v'), 'r': v.get('r') or d.get('rad'), 'p': v.get('p'), 'd': v.get('d'),
                  'w': [w[1:] for w in words.get(char, [])],
                  'u': ''.join(sorted(used_in.get(char, []), key=order)[:USED_IN])}
        records[char] = {k: x for k, x in record.items() if x not in (None, [], '')}

    meta = json.dumps({
        'format': FORMAT, 'built': date.today().isoformat(), 'count': len(records),
        'sources': [
            {'name': 'KANJIDIC2', 'by': 'EDRDG', 'licence': 'CC BY-SA 4.0', 'version': dict_date},
            {'name': 'KanjiVG', 'by': 'Ulrich Apel', 'licence': 'CC BY-SA 3.0', 'version': os.path.basename(kvg_path)},
            {'name': 'JMdict', 'by': 'EDRDG', 'licence': 'CC BY-SA 4.0'},
            {'name': 'Kanji frequency (Aozora Bunko)', 'by': 'Dmitry Shpika', 'licence': 'CC BY 4.0'},
            {'name': 'JLPT levels', 'by': 'Jonathan Waller (Tanos), via kanji-data', 'licence': 'CC BY / MIT'},
        ]}, ensure_ascii=False).encode('utf-8')
    index, blob = [], bytearray()
    for char in sorted(records, key=ord):
        data = json.dumps(records[char], ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        index.append(struct.pack('<III', ord(char), len(blob), len(data)))
        blob += data
    pack = b'JDJK' + struct.pack('<III', FORMAT, len(records), len(meta)) + meta + b''.join(index) + bytes(blob)

    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'kanji-pack-{FORMAT}.bin.gz')
    with open(out, 'wb') as f:
        f.write(gzip.compress(pack, 9, mtime=0))
    packed = open(out, 'rb').read()
    print(f'{len(records)} characters ({sum(1 for r in records.values() if "d" in r)} with strokes, '
          f'{sum(1 for r in records.values() if "w" in r)} with words); '
          f'{len(pack) / 2 ** 20:.1f} MB unzipped')
    print(f'{out}: {len(packed)} bytes, sha256 {hashlib.sha256(packed).hexdigest()}')


if __name__ == '__main__':
    main()
