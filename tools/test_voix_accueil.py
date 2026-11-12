"""Test hors jeu de la voix d'accueil : python site/tools/test_voix_accueil.py (lupa).

Extrait du vrai script le bloc « Voix d'accueil » : jouée WELCOME_VOICE_DELAY_S après l'apparition, une fois par
mission, et rejouée à l'apparition suivante si le pilote a quitté l'avion avant.
"""
import pathlib
from lupa.lua51 import LuaRuntime

src = (pathlib.Path(__file__).parent.parent / 'mission' / 'script Caucase.lua').read_text(encoding='utf-8')
delay = src[src.index('WELCOME_VOICE_DELAY_S ='):].split('\n')[0]
block = src[src.index("        -- Voix d'accueil (commandement)"):src.index('    local dcsGroup = dcsUnit:getGroup()')]
block = block[:block.rindex('    end')]   # retire le « end » du « if playerName »

lua = LuaRuntime()
lua.execute(delay + '''
NOW, TASKS, PLAYED, UNITS = 0, {}, {}, {}
timer = { getTime = function() return NOW end, scheduleFunction = function(f, _, t) TASKS[#TASKS + 1] = { f = f, t = t } end }
trigger = { action = { outSoundForUnit = function(id, file) PLAYED[#PLAYED + 1] = id .. file end } }
Unit = { getByName = function(n) return UNITS[n] end }
WelcomeVoiced = {}
function spawn(id, unitName, playerName)
  local u = { getID = function() return id end, getName = function() return unitName end,
              isExist = function() return true end, getPlayerName = function() return playerName end }
  UNITS[unitName] = u
  local dcsUnit = u
''' + block + '''
end
function wait(s)
  NOW = NOW + s
  for i = #TASKS, 1, -1 do if TASKS[i].t <= NOW then local t = table.remove(TASKS, i); t.f() end end
end
''')
ev = lua.eval

assert ev('WELCOME_VOICE_DELAY_S') == 10
lua.execute('spawn(1, "F18-1", "Alpha"); wait(9)')
assert ev('#PLAYED') == 0                       # pas pendant le chargement
lua.execute('wait(1)')
assert ev('PLAYED[1]') == '1c00_accueil.ogg'   # après 10 s
lua.execute('spawn(2, "F18-2", "Alpha"); wait(10)')
assert ev('#PLAYED') == 1                       # une seule fois par mission
lua.execute('spawn(3, "F18-3", "Bravo"); UNITS["F18-3"] = nil; wait(10)')
assert ev('#PLAYED') == 1                       # avion quitté avant la voix : rien...
lua.execute('spawn(4, "F18-4", "Bravo"); wait(10)')
assert ev('PLAYED[2]') == '4c00_accueil.ogg'   # ... rejouée à l'apparition suivante
print('voix d\'accueil : OK')
