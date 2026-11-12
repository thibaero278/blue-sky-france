"""Test hors jeu : equipier monte dans un multi-places deja en l'air (python site/tools/test_equipage_en_vol.py, besoin de lupa)."""
import pathlib
from lupa import LuaRuntime

src = (pathlib.Path(__file__).parent.parent / 'mission' / 'script Caucase.lua').read_text(encoding='utf-8')
def cut(a, b): return src[src.index(a):src.index(b)]

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
NOW = 100
timer = { getTime = function() return NOW end }
coalition = { side = { BLUE = 2, RED = 1, NEUTRAL = 0 }, getPlayers = function(s) return s == 2 and UNITS or {} end }
env = { info = function() end }
BSCrew, CrewUnit, SeatUnit, Flights, FlightClosedAt, PlayerLife, UnitPlayer = {}, {}, {}, {}, {}, {}, {}
UNITS = {}
function SaveScores() end
function MessageToPlayer() end
function StartFlight(n) Flights[n] = { active = true } end
function CloseFlight(n) CrewUnit[n] = nil; local f = Flights[n]; Flights[n] = nil; return f and f.active end
function apache(dcsName)
  return { isExist = function() return true end, inAir = function() return true end,
           getName = function() return "apache" end, getPlayerName = function() return dcsName end, getID = function() return 1 end }
end
''' + cut('local function Crew(', 'local function EventUnitName') +
    cut('local function StartCrewFlight', '-- Valide les kills') +
    cut('local function CheckAirbornePlayers', 'timer.scheduleFunction(function()\n    local ok, err = pcall(CheckAirbornePlayers)') + '''
_G.Check = CheckAirbornePlayers
''')
g = lua.globals()

def reset():
    lua.execute('for _, t in ipairs({BSCrew, CrewUnit, SeatUnit, Flights, FlightClosedAt, PlayerLife}) do for k in pairs(t) do t[k] = nil end end')

# 1. DCS donne bien le pilote : l'equipier monte en vol, son vol demarre
reset()
lua.execute('Flights.Dex = { active = true }; UNITS = { apache("Dex") }; BSCrew.apache = { "Dex", "Weefe" }; Check()')
assert g.Flights['Weefe'] and g.Flights['Weefe'].active, 'cas 1 : vol equipier non demarre'

# 2. Le bug : l'equipier sort d'un autre avion (dead = true) et DCS le donne comme pilote de l'Apache
reset()
lua.execute('''Flights.Dex = { active = true }; PlayerLife.Weefe = { dead = true }; FlightClosedAt.Weefe = 0
UNITS = { apache("Weefe") }; BSCrew.apache = { "Dex", "Weefe" }; Check()''')
assert g.Flights['Weefe'] and g.Flights['Weefe'].active, 'cas 2 : vol bloque par la vie precedente'

# 3. Mort pendant le vol, toujours assis : pas de nouveau vol (dead reste vrai)
lua.execute('Flights.Weefe = nil; PlayerLife.Weefe = { dead = true }; FlightClosedAt.Weefe = NOW - 30; Check()')
assert not g.Flights['Weefe'], 'cas 3 : vol relance apres une mort'

# 4. Place quittee en vol : vol ferme
reset()
lua.execute('Flights.Dex = { active = true }; UNITS = { apache("Dex") }; BSCrew.apache = { "Dex", "Weefe" }; Check()')
lua.execute('NOW = 200; BSCrew.apache = { "Dex" }; Check()')
assert not g.Flights['Weefe'] and not g.SeatUnit['Weefe'], 'cas 4 : place quittee non fermee'

print('OK : 4 cas equipage en vol')
