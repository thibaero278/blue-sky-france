"""Convertit un Scores.lua (écrit par mission/script Caucase.lua) en web/data/stats.json pour le site.

Usage : python tools/scores_to_json.py "chemin/vers/Scores.lua"
Le site lit ce fichier quand statsUrl (Apps Script) n'est pas renseigné.
"""
import json, os, re, sys
from datetime import datetime, timezone

src = sys.argv[1] if len(sys.argv) > 1 else 'Scores.lua'
dst = os.path.join(os.path.dirname(__file__), '..', 'web', 'data', 'stats.json')

text = open(src, encoding='utf-8').read()
pilots = []
# Chaque entrée : ["pseudo"] = { cle = valeur, ... },
for name, body in re.findall(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*\{(.*?)\}', text, re.S):
    p = {'name': name.encode().decode('unicode_escape').encode('latin-1').decode('utf-8')}
    for key, val in re.findall(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|[-\d.]+)', body):
        p[key] = val[1:-1] if val.startswith('"') else (float(val) if '.' in val else int(val))
    pilots.append(p)

mtime = datetime.fromtimestamp(os.path.getmtime(src), timezone.utc)
out = {'source': 'Scores.lua', 'updated': mtime.isoformat(), 'pilots': pilots}
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print(f'{len(pilots)} pilotes -> {os.path.normpath(dst)} (Scores.lua du {mtime:%d/%m/%Y %H:%M} UTC)')
