"""Test hors jeu des distances de kill : python site/tools/test_kill_distance.py (besoin de lupa).

Extrait du vrai script le suivi des armes et GetTargetPoint, avec un faux DCS.
"""
import pathlib
from lupa import LuaRuntime

src = (pathlib.Path(__file__).parent.parent / 'mission' / 'script Caucase.lua').read_text(encoding='utf-8')
tracker = src[src.index('TrackedWeapons = {}'):src.index('timer.scheduleFunction(TrackWeapons')]
handler = src[src.index('WeaponTrackerHandler = {}'):src.index('world.addEventHandler(WeaponTrackerHandler)')]
target = src[src.index('local function GetTargetPoint'):src.index('local function IsAirDefence')]

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
NOW = 100
timer = { getTime = function() return NOW end }
world = { event = { S_EVENT_SHOT = 1, S_EVENT_HIT = 2 } }
IP_DISTANCE, TRACK_INTERVAL = 1000, 1
function unit(x, z, name)
  return { getPlayerName = function() return name end, isExist = function(self) return not self.dead end,
           getPoint = function() return { x = x, y = 0, z = z } end }
end
function weapon(id, tgt) return { id_ = id, getTarget = function() return tgt end } end
''' + tracker + handler + target + '''
_G.GetTargetPoint = GetTargetPoint
_G.TrackWeapons = TrackWeapons
function dist(ev)  -- meme formule que OnEventKill
  local tp = GetTargetPoint(ev)
  local shot = type(ev.weapon) == "table" and Shots[ev.weapon.id_]
  return shot and (shot.dist or Distance2D(shot.point, tp or shot.last)) or Distance2D(ev.shooter, tp)
end
pilot = unit(0, 0, "P")
function shot(w) WeaponTrackerHandler:onEvent({ id = 1, initiator = pilot, weapon = w }) end
function hit(t) WeaponTrackerHandler:onEvent({ id = 2, initiator = pilot, target = t }) end
''')
ev = lua.eval

# missile verrouille : distance au tir, meme si l'avion s'est rapproche et que la cible a disparu
assert ev('''(function()
  local t = unit(70000, 0); local w = weapon(1, t); shot(w); hit(t); t.dead = true
  return dist({ IniPlayerName = "P", weapon = w, TgtDCSUnit = t, shooter = { x = 50000, z = 0 } })
end)()''') == 70000
# bombe sans cible verrouillee, cible disparue : tireur au tir -> position au dernier coup au but
assert ev('''(function()
  local t = unit(3000, 4000); local w = weapon(2, nil); shot(w); hit(t); t.dead = true
  return dist({ IniPlayerName = "P", weapon = w, TgtDCSUnit = t, shooter = { x = 0, z = 9999 } })
end)()''') == 5000
# canon (pas d'arme suivie), cible disparue : distance au moment du kill
assert ev('''(function()
  local t = unit(300, 0); hit(t); t.dead = true
  return dist({ IniPlayerName = "P", TgtDCSUnit = t, shooter = { x = 100, z = 0 } })
end)()''') == 200
# coup au but trop ancien : pas de position inventee
assert ev('''(function()
  local t = unit(300, 0); hit(t); t.dead = true; NOW = NOW + HIT_KEEP_S + 1
  return GetTargetPoint({ IniPlayerName = "P", TgtDCSUnit = t })
end)()''') is None
# SLAM-ER : 25 min de vol, cible detruite d'un coup (jamais localisee) : distance = tir -> derniere position du missile
assert ev('''(function()
  land = { getIP = function() return nil end }
  local w = weapon(3, nil); w.isExist = function() return true end
  w.getPosition = function() return { p = { x = 350000, y = 0, z = 0 }, x = {} } end
  TrackedWeapons = {}
  shot(w); NOW = NOW + 1500
  TrackWeapons(nil, NOW)
  return dist({ IniPlayerName = "P", weapon = w, shooter = { x = 900000, z = 0 } })
end)()''') == 350000

# mode Blue Sky : un faux Land au sol (pas de vol actif) ne le coupe pas ; la fin d'un vrai vol le compte puis le coupe
close = src[src.index('local function CloseFlight'):src.index('-- MULTI-EQUIPAGE')].rsplit('---', 1)[0]
lua.execute('''
FlightClosedAt, CrewUnit, BSMode, Flights, S = {}, {}, { P = true }, {}, { totalFlightTime = 0, bsFlightTime = 0, flights = 0 }
function StopRefuel() end
function InitPlayer() return S end
function SetRecord() end
env = { info = function() end }
''' + close + '''
_G.CloseFlight = CloseFlight
''')
assert ev('(function() CloseFlight("P"); return BSMode.P end)()') is True
assert ev('''(function()
  Flights.P = { active = true, startTime = NOW - 600 }
  CloseFlight("P"); return S.bsFlightTime
end)()''') == 600
assert ev('BSMode.P') is None

# le script complet reste compilable
lua.compile(src)
print('OK')
