"""Test hors bot de la fusion des scores (bug du 11/11 : stats x2) : python site/tools/test_fusion_scores.py (lupa).

Rejoue avec scores.py du plugin : Dex compté deux fois, Branch additionné à son ancien pseudo, record bugué,
envoi en jeu découpé (UDP 8 Ko) et reconstitué par lua/commands.lua + lua/mission.lua.
"""
import copy
import importlib.util
import json
import pathlib

from lupa.lua51 import LuaRuntime

ROOT = pathlib.Path(__file__).parent.parent
PLUGIN = ROOT / 'bot BS' / 'plugins' / 'bluesky'
spec = importlib.util.spec_from_file_location('scores', PLUGIN / 'scores.py')
sc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sc)


def P(points, flights=1, **kw):
    return {'points': points, 'flights': flights, 'airsol': points // 2, 'grade': 'ROOKIE', **kw}


ALIAS = sc.resolve({'DEX WAVE OFF 1-1': 'WaveOff | BlueSky 1-4', 'Branch 1-1 | Weefe': 'Branch | BlueSky 1-2',
                    'Branch': 'Branch 1-1 | Weefe', 'Seigneur-Perceval': 'Joker | BlueSky 2-1'})
assert ALIAS['Branch'] == 'Branch | BlueSky 1-2', ALIAS          # chaîne suivie
assert sc.resolve({'a': 'b', 'b': 'a'}) == {}   # boucle (erreur de config) : ignorée, pas de blocage

# 1. Consolidation : ancien + nouveau pseudo rangés à part → additionnés UNE fois, ancien effacé
total = {'Branch 1-1 | Weefe': P(524, 80), 'Branch | BlueSky 1-2': P(10, 2), 'DEX WAVE OFF 1-1': P(364, 110)}
total = sc.group(total, ALIAS)
assert set(total) == {'Branch | BlueSky 1-2', 'WaveOff | BlueSky 1-4'}
assert total['Branch | BlueSky 1-2']['points'] == 534 and total['WaveOff | BlueSky 1-4']['flights'] == 110
assert sc.group(total, ALIAS) == total   # relancé à chaque tour : ne change plus rien

# 2. Gain sous un ancien pseudo (Dex vole encore en « DEX WAVE OFF 1-1 ») : crédité au pilote, une fois
base = {'DEX WAVE OFF 1-1': P(364, 110)}
new = {'DEX WAVE OFF 1-1': P(374, 111)}
t = sc.merge(total, base, new, False, ALIAS)
assert t['WaveOff | BlueSky 1-4']['points'] == 374 and 'DEX WAVE OFF 1-1' not in t
assert sc.merge(t, new, new, False, ALIAS) == t   # relu sans changement : rien de plus

# 3. Le bug de Dex : envoi pas appliqué (message perdu) et bot redémarré pendant l'attente.
#    Avant : base = envoi avec « DEX WAVE OFF 1-1 » à 0 → le fichier (toujours à 364) recompté → 728.
sent = sc.for_mission(total, ALIAS)
assert 'DEX WAVE OFF 1-1' not in sent   # plus d'ancien pseudo envoyé à 0
safe = sc.safe_base(base, sent)
file_not_applied = {'DEX WAVE OFF 1-1': P(364, 110)}
t = sc.merge(total, safe, file_not_applied, False, ALIAS)
assert t['WaveOff | BlueSky 1-4']['points'] == 364, t   # rien recompté
#    envoi appliqué mais pas confirmé : le fichier = l'envoi, pas recompté non plus
t = sc.merge(total, safe, copy.deepcopy(sent), False, ALIAS)
assert t == total, t
#    confirmé : base = envoi, les gains suivants comptent normalement
after = copy.deepcopy(sent)
after['WaveOff | BlueSky 1-4']['points'] += 5
t = sc.merge(total, sent, after, False, ALIAS)
assert t['WaveOff | BlueSky 1-4']['points'] == 369

# 4. Serveur jamais lu dont le fichier a ancien + nouveau pseudo (le renommage de Weefe) : pas de x2
file_weefe = {'Branch 1-1 | Weefe': P(524, 80), 'Branch | BlueSky 1-2': P(10, 2)}
t = sc.merge(total, {}, file_weefe, True, ALIAS)
assert t['Branch | BlueSky 1-2']['points'] == 534, t['Branch | BlueSky 1-2']
assert 'Branch 1-1 | Weefe' not in t

# 5. Record bugué effacé sur R2D2 (Mach 4 de Perceval) : ne revient pas tant que le fichier ne change pas
total = {'Joker | BlueSky 2-1': P(11, 25, maxSpeed=0)}
base = {'Seigneur-Perceval': P(11, 25, maxSpeed=1183)}
t = sc.merge(total, base, copy.deepcopy(base), False, ALIAS)
assert t['Joker | BlueSky 2-1']['maxSpeed'] == 0
new = {'Seigneur-Perceval': P(11, 26, maxSpeed=1183)}   # nouveau vol, record du fichier inchangé
assert sc.merge(total, base, new, False, ALIAS)['Joker | BlueSky 2-1']['maxSpeed'] == 0
new = {'Seigneur-Perceval': P(11, 26, maxSpeed=1190)}   # vrai nouveau record dans le fichier
assert sc.merge(total, base, new, False, ALIAS)['Joker | BlueSky 2-1']['maxSpeed'] == 1190

# 6. Suppression RGPD : pilote dans la base d'un serveur mais plus dans le total → ignoré s'il ne rejoue pas
base = {'Tom': P(6)}
assert 'Tom' not in sc.merge({}, base, {'Tom': P(6)}, False, {})
assert sc.merge({}, base, {'Tom': P(8)}, False, {})['Tom']['points'] == 2

# 6b. Scores.lua corrigé copié à la main chez Weefe (11/11 22 h 55) : le fichier = le total, rien de gagné.
#     Avant : WaveOff 388 → 752, Napster1-1 23 → 46 (pseudo absent de l'ancienne base = « tout gagné »).
total = {'WaveOff | BlueSky 1-4': P(388, 124), 'Napster1-1 | Lixx': P(23, 1), 'Branch | BlueSky 1-2': P(648, 96)}
base = {'WaveOff | BlueSky 1-4': P(24, 14), 'DEX WAVE OFF 1-1': P(364, 110), 'Branch | BlueSky 1-2': P(648, 96)}
copy_by_hand = copy.deepcopy(total)
assert sc.merge(total, base, copy_by_hand, False, ALIAS) == total
after = copy.deepcopy(copy_by_hand)   # puis un vrai vol : compté normalement
after['WaveOff | BlueSky 1-4']['points'] += 3
assert sc.merge(total, copy_by_hand, after, False, ALIAS)['WaveOff | BlueSky 1-4']['points'] == 391
#     premier vol d'un pilote inconnu du total : compté
assert sc.merge(total, base, {'Nouveau': P(5)}, False, ALIAS)['Nouveau']['points'] == 5

# 7. Envoi découpé : chaque message (tel que le bot l'envoie) < 8192 octets, et tout est reconstitué en jeu
weefe = sc.parse_scores(pathlib.Path(r'C:\Users\thiba\Downloads\Scores (1).lua').read_bytes())
big = {f'{n} #{i}': p for i in range(3) for n, p in weefe.items()}   # 3x les pilotes actuels
parts = sc.chunks(big)
msgs = []
for i, part in enumerate(parts, 1):
    m = {'command': 'bsSetScores', 'scores': json.dumps(part), 'id': '220501123456', 'part': i, 'parts': len(parts),
         'server_name': 'Blue Sky France', 'channel': '-1'}
    if i == len(parts):
        m['remove'] = json.dumps(['Branch 1-1 | Weefe'])
    msgs.append(m)
    assert len(json.dumps(m).encode('utf-8')) < 8192, len(json.dumps(m).encode('utf-8'))
assert len(parts) > 1 and sum(len(p) for p in parts) == len(big)

lua = LuaRuntime(unpack_returned_tuples=True)
to_lua = lambda v: lua.table_from({k: to_lua(x) for k, x in v.items()}) if isinstance(v, dict) else (
    lua.table_from([to_lua(x) for x in v]) if isinstance(v, list) else v)
lua.globals().py_json2lua = lambda s: to_lua(json.loads(s))
lua.execute('''
net = { json2lua = function(s) return py_json2lua(s) end, dostring_in = function(_, code) SENT[#SENT + 1] = code end }
utils = { basicSerialize = function(s) return string.format('%q', s) end }
log = { write = function() end, WARNING = 1 }
SENT, Scores, SAVED = {}, { ['Branch 1-1 | Weefe'] = { points = 524 } }, 0
function InitPlayer(n) Scores[n] = Scores[n] or {}; return Scores[n] end
function SaveScores() SAVED = SAVED + 1 end
env = { info = function() end, warning = function() end }
dcsbot = {}
''')
hook = (PLUGIN / 'lua' / 'commands.lua').read_text(encoding='utf-8')
mission = (PLUGIN / 'lua' / 'mission.lua').read_text(encoding='utf-8')
lua.execute(hook[hook.index('-- Envoyé en plusieurs morceaux'):])
hook_set = lua.eval('dcsbot.bsSetScores')
lua.execute('dcsbot = {}\n' + mission[mission.index('-- id, part, parts'):mission.index('-- Places 2, 3')])
for m in reversed(msgs):   # ordre d'arrivée quelconque
    hook_set(to_lua(m))
    code = lua.eval('SENT[#SENT]')
    assert code.startswith('a_do_script(')
    lua.execute(lua.eval('function(c) return loadstring("return " .. c:sub(13, -2))() end')(code))
    if m['part'] != 1:
        assert lua.eval('SAVED') == 0   # rien d'appliqué avant le dernier morceau
assert lua.eval('SAVED') == 1 and lua.eval('BS_SCORES_SYNCED') == '220501123456'
assert lua.eval('Scores["Branch 1-1 | Weefe"]') is None   # ancien pseudo retiré du fichier
n = lua.eval('(function() local c = 0 for _ in pairs(Scores) do c = c + 1 end return c end)()')
assert n == len(big), n
# un seul morceau (petit total, ou ancien hook sans id) : appliqué tout de suite
lua.execute('BS_SCORES_SYNCED = nil')
lua.eval('dcsbot.bsSetScores')('{"Solo": {"points": 1}}', None, None, None, None)
assert lua.eval('BS_SCORES_SYNCED') is True and lua.eval('Scores.Solo.points') == 1
print(f'fusion des scores : OK ({len(parts)} morceaux pour {len(big)} pilotes)')
