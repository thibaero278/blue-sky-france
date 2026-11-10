"""Test hors jeu des missions a code : python site/tools/test_missions_code.py (besoin de lupa).

Extrait du vrai script les codes, les missions strike et le jugement des tirs d'interception, avec un faux DCS.
"""
import pathlib
import re
from lupa import LuaRuntime

src = (pathlib.Path(__file__).parent.parent / 'mission' / 'script Caucase.lua').read_text(encoding='utf-8')
def cut(a, b): return src[src.index(a):src.index(b)]

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
NOW = 100
timer = { getTime = function() return NOW end, scheduleFunction = function(f) SCHED = f end }
coalition = { side = { BLUE = 2, RED = 1 }, getPlayers = function() return UNITS end,
              getStaticObjects = function() return STATICS end }
env = { warning = function(m) error(m) end, info = function() end }
ADMIRAL = {}
Group = { getByName = function() return ADMIRAL end }
UNITS, STATICS, SENT, GMSG, PlayerLife, Flights, AWARD = {}, {}, {}, {}, {}, {}, {}
function SaveScores() end
function NewFlight() return { points = 0 } end
function CommitFlightKills(name, f) AWARD[name] = (AWARD[name] or 0) + f.points end
function MessageToPlayer(id, text) SENT[#SENT + 1] = { id = id, text = text } end
MESSAGE = { New = function(_, text) return { ToGroup = function(_, g) GMSG[g:GetName()] = text end, ToCoalition = function() end } end }
function Crew(_, pilot) return { pilot } end
function ForEachGroupPlayer(g, fn) for i, n in ipairs(g.players) do fn(i, n) end end
function Distance2D(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end
function grp(name, ...)
  local g = { players = { ... } }
  function g:IsAlive() return true end
  function g:GetName() return name end
  return g
end
function player(id, name)
  return { isExist = function() return true end, getName = function() return "u" .. id end,
           getPlayerName = function() return name end, getID = function() return id end,
           pos = { x = 0, y = 0, z = 0 }, getPoint = function(s) return s.pos end }
end
trigger = { misc = { getZone = function() return { point = { x = 0, z = 0 }, radius = 100 } end } }
function obj(typeName, x, z)
  local o = { life = 10 }
  function o:isExist() return true end
  function o:getLife() return self.life end
  function o:getTypeName() return typeName end
  function o:getPoint() return { x = x, y = 0, z = z } end
  return o
end
Icpt = nil
function IcptMsg() end
ICPT_LABEL = "INTERCEPTION"
function IcptEnd() Ops[ICPT_LABEL] = nil; Icpt = nil end
''' + cut('local OP_CODE_LEN', '-- INTERCEPTION (08/11)') +
    cut('local NAVAL_HOST', '-- MISSIONS STRIKE') +
    cut('local OP_IDLE_S', '-- MENUS F10 MISSIONS + CODE') +
    cut('-- Appele par le KillHandler', 'local function IcptTick') + '''
_G.STRIKES, _G.StrikeTick, _G.OpStart, _G.OpReward, _G.CapTick = STRIKES, StrikeTick, OpStart, OpReward, CapTick
_G.OpVoice = OpVoice
function enter(g, code) for d in code:gmatch(".") do CodeDigit(g, tonumber(d)) end end
function members(op) local t = {} for n in pairs(op.members) do t[#t + 1] = n end table.sort(t) return table.concat(t, ",") end
leader, wing = grp("L", "Alpha"), grp("W", "Bravo")
UNITS = { player(1, "Alpha"), player(2, "Bravo") }
STATICS = { obj("Oil rig", -274568, 495942), obj("Gas platform", -274419, 495765), obj("Oil rig", 0, 0) }
''')
ev = lua.eval

# lancement : le lanceur est membre, le code est donne, et seulement a lui (cible hors champ exclue)
ev('StrikeLaunch(leader, STRIKES[1])')
assert ev('Ops["Petrol Strike"].left') == 2
assert ev('members(Ops["Petrol Strike"])') == 'Alpha'
code = ev('Ops["Petrol Strike"].code')
assert len(code) == 3 and '0' not in code and code in ev('GMSG.L')

# deuxieme lancement refuse ; un mauvais code ne rejoint rien
ev('StrikeLaunch(wing, STRIKES[1])')
assert 'deja en cours' in ev('GMSG.W')
bad = '111' if code != '111' else '222'
ev(f'enter(wing, "{bad}")')
assert 'INCONNU' in ev('GMSG.W') and ev('members(Ops["Petrol Strike"])') == 'Alpha'

# Effacer repart de zero ; le bon code rejoint et donne le briefing
ev('CodeDigit(wing, 5)'); ev('CodeClear(wing)')
ev(f'enter(wing, "{code}")')
assert ev('members(Ops["Petrol Strike"])') == 'Alpha,Bravo'
assert 'MISSION REJOINTE' in ev('GMSG.W') and code in ev('GMSG.W')

# cibles : progression, puis bonus egal a chaque membre vivant (Bravo est mort : rien), mission fermee
lua.execute('STATICS[1].life = 0'); ev('StrikeTick(Ops["Petrol Strike"])')
assert 'venir au moins une fois' not in ev('GMSG.W')  # Petrol : aucune condition de zone (Alpha n'y est jamais alle)
assert ev('Ops["Petrol Strike"].left') == 1
lua.execute('PlayerLife.Bravo = { dead = true }'); lua.execute('STATICS[2].life = 0'); ev('StrikeTick(Ops["Petrol Strike"])')
assert ev('Ops["Petrol Strike"]') is None and ev('AWARD.Alpha') == 20 and ev('AWARD.Bravo') is None
lua.execute('PlayerLife.Bravo = nil')
# objectif detruit : plus relancable tant que la mission serveur tourne
ev('StrikeLaunch(leader, STRIKES[1])')
assert 'deja detruit' in ev('GMSG.L') and ev('Ops["Petrol Strike"]') is None

# Naval : active Admiral, cible le Kuznetsov seul ; plus aucun membre en slot pendant 10 min = fermee
ev('''(function()
  ACTIVATED = 0
  ADMIRAL = { activate = function() ACTIVATED = ACTIVATED + 1 end,
              getUnits = function() return { obj("REZKY", 0, 0), obj("CV_1143_5", 0, 0) } end }
  StrikeLaunch(leader, STRIKES[2])
end)()''')
assert ev('ACTIVATED') == 1 and ev('Ops["HOST Naval AERA"].left') == 1
ev('NavalHost()'); assert ev('ACTIVATED') == 1
lua.execute('UNITS = {}'); assert 'venir au moins une fois' in ev('GMSG.L'); ev('StrikeTick(Ops["HOST Naval AERA"])'); lua.execute('NOW = NOW + 601'); ev('StrikeTick(Ops["HOST Naval AERA"])')
assert ev('Ops["HOST Naval AERA"]') is None

# Interception : tir non autorise d'un membre = 0 pt ; pilote hors mission = kill normal ; autorise = bonus a tous les membres
lua.execute('''function ic(state)
  Icpt = { def = { label = "Yak-40", bonus = 5 }, unitName = "T", state = state, op = OpStart(ICPT_LABEL, "b", leader) }
  Icpt.op.members.Bravo = true
  Icpt.op.present.Alpha, Icpt.op.present.Bravo = true, true
end''')
ev('ic("silent")')
assert ev('IcptKillAllowed({ TgtUnitName = "T" }, "Alpha")') is False and ev('Icpt') is None
ev('ic("silent")')
assert ev('IcptKillAllowed({ TgtUnitName = "T" }, "Inconnu")') is True and ev('Icpt') is None
lua.execute('AWARD = {}'); ev('ic("hostile")')
assert ev('IcptKillAllowed({ TgtUnitName = "T" }, "Bravo")') is True
assert ev('AWARD.Alpha') == 5 and ev('AWARD.Bravo') == 5 and ev('Icpt') is None
# autre avion que la cible : aucun effet
ev('ic("silent")')
assert ev('IcptKillAllowed({ TgtUnitName = "autre" }, "Alpha")') is True and ev('Icpt') is not None

# Anti-triche : membre vivant jamais venu sur zone = pas de bonus, et il est nomme ; personne sur zone = aucun bonus
lua.execute('''AWARD = {}
RO = { members = { Alpha = true, Bravo = true }, present = { Alpha = true } }
RT = OpReward(RO, 50)
RO2 = { members = { Bravo = true }, present = {} }
RT2 = OpReward(RO2, 50)''')
assert ev('AWARD.Alpha') == 50 and ev('AWARD.Bravo') is None
assert '+50 pts pour Alpha' in ev('RT') and 'jamais venu sur zone : Bravo' in ev('RT') and 'Aucun bonus' in ev('RT2')

# Punition du Tu-95 abattu sans autorisation
lua.execute('''
TASKS, SPAWNS = {}, {}
function fakeEsc()
  local g = { unit = { getPoint = function() return { x = 1, y = 2, z = 3 } end } }
  function g:OptionROEWeaponFree() TASKS[#TASKS + 1] = "free" end
  function g:SetTask(t) TASKS[#TASKS + 1] = t.id end
  return g
end
function GroupUnit(g) return g and g.unit end
function Bearing() return 90 end
function Wp() return {} end
function LandWp() return {} end
Airbase = { getByName = function() return {} end }
SPAWNED = fakeEsc()
function GetSpawner()
  return { InitHeading = function() end, SpawnFromVec3 = function(_, p) SPAWNS[#SPAWNS + 1] = p; return SPAWNED end }
end
TU_SPAWN_M = 15000
SHOOTER = { alive = true, isExist = function(s) return s.alive end, getLife = function() return 10 end, getID = function() return 7 end,
            getPoint = function() return { x = 50000, y = 8000, z = 0 } end, getPosition = function() return { x = { x = 1, z = 0 } } end }
DEF = { speed = 255, home = "Maykop", escort = "E" }
''' + cut('local function TuPunish', '---- Su-34') + '''
_G.TuPunish = TuPunish
''')
# pas de Su-27 en vol : il apparait 15 km derriere le tireur, attaque une seule fois, puis rentre quand le tireur a disparu
lua.execute('Icpt = {}; TuPunish(DEF, SHOOTER)')
assert ev('SPAWNS[1].x') == 35000 and ev('Icpt.escort') is None
assert ev('SCHED()') is not None and ev('SCHED()') is not None and ev('#TASKS') == 2 and ev('TASKS[2]') == 'AttackUnit'
lua.execute('SHOOTER.alive = false')
assert ev('SCHED()') is None and ev('TASKS[3]') == 'Mission'
# Su-27 deja en vol : pas de second avion, il n'est plus rattache a l'interception (IcptEnd ne le rappelle pas)
lua.execute('SHOOTER.alive = true; SPAWNS = {}; TASKS = {}; Icpt = { escort = fakeEsc() }; TuPunish(DEF, SHOOTER)')
assert ev('#SPAWNS') == 0 and ev('Icpt.escort') is None
# seul un membre qui abat le Tu-95 lui-meme declenche la punition
lua.execute('''function ip(tgt, who)
  PUNISHED = false
  Ops[ICPT_LABEL] = nil
  Icpt = { def = { label = "Tu-95", bonus = 10, punish = function() PUNISHED = true end }, unitName = "T", escortName = "S", state = "silent",
           op = OpStart(ICPT_LABEL, "b", leader) }
  IcptKillAllowed({ TgtUnitName = tgt }, who)
  return PUNISHED
end''')
assert ev('ip("T", "Alpha")') is True
assert ev('ip("T", "Inconnu")') is False
assert ev('ip("S", "Alpha")') is False

# Zone CAP
lua.execute('''
UNITS = { player(1, "Alpha"), player(2, "Bravo") }
PlayerLife, AWARD, Ops, HostileGroups = {}, {}, Ops, {}
INZONE, OVER, ROUTES, SPAWNED_CAP = true, false, {}, {}
ZONE = { FindByName = function() return { GetRandomVec2 = function() return { x = 1000, y = 2000 } end,
                                          IsVec2InZone = function() return INZONE end } end }
_DATABASE = { Templates = { Groups = setmetatable({}, { __index = function() return { Template = { route = { points = { { alt = 21000 } } } } } end }) } }
function EniWaveOver() return OVER end
function GetSpawner()
  local s = {}
  function s:InitSpeedMps() return self end
  function s:SpawnFromVec3(v)
    local g = { v = v, unit = { pos = { x = 500000, z = 0 }, inAir = function() return true end } }
    function g.unit.getPoint(u) return u.pos end
    function g:OptionROEWeaponFree() end
    function g:EnRouteTaskEngageTargets() return { id = "EngageTargets", params = {} } end
    function g:SetTask(t) ROUTES[#ROUTES + 1] = t.params.route.points end
    SPAWNED_CAP[#SPAWNED_CAP + 1] = g
    return g
  end
  return s
end
function Wp(x, z) return { x = x, z = z } end
function routeEngages() return ROUTES[#ROUTES][1].task ~= nil end
''')
# rien ne part tant que ni le menu ni une mission ne l'activent
ev('CapTick()'); assert ev('#SPAWNED_CAP') == 0
# la mission lance les vagues : un seul groupe, altitude bornee, route avec engagement ; pas de 2e vague tant que la 1re vit
ev('CapLaunch(leader)')
ev('CapTick()'); ev('CapTick()')
assert ev('#SPAWNED_CAP') == 1 and ev('#HostileGroups') == 1 and ev('SPAWNED_CAP[1].v.y') == 12000 and ev('#ROUTES') == 1 and ev('routeEngages()')
assert ev('Ops.CAP.present.Alpha') is True
# sortie de zone : un seul ordre de retour, sans engagement
lua.execute('INZONE = false'); ev('CapTick()'); ev('CapTick()')
assert ev('#ROUTES') == 2 and not ev('routeEngages()')
# revenu dans la zone : reprise de la patrouille seulement apres le delai
lua.execute('INZONE = true; SPAWNED_CAP[1].unit.pos = { x = 500000, z = 0 }'); ev('CapTick()')
assert ev('#ROUTES') == 2
lua.execute('NOW = NOW + 91'); ev('CapTick()')
assert ev('#ROUTES') == 3 and ev('routeEngages()')
# point de patrouille atteint : il en prend un autre
lua.execute('SPAWNED_CAP[1].unit.pos = { x = 1000, z = 2000 }'); ev('CapTick()')
assert ev('#ROUTES') == 4
# kills : hors mission et autre avion ignores, les 5 kills des membres valident ; +30 seulement a qui est venu dans la zone
ev('CapKill({ TgtUnitName = "mig29 cap#001-01" }, "Inconnu")'); ev('CapKill({ TgtUnitName = "T" }, "Alpha")'); ev('CapKill({ TgtUnitName = "autre#001-01" }, "Alpha")')
assert ev('Ops.CAP.kills') == 0
lua.execute('Ops.CAP.members.Bravo = true; Ops.CAP.present.Bravo = nil')
for _ in range(4): ev('CapKill({ TgtUnitName = "mig29 cap#001-01" }, "Alpha")')
assert ev('Ops.CAP.kills') == 4
lua.execute('UNITS = {}')
ev('CapKill({ TgtUnitName = "M2000 Cap#002-01" }, "Bravo")')
assert ev('Ops.CAP') is None and ev('AWARD.Alpha') == 30 and ev('AWARD.Bravo') is None
# fin de mission : la vague restante rentre, plus de nouvelle ; le menu relance les vagues
lua.execute('OVER = true'); n = ev('#ROUTES'); ev('CapTick()')
assert ev('#SPAWNED_CAP') == 1 and ev('CapWave') is None and ev('#ROUTES') == n + 1
lua.execute('CapActive, OVER = true, false'); ev('CapTick()')
assert ev('#SPAWNED_CAP') == 2

# Voix : chaque numero utilise existe dans VOIX et son .ogg est verrouille dans voix-ia/validees
codes = set(re.findall(r'"(c\d\d)"', src))
voix = dict(re.findall(r'(c\d\d) = \{ "([^"]+)"', src))
assert codes and codes <= set(voix), codes - set(voix)
valid = pathlib.Path(__file__).parent.parent.parent / 'voix-ia' / 'validees'
assert all((valid / f).exists() for f in voix.values())
# une liste se joue a la suite (duree + 0,5 s), aux seuls membres ; pas de voix = rien
lua.execute('''
PLAYED, CALLS = {}, {}
local sf = timer.scheduleFunction
timer.scheduleFunction = function(f, _, t) CALLS[#CALLS + 1] = { f = f, t = t } end
trigger.action = { outSoundForUnit = function(id, file) PLAYED[#PLAYED + 1] = id .. file end }
UNITS = { player(1, "Alpha"), player(2, "Bravo") }
OpVoice({ members = { Alpha = true } }, { "c02", "c03" })
OpVoice({ members = { Alpha = true } }, nil)
for _, c in ipairs(CALLS) do c.f() end
timer.scheduleFunction = sf
''')
assert ev('#PLAYED') == 2 and ev('PLAYED[1]') == '1c02_chasseur_rf59_1.ogg' and ev('PLAYED[2]') == '1c03_rf59_mensonge.ogg'
assert abs(ev('CALLS[2].t - CALLS[1].t') - 8.6) < 1e-9

# le script complet reste compilable
lua.compile(src)
print('OK')
