#!/usr/bin/env python3
"""검수된 배치를 병합해 assets/data/n2_words.json(v2 스키마)을 만든다.
사용: python3 tool/merge_audit.py <out_dir> <in_dir>
"""
import glob, json, re, sys
from collections import Counter

out_dir, in_dir = sys.argv[1], sys.argv[2]
KANA = re.compile(r'^[぀-ゟ゠-ヿー]+$')
TYPES = {'on', 'kun', 'katakana', 'other'}

# 검수 후 수동 판정: 한국어 한자음으로 뜻을 유추하면 틀리는 단어
TRAP_IDS = {
    547, 851, 1764, 891, 583, 420, 1610, 1515, 1356, 1824, 1091, 173, 1102,
    190, 974, 262, 582, 1100, 1742, 1725, 1447, 805, 873, 917,
}
# 검수 후 완전 중복으로 판정된 항목 (표기+읽기 동일)
DROP_IDS = {584, 1646, 1784}

merged = []
for f in sorted(glob.glob(f'{out_dir}/batch_*.json')):
    src = json.load(open(f.replace(out_dir, in_dir)))
    out = json.load(open(f))
    assert [x['id'] for x in src] == [x['id'] for x in out], f'id order mismatch in {f}'
    merged.extend(out)

merged = [x for x in merged if x['id'] not in DROP_IDS]
ids = [x['id'] for x in merged]
assert len(ids) == len(set(ids)), 'duplicate ids'

for x in merged:
    x['is_trap'] = x['id'] in TRAP_IDS
    assert KANA.match(x['reading']), (x['id'], x['reading'])
    assert x['type'] in TYPES, x['id']
    core = x['expression'].replace('～', '')
    stem = core[:-1] if re.search(r'[぀-ゟ]$', core) and len(core) > 1 else core
    assert stem in x['example']['ja'], (x['id'], x['expression'], x['example']['ja'])

# 같은 표기·읽기지만 뜻이 다른 접사(～発: 총알 세는 단위 / 출발)는 허용
ALLOWED_DUPS = {('～発', 'はつ')}
dups = Counter((x['expression'], x['reading']) for x in merged)
bad = [k for k, v in dups.items() if v > 1 and k not in ALLOWED_DUPS]
assert not bad, bad

final = [{
    'id': x['id'], 'expression': x['expression'], 'reading': x['reading'],
    'meaning_en': x.get('meaning_en', ''), 'meaning_ko': x['meaning_ko'],
    'type': x['type'], 'is_trap': x['is_trap'], 'example': x['example'],
} for x in merged]
json.dump(final, open('assets/data/n2_words.json', 'w'), ensure_ascii=False, indent=2)
print('written', len(final), Counter(x['type'] for x in final), 'trap', sum(x['is_trap'] for x in final))
