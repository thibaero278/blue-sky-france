"""Test hors jeu : points divises hors aeroport, DEBUG revalider l'atterrissage, zones Destroy cap (13/11).
python site/tools/test_atterrissage.py (besoin de lupa). Faux DCS partagé : mocks/fakedcs.lua."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / 'mocks'))
import fakedcs  # noqa: E402

src = fakedcs.SCRIPT.read_text(encoding='utf-8')
def cut(a, b): return src[src.index(a):src.index(b)]

lua = fakedcs.runtime()
lua.execute('''
Fake.now = 100
AB = Fake.addAirbase({ name = "Kobuleti", x = 0, z = 0, runway = 0 })
TIME_PTS_S, CARRIERS, STATS, SENT = 300, {}, {}, {}
function InitPlayer(n) STATS[n] = STATS[n] or { points = 0, airair = 0, airsol = 0, airmer = 0, landings = 0,
    completedFlightTime = 0 } return STATS[n] end
function GetRank() return 1, { name = "x" } end
function SetRecord() end
function SaveScores() end
function FormatFlightTime(t) return tostring(t) end
function NewFlight() return { points = 0, airair = 0, airsol = 0, airmer = 0, refuelTime = 0 } end
function MessageToPlayer(id, text) SENT[#SENT + 1] = text end
Flights = {}
function CloseFlight(n) local f = Flights[n]; Flights[n] = nil; if f and f.active then return 600, f end end
function unit(x, z, air, speed)
  local u = Fake.addGroup({ kind = "AIRPLANE", coal = 2, units = { { x = x, z = z } } }).units[1]
  u.player, u.air, u.speed = "Alpha", air, speed
  return u
end
function ForEachGroupPlayer(g, fn) fn(1, "Alpha", g.u) end
function fly(pts) local f = NewFlight(); f.active = true; f.points = pts; Flights.Alpha = f end
''' + cut('-- divisor (atterrissage hors', '-- NAISSANCE (spawn') +
    cut('-- ATTERRISSAGE HORS AEROPORT', '-- Porte-avions : on attend') + 'end\n' +  # fin de LandFlight (branche porte-avions coupee)
    cut('-- DEBUG (13/11)', '-- MENU F10 STATISTIQUES') + 'DestroyWatch = {}\n' +
    'Fake.addZone({ name = "Destroy cap", quad = { { 1000, -1e7 }, { 1000, 1e7 }, { 1e7, 1e7 }, { 1e7, -1e7 } } })\n' +
    'Fake.addZone({ name = "Destroy cap-2", x = -1e7, z = 0, r = 1 })\n' +
    cut('-- ZONES DESTROY CAP', '-- MENUS F10 MISSIONS + CODE') + '_G.DestroyTick = DestroyTick\n')
ev = lua.eval
def fly(pts): lua.execute(f'fly({pts})')

# Kobuleti donne en Place par DCS : points entiers (20 + 2 pour 10 min de vol)
fly(20)
lua.execute('local f = Flights.Alpha; local e = CloseFlight("Alpha"); local b, on = LandPlace(unit(9000, 0, false, 0), AB); LandFlight("Alpha", f, e, b, on, unit(0,0,false,0), true)')
assert ev('STATS.Alpha.points') == 22, ev('STATS.Alpha.points')

# dans l'herbe a 9 km, pas de Place : (20 + 2) / 2 = 11
fly(20)
lua.execute('local f = Flights.Alpha; local e = CloseFlight("Alpha"); local b, on = LandPlace(unit(9000, 0, false, 0)); LandFlight("Alpha", f, e, b, on, unit(0,0,false,0), true)')
assert ev('STATS.Alpha.points') == 33, ev('STATS.Alpha.points')
assert 'hors aeroport' in ev('SENT[#SENT]') and '(-11)' in ev('SENT[#SENT]'), ev('SENT[#SENT]')

# herbe a 2 km de la base, ou sur une piste loin du centre : points entiers
assert ev('select(2, LandPlace(unit(2000, 0, false, 0)))') is True
lua.execute('AB.runway = 10000'); assert ev('select(2, LandPlace(unit(9000, 0, false, 0)))') is True; lua.execute('AB.runway = 0')

# DEBUG : refuse sans vol, en vol, trop vite ; accepte pose et arrete
ev('DebugRevalidateLanding({ u = unit(0, 0, false, 0) })'); assert 'aucun vol' in ev('SENT[#SENT]')
fly(10)
ev('DebugRevalidateLanding({ u = unit(0, 0, true, 0) })'); assert 'refuse' in ev('SENT[#SENT]')
ev('DebugRevalidateLanding({ u = unit(0, 0, false, 10) })'); assert 'refuse' in ev('SENT[#SENT]')
ev('DebugRevalidateLanding({ u = unit(0, 0, false, 1) })')
assert 'Bienvenue a Kobuleti' in ev('SENT[#SENT]') and ev('Flights.Alpha') is None, ev('SENT[#SENT]')
assert ev('STATS.Alpha.points') == 45, ev('STATS.Alpha.points')

# Destroy cap : l'avion entre dans la zone (x > 1000) -> supprime, groupe retire de la liste
lua.execute('''
function plane(x) local g = Fake.addGroup({ kind = "AIRPLANE", coal = 1, alt = 5000, units = { { x = x, z = 0 } } }) return g.units[1], Fake.wrapGroup(g.name) end
IN, WIN = plane(5000)
OUT, WOUT = plane(0)
DestroyWatch = { WIN, WOUT }
''')
ev('DestroyTick()')
assert ev('IN.exists') is False and ev('OUT.exists') is True and ev('#DestroyWatch') == 1
print('atterrissage / debug / destroy cap : OK')
