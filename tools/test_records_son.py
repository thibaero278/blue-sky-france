"""Test hors jeu du son des records battus (17/11) : python site/tools/test_records_son.py (lupa).

Extrait du vrai script RECORDS et SetRecord : record du serveur battu = message + PA.ogg a tout le serveur,
un seul son pour plusieurs records d'affilee, rien pour un simple record perso.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / 'mocks'))
import fakedcs  # noqa: E402

src = fakedcs.SCRIPT.read_text(encoding='utf-8')
code = src[src.index('local function FormatDistance'):src.index('local function PlayerFromEvent')]

lua = fakedcs.runtime()
lua.execute('''
function FormatFlightTime(s) return tostring(s) end
Scores = { A = { maxSpeed = 300, maxAltitude = 9000 }, B = { maxSpeed = 100 } }
''' + code + '''
_G.SetRecord = SetRecord
function pa() local n = 0 for _, s in ipairs(Fake.sounds) do if s.kind == "all" and s.file == "PA.ogg" then n = n + 1 end end return n end
''')
pa = lambda: lua.eval('pa()')

lua.execute('SetRecord("B", Scores.B, "maxSpeed", 200)')  # record perso, pas celui du serveur
assert pa() == 0
lua.execute('SetRecord("B", Scores.B, "maxSpeed", 400)')  # record du serveur battu
assert pa() == 1
lua.execute('SetRecord("B", Scores.B, "maxAltitude", 9500)')  # 2e record dans la foulee : pas de 2e son
assert pa() == 1
lua.execute('Fake.now = Fake.now + 15 SetRecord("A", Scores.A, "maxSpeed", 500)')  # plus tard : nouveau son
assert pa() == 2
print('son des records : OK')
