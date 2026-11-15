"""Test hors jeu de la voix d'accueil : python site/tools/test_voix_accueil.py (lupa).

Extrait du vrai script le bloc « Voix d'accueil », dans le faux DCS partagé (mocks/fakedcs.lua) : jouée
WELCOME_VOICE_DELAY_S après l'apparition, une fois par mission, et rejouée à l'apparition suivante si le pilote a
quitté l'avion avant.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / 'mocks'))
import fakedcs  # noqa: E402

src = fakedcs.SCRIPT.read_text(encoding='utf-8')
delay = src[src.index('WELCOME_VOICE_DELAY_S ='):].split('\n')[0]
block = src[src.index("        -- Voix d'accueil (commandement)"):src.index('    local dcsGroup = dcsUnit:getGroup()')]
block = block[:block.rindex('    end')]   # retire le « end » du « if playerName »

lua = fakedcs.runtime()
lua.execute(delay + '''
WelcomeVoiced = {}
function spawn(unitName, playerName)
  local u = Fake.addGroup({ kind = "AIRPLANE", coal = 2, units = { { name = unitName } } }).units[1]
  u.player = playerName
  local dcsUnit = u
''' + block + '''
end
function wait(s) Fake.runUntil(Fake.now + s) end
function played(i) local s = Fake.sounds[i] return s and (table.concat(s.to, ",") .. " " .. s.file) end
''')
ev = lua.eval

assert ev('WELCOME_VOICE_DELAY_S') == 10
lua.execute('spawn("F18-1", "Alpha"); wait(9)')
assert ev('#Fake.sounds') == 0                         # pas pendant le chargement
lua.execute('wait(1)')
assert ev('played(1)') == 'Alpha c00_accueil.ogg'    # après 10 s, au pilote seul
lua.execute('spawn("F18-2", "Alpha"); wait(10)')
assert ev('#Fake.sounds') == 1                         # une seule fois par mission
lua.execute('spawn("F18-3", "Bravo"); Fake.units["F18-3"].exists = false; wait(10)')
assert ev('#Fake.sounds') == 1                         # avion quitté avant la voix : rien...
lua.execute('spawn("F18-4", "Bravo"); wait(10)')
assert ev('played(2)') == 'Bravo c00_accueil.ogg'    # ... rejouée à l'apparition suivante
print('voix d\'accueil : OK')
