"""Migre un Scores.lua (ancien ou v2) vers le format exact écrit par mission/script Caucase.lua (v2).

Usage : python tools/migrer_scores.py "ancien/Scores.lua" [sortie.lua]
Sortie par défaut : mission/Scores.lua. L'original n'est jamais modifié.

- Tous les champs de SCORE_FIELDS (lus dans le script) sont écrits, entiers.
- rang recalculé avec la table RANKS du script.
- Pilotes triés par points (puis par nom) : fichier lisible et stable.
- Retirés : pseudos par défaut de DCS (Player, Joueur…) et profils entièrement vides.
- Ancien format (sans heures totales) : le vol le plus long est le seul temps connu, et c'était un vol
  terminé par un atterrissage (l'ancien script n'arrêtait le chrono qu'à l'atterrissage). On s'en sert
  donc comme minimum pour totalFlightTime / completedFlightTime, et flights = 1 s'il existe.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, '..', 'mission', 'script Caucase.lua')
IGNORED = {'player', 'joueur', 'new callsign'}

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'mission', 'Scores.lua')

script = open(SCRIPT, encoding='utf-8').read()
fields = re.findall(r'"(\w+)"', re.search(r'local SCORE_FIELDS = \{(.*?)\}', script, re.S).group(1))
ranks = [(int(m), n) for m, n in re.findall(r'\{\s*min\s*=\s*(\d+),\s*name\s*=\s*"([^"]+)"\s*\}',
                                              re.search(r'local RANKS = \{(.*?)\n\}', script, re.S).group(1))]


def lua_str(s):
    """Équivalent de string.format('%q') pour les pseudos."""
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def parse(text):
    out = {}
    for name, body in re.findall(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*\{(.*?)\}', text, re.S):
        name = re.sub(r'\\(.)', r'\1', name)
        p = {}
        for k, v in re.findall(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|[-\d.]+)', body):
            p[k] = v[1:-1] if v.startswith('"') else int(float(v))
        out[name] = p
    return out


old = parse(open(src, encoding='utf-8').read())
legacy = not any('totalFlightTime' in p for p in old.values())
pilots, dropped = {}, []
for name, p in old.items():
    s = {f: int(p.get(f, 0) or 0) for f in fields}
    if legacy and s['maxFlightTime'] > 0:
        s['totalFlightTime'] = max(s['totalFlightTime'], s['maxFlightTime'])
        s['completedFlightTime'] = max(s['completedFlightTime'], s['maxFlightTime'])
        s['flights'] = max(s['flights'], 1)
    if name.strip().lower() in IGNORED or not any(s.values()):
        dropped.append(name)
        continue
    s['grade'] = p.get('grade', 'ROOKIE')
    s['rang'] = [n for m, n in ranks if s['points'] >= m][-1]
    pilots[name] = s

lines = ['return {\n']
for name, s in sorted(pilots.items(), key=lambda kv: (-kv[1]['points'], kv[0].lower())):
    lines.append(f'    [{lua_str(name)}] = {{\n')
    lines += [f'        {f} = {s[f]},\n' for f in fields]
    lines.append(f'        grade = {lua_str(s["grade"])},\n')
    lines.append(f'        rang = {lua_str(s["rang"])},\n')
    lines.append('    },\n')
lines.append('}\n')
open(dst, 'w', encoding='utf-8', newline='\n').write(''.join(lines))

print(f'{len(pilots)} pilotes ecrits dans {os.path.normpath(dst)}' + (' (ancien format migre)' if legacy else ''))
if dropped:
    print('Retires :', ', '.join(dropped))
for name, s in sorted(pilots.items(), key=lambda kv: -kv[1]['points'])[:5]:
    print(f'  {s["points"]:>4} pts  {s["rang"]:<28} {name}')
