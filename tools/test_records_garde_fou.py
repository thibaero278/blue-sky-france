"""Test hors jeu du garde-fou des records vitesse / altitude : python site/tools/test_records_garde_fou.py (lupa).

Extrait du vrai script HeldValue et SampleFlights, dans le faux DCS partagé (mocks/fakedcs.lua) :
une valeur ne compte que tenue 1 s.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / 'mocks'))
import fakedcs  # noqa: E402

src = fakedcs.SCRIPT.read_text(encoding='utf-8')
code = src[src.index('RECORD_SAMPLE_S = 0.5'):src.index('timer.scheduleFunction(function()\n    local ok, err = pcall(SampleFlights)')]

lua = fakedcs.runtime()
lua.execute('''
U = Fake.addGroup({ kind = "AIRPLANE", coal = 2, units = { { name = "U" } } }).units[1]
U.player, U.air = "P", true
function Crew(_, name) return { name } end
Flights = { P = { active = true } }
''' + code + '''
_G.SampleFlights = SampleFlights
function run(seconds, speed, alt)  -- relevés toutes les 0,5 s pendant seconds, à cette vitesse / altitude
  U.speed, U.y = speed, alt or U.y
  for _ = 1, math.floor(seconds / 0.5 + 0.5) do Fake.now = Fake.now + 0.5; SampleFlights() end
end
''')
f = lambda k: lua.eval(f'Flights.P.{k} or 0')

lua.execute('run(3, 200, 3000)')
assert f('maxSpeed') == 200 and f('maxAlt') == 3000
# pic d'un seul relevé (bug DCS) : ignoré
lua.execute('run(0.5, 1183) run(2, 200)')
assert f('maxSpeed') == 200, f('maxSpeed')
# pic sur 2 relevés (0,5 s) : toujours ignoré
lua.execute('run(1, 1183) run(2, 200)')
assert f('maxSpeed') == 200
# vitesse tenue 1,5 s : comptée
lua.execute('run(1.5, 450) run(2, 200)')
assert f('maxSpeed') == 450, f('maxSpeed')
# altitude : saut d'un relevé ignoré, palier tenu compté
lua.execute('run(0.5, 200, 30000) run(2, 200, 3000)')
assert f('maxAlt') == 3000
lua.execute('run(2, 200, 9000) run(1, 200, 3000)')
assert f('maxAlt') == 9000
# trou dans les relevés (au sol entre deux) : pas de mélange avant / après
lua.execute('run(0.5, 300) U.air = false run(3, 0) U.air = true run(0.5, 300) run(2, 200)')
assert f('maxSpeed') == 450
print('garde-fou records : OK')
