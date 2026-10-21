"""Efface toutes les stats d'un pilote (demande de suppression RGPD, onglet « Demandes » de la feuille BS Stats).

Usage : python tools/supprimer_pilote.py "chemin/vers/Scores.lua" "pseudo en jeu" ["autre pseudo" ...]

- Serveur DCS / mission ARRÊTÉS : la mission garde les scores en mémoire et réécrirait le pilote.
- Sauvegarde du Scores.lua d'avant dans mission/bakup/ (jamais écrasée), puis retire le pilote
  de ce Scores.lua et de web/data/stats.json.
- Le site et la feuille se mettent à jour au prochain envoi du bot (il republie Scores.lua à chaque changement).
- Reste à faire à la main (affiché à la fin) : alias dans web/js/config.js, /prune dans la base du bot.
"""
import json, os, re, shutil, sys
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')
if len(sys.argv) < 3:
    sys.exit(__doc__)
src, names = sys.argv[1], sys.argv[2:]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

def lua_name(raw):
    return raw.encode().decode('unicode_escape').encode('latin-1').decode('utf-8')

text = open(src, encoding='utf-8').read()
removed = []
# Chaque entrée : ["pseudo"] = { cle = valeur, ... }, (une ligne par champ, pas de table imbriquée)
def drop(m):
    if lua_name(m.group(2)) in names:
        removed.append(lua_name(m.group(2)))
        return ''
    return m.group(0)
new = re.sub(r'([ \t]*)\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*\{.*?\},?[ \t]*\r?\n', drop, text, flags=re.S)

missing = [n for n in names if n not in removed]
if missing:
    print('Introuvable dans Scores.lua :', ', '.join(missing))
if removed:
    bak = os.path.join(root, 'mission', 'bakup', f'Scores_{datetime.now():%Y-%m-%d_%H-%M-%S}_avant-suppression.lua')
    os.makedirs(os.path.dirname(bak), exist_ok=True)
    shutil.copy2(src, bak)
    with open(src, 'w', encoding='utf-8', newline='') as f:
        f.write(new)
    print('Retiré de Scores.lua :', ', '.join(removed), '| sauvegarde :', os.path.normpath(bak))

stats = os.path.join(root, 'web', 'data', 'stats.json')
if os.path.exists(stats):
    data = json.load(open(stats, encoding='utf-8'))
    before = len(data['pilots'])
    data['pilots'] = [p for p in data['pilots'] if p.get('name') not in names]
    if len(data['pilots']) != before:
        with open(stats, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        print(f'Retiré de web/data/stats.json : {before - len(data["pilots"])} pilote(s)')

config = open(os.path.join(root, 'web', 'js', 'config.js'), encoding='utf-8').read()
for n in names:
    if f"'{n}'" in config:
        print(f"À retirer à la main dans web/js/config.js (alias / équipe) : '{n}'")
print("Base du bot : sur Discord, /prune user:<membre ou UCID> (commande Admin de DCSServerBot).")
print("Puis noter « Traité » + la date dans l'onglet Demandes et prévenir la personne.")
