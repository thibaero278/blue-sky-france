"""Test hors jeu du garde-fou des records vitesse / altitude : python site/tools/test_records_garde_fou.py (lupa).

Extrait du vrai script HeldValue et SampleFlights, avec un faux DCS : une valeur ne compte que tenue 1 s.
"""
import pathlib
from lupa import LuaRuntime

src = (pathlib.Path(__file__).parent.parent / 'mission' / 'script Caucase.lua').read_text(encoding='utf-8')
code = src[src.index('RECORD_SAMPLE_S = 0.5'):src.index('timer.scheduleFunction(function()\n    local ok, err = pcall(SampleFlights)')]

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
NOW, SPEED, ALT, AIR = 0, 200, 3000, true
timer = { getTime = function() return NOW end }
coalition = { side = { RED = 1, BLUE = 2, NEUTRAL = 0 }, getPlayers = function(side)
  if side ~= 2 then return {} end
  return { { isExist = function() return true end, getPlayerName = function() return "P" end, getName = function() return "U" end,
             inAir = function() return AIR end, getPoint = function() return { y = ALT } end,
             getVelocity = function() return { x = SPEED, y = 0, z = 0 } end } }
end }
function Crew(_, name) return { name } end
Flights = { P = { active = true } }
''' + code + '''
_G.SampleFlights = SampleFlights
function run(seconds, speed, alt)  -- relevés toutes les 0,5 s pendant seconds, à cette vitesse / altitude
  SPEED, ALT = speed, alt or ALT
  for _ = 1, math.floor(seconds / 0.5 + 0.5) do NOW = NOW + 0.5; SampleFlights() end
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
lua.execute('run(0.5, 300) AIR = false run(3, 0) AIR = true run(0.5, 300) run(2, 200)')
assert f('maxSpeed') == 450
print('garde-fou records : OK')
