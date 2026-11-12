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
world = { getAirbases = function() return STATICS end }  -- derricks = heliports, donc des Airbase pour DCS
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
BASES = { { name = "Gudauta", x = 0, y = 0, groups = { "renfort" } }, { name = "Sochi", x = 100000, y = 0, groups = {} },
          { name = "Anapa", x = 200000, y = 0, groups = {} } }
BASE_RADIUS = 8000
REFRESH = 0
function RefreshMissionMenus() REFRESH = REFRESH + 1 end
function Bearing(from, to) return math.floor(math.deg(math.atan2(to.z - from.z, to.x - from.x)) + 360.5) % 360 end
Airbase = { Category = { AIRDROME = 0 } }
function obj(typeName, x, z)
  local o = { life = 10, active = true }
  function o:isActive() return self.active end
  function o:isExist() return true end
  function o:getLife() return self.life end
  function o:getTypeName() return typeName end
  function o:getName() return typeName .. x .. "/" .. z end
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
_G.OpVoice, _G.BASE_DEFS, _G.CONVOY_DEFS, _G.NORTH_DEF, _G.NOT_BASE = OpVoice, BASE_DEFS, CONVOY_DEFS, NORTH_DEF, NOT_BASE
_G.NORTH_CONVOYS, _G.NORTH_LABEL, _G.GroupTargets, _G.GroupMsg, _G.CAP_LABEL = NORTH_CONVOYS, NORTH_LABEL, GroupTargets, GroupMsg, CAP_LABEL
function enter(g, code) CodeJoin(g, code) end
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
# une cible dont la vie vaut deja 0 au lancement reste comptee comme intacte
lua.execute('ZERO = obj("Oil rig", -274500, 495500); ZERO.life = 0; table.insert(STATICS, ZERO)')
assert ev('#STRIKES[1].targets()') == 3
lua.execute('table.remove(STATICS)')
code = ev('Ops["Petrol Strike"].code')
assert len(code) == 2 and '0' not in code and code in ev('GMSG.L')
assert 'partage selon les cibles' in ev('GMSG.L')

# deuxieme lancement refuse ; un mauvais code ne rejoint rien
ev('StrikeLaunch(wing, STRIKES[1])')
assert 'deja en cours' in ev('GMSG.W')
bad = '11' if code != '11' else '22'
ev(f'enter(wing, "{bad}")')
assert 'INCONNU' in ev('GMSG.W') and ev('members(Ops["Petrol Strike"])') == 'Alpha'

# le bon code rejoint et donne le briefing
ev(f'enter(wing, "{code}")')
assert ev('members(Ops["Petrol Strike"])') == 'Alpha,Bravo'
assert 'MISSION REJOINTE' in ev('GMSG.W') and code in ev('GMSG.W')

# cibles : progression, puis bonus egal a chaque membre vivant (Bravo est mort : rien), mission fermee
# un statique compte comme intact meme avec une vie a 0 (cas vu en jeu) ; detruit = evenement Dead
# detruit = vie qui tombe a 0 depuis le lancement, ou evenement Dead
lua.execute('STATICS[1].life = 0'); ev('StrikeTick(Ops["Petrol Strike"])')
assert 'venir au moins une fois' not in ev('GMSG.W')  # Petrol : aucune condition de zone (Alpha n'y est jamais alle)
assert ev('Ops["Petrol Strike"].left') == 1
lua.execute('PlayerLife.Bravo = { dead = true }'); lua.execute('StrikeDead[STATICS[2]:getName()] = true'); ev('StrikeTick(Ops["Petrol Strike"])')
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
lua.execute('UNITS = {}'); assert 'partage selon' in ev('GMSG.L'); ev('StrikeTick(Ops["HOST Naval AERA"])'); lua.execute('NOW = NOW + 601'); ev('StrikeTick(Ops["HOST Naval AERA"])')
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
    function g:GetName() return "cap" end
    function g:Destroy() DESTROYED = (DESTROYED or 0) + 1 end
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
# parti en poursuite : encore hors zone 2 min apres : supprime (et pas avant)
lua.execute('INZONE = false'); ev('CapTick()'); lua.execute('NOW = NOW + 119'); ev('CapTick()')
assert ev('DESTROYED') is None
lua.execute('NOW = NOW + 2'); ev('CapTick()')
assert ev('DESTROYED') == 1
lua.execute('INZONE = true'); ev('CapTick()')
# kills : hors mission et autre avion ignores, les 5 kills des membres valident ; bonus au prorata (comme le KillHandler : OpCredit puis CapKill)
lua.execute('function kill(unit, who) OpCredit({ TgtUnitName = unit }, { who }); CapKill({ TgtUnitName = unit }, who) end')
ev('kill("mig29 cap#001-01", "Inconnu")'); ev('kill("T", "Alpha")'); ev('kill("autre#001-01", "Alpha")')
assert ev('Ops.CAP.kills') == 0 and ev('Ops.CAP.credit.Alpha') is None
lua.execute('Ops.CAP.members.Bravo = true; Ops.CAP.members.Charlie = true')
for _ in range(4): ev('kill("mig29 cap#001-01", "Alpha")')
assert ev('Ops.CAP.kills') == 4
lua.execute('UNITS = {}')
ev('kill("M2000 Cap#002-01", "Bravo")')
# 2 tireurs : cagnotte 60, Alpha 4/5 = 48, Bravo 1/5 = 12 ; Charlie (membre sans kill) : rien
assert ev('Ops.CAP') is None and ev('AWARD.Alpha') == 48 and ev('AWARD.Bravo') == 12 and ev('AWARD.Charlie') is None
# fin de mission : la vague restante rentre, plus de nouvelle ; le menu relance les vagues
lua.execute('OVER = true'); n = ev('#ROUTES'); ev('CapTick()')
assert ev('#SPAWNED_CAP') == 1 and ev('CapWave') is None and ev('#ROUTES') == n + 1
lua.execute('CapActive, OVER = true, false'); ev('CapTick()')
assert ev('#SPAWNED_CAP') == 2

# Bases et convois (11/11)
lua.execute('''
AWARD, PlayerLife, ALL = {}, {}, {}
UNITS = { player(1, "Alpha"), player(2, "Bravo") }
function ground(name, units) local g = { units = units } function g:getName() return name end function g:getUnits() return self.units end return g end
G1 = ground("G1", { obj("T-72", 100, 100), obj("ZU-23", 200, 0) })
REN = ground("renfort", { obj("BTR", 50, 50) })
FAR = ground("loin", { obj("BTR", 50000, 0) })
OFF = ground("off", { obj("BTR", 10, 10) }); OFF.units[1].active = false
SO = ground("S1", { obj("T-90", 100000, 10) })
CV = ground("Gudauta convoie", { obj("Ural", 30000, 0) }); CV.units[1].active = false
N1 = ground("convoie-1", { obj("T-72B3", 90000, 9000), obj("ZU", 90000, 9100), obj("KS-19", 90000, 9200), obj("T-72B3", 90000, 9300) })
GROUPS = { G1, REN, FAR, OFF, SO, CV, N1 }
Group.Category = { GROUND = 2 }
coalition.getGroups = function() return GROUPS end
Group.getByName = function(n) for _, g in ipairs(GROUPS) do if g:getName() == n then return g end end end
AB = { getDesc = function() return { category = 0 } end, getPoint = function() return { x = 100000, z = 0 } end, getName = function() return "Maykop" end }
world.getAirbases = function() return { AB } end
Airbase.Category = { AIRDROME = 0 }
MESSAGE = { New = function(_, text) return { ToGroup = function(_, g) GMSG[g:GetName()] = text end, ToCoalition = function() end,
                                             ToAll = function() ALL[#ALL + 1] = text end } end }
function credit(o, who) OpCredit({ TgtUnitName = o:getName() }, { who }) end
''')
# renforts, convois et unites inactives ne comptent jamais dans une base ; hors rayon non plus
assert ev('NOT_BASE["renfort"]') and ev('NOT_BASE["Gudauta convoie"]') and ev('NOT_BASE["convoie-1"]')
assert ev('CampaignStage') == 1
ev('StrikeLaunch(leader, BASE_DEFS[1])')
assert ev('Ops["Base Gudauta"].left') == 2
ev(f'enter(wing, Ops["Base Gudauta"].code)')
# Alpha detruit une cible ; la 2e tombe sous les coups d'un non-membre : hors calcul, Alpha prend toute la cagnotte (1 tireur = 30)
lua.execute('credit(G1.units[1], "Alpha"); G1.units[1].life = 0'); ev('StrikeTick(Ops["Base Gudauta"])')
assert 'reste 1' in ev('SENT[#SENT].text')
lua.execute('REFRESH = 0; StrikeDead[G1.units[2]:getName()] = true'); ev('StrikeTick(Ops["Base Gudauta"])')
assert ev('Ops["Base Gudauta"]') is None and ev('AWARD.Alpha') == 30 and ev('AWARD.Bravo') is None
assert 'Aucune cible detruite, pas de bonus : Bravo' in ev('SENT[#SENT].text')
assert ev('CampaignStage') == 2 and 'Gudauta est tombee' in ev('ALL[1]') and 'Sochi' in ev('ALL[1]') and ev('REFRESH') == 1
# relancer Gudauta : detruite, la campagne ne recule pas
ev('StrikeLaunch(leader, BASE_DEFS[1])'); assert 'deja detruit' in ev('GMSG.L') and ev('CampaignStage') == 2
# Sochi videe sans mission : son lancement ouvre Anapa ; Anapa vide : victoire
lua.execute('StrikeDead[SO.units[1]:getName()] = true'); ev('StrikeLaunch(leader, BASE_DEFS[2])')
assert ev('CampaignStage') == 3 and 'Anapa' in ev('ALL[2]')
ev('StrikeLaunch(leader, BASE_DEFS[3])'); assert ev('CampaignStage') == 4 and 'victoire' in ev('ALL[3]')

# Convoi de renfort : aucune cible tant qu'il n'est pas active
assert ev('#CONVOY_DEFS[1].targets()') == 0
lua.execute('CV.units[1].active = true'); assert ev('#CONVOY_DEFS[1].targets()') == 1

# Convoi nord : position au briefing ; prorata avec un membre mort (sa part est perdue, cagnotte 20 x 2 tireurs)
lua.execute('AWARD = {}'); ev('StrikeLaunch(leader, NORTH_DEF)')
assert 'environ 7 NM au 090 de Maykop' in ev('GMSG.L')  # cap 090 : Bearing remplace par le test de la punition and ev('Ops["Convoi nord"].left') == 4
ev(f'enter(wing, Ops["Convoi nord"].code)')
lua.execute('''for i = 1, 3 do credit(N1.units[i], "Alpha"); N1.units[i].life = 0 end
credit(N1.units[4], "Bravo"); N1.units[4].life = 0; PlayerLife.Bravo = { dead = true }''')
ev('StrikeTick(Ops["Convoi nord"])')
assert ev('Ops["Convoi nord"]') is None and ev('AWARD.Alpha') == 30 and ev('AWARD.Bravo') is None
assert 'Alpha +30 pts (75 %)' in ev('SENT[#SENT].text')
lua.execute('PlayerLife.Bravo = nil')
# plus aucun convoi nord vivant : rien a lancer
ev('StrikeLaunch(leader, NORTH_DEF)'); assert 'deja detruit' in ev('GMSG.L')

# HOST Naval : un kill d'escorte du groupe Admiral compte dans les parts
lua.execute('''ADM = ground("Admiral", { obj("CV_1143_5", 0, 0), obj("REZKY", 0, 10) }); table.insert(GROUPS, ADM)''')
ev('StrikeLaunch(leader, STRIKES[2])')
assert ev('Ops["HOST Naval AERA"].left') == 1
lua.execute('OpCredit({ TgtUnitName = "escorte", TgtGroupName = "Admiral" }, { "Alpha" }); OpCredit({ TgtUnitName = "x", TgtGroupName = "autre" }, { "Alpha" })')
assert ev('Ops["HOST Naval AERA"].credit.Alpha') == 1
lua.execute('Ops["HOST Naval AERA"] = nil')

# Factory Strike : statiques industriels du cercle GCI-2 seulement (pas les sacs de sable, ni hors cercle), kill GCI-2 credite
lua.execute('''STATICS = { obj("Tank 2", -33689, 587000), obj(".Command Center", -33500, 587300), obj("Sandbag_02", -33689, 587167),
                         obj("Tank 2", -30000, 587167) }''')
ev('StrikeLaunch(leader, STRIKES[3])')
assert ev('STRIKES[3].label') == 'Factory Strike' and ev('Ops["Factory Strike"].left') == 2
lua.execute('OpCredit({ TgtUnitName = "GCI-2-28", TgtGroupName = "GCI-2" }, { "Alpha" })')
assert ev('Ops["Factory Strike"].credit.Alpha') == 1
lua.execute('Ops["Factory Strike"] = nil')

# Menus BASES / CONVOIS : seule la base debloquee, convois en route seulement, refaits a chaque RefreshMissionMenus
lua.execute('''
function menu(text, parent)
  local m = { text = text, items = {} }
  if parent then parent.items[#parent.items + 1] = m end
  function m:RemoveSubMenus() self.items = {} end
  function m:Remove() end
  return m
end
MENU_GROUP = { New = function(_, g, text, parent) return menu(text, parent) end }
MENU_GROUP_COMMAND = { New = function(_, g, text, parent) return menu(text, parent) end }
PlayerMissionMenus, PlayerCodeMenus = {}, {}
function leader:GetDCSObject() return { getCoalition = function() return 2 end } end
function texts(m) local t = {} for _, i in ipairs(m.items) do t[#t + 1] = i.text end return table.concat(t, "|") end
''' + cut('-- BASES et CONVOIS changent', '------------------------------------------------------------\n-- MENUS F10 COALITION BLEUE') + '''
_G.PlayerDynMenus = PlayerDynMenus
CampaignStage = 1
for _, u in ipairs(G1.units) do StrikeDead[u:getName()] = nil end
CV.units[1].active = false
N1.units[1].life, StrikeDead[N1.units[1]:getName()] = 10, nil
AddMissionMenusForGroup(leader, "L")
''')
assert ev('texts(PlayerDynMenus.L.bases)') == 'Base Gudauta'
assert ev('texts(PlayerDynMenus.L.convois)') == 'Convoi nord'
assert ev('texts(PlayerDynMenus.L.root)') == 'BASES|CONVOIS|STRIKE|NAVAL|AIR|Rappel de mes missions'
assert ev('texts(PlayerDynMenus.L.root.items[3])') == 'Petrol Strike|Factory Strike'
assert ev('texts(PlayerDynMenus.L.root.items[4])') == 'HOST Naval AERA'
assert ev('#PlayerCodeMenus.L.items') == 9 and ev('#PlayerCodeMenus.L.items[4].items') == 9 and ev('PlayerCodeMenus.L.items[4].items[7].text') == '47'
lua.execute('CampaignStage = 2; CV.units[1].active = true; RefreshMissionMenus()')
assert ev('texts(PlayerDynMenus.L.bases)') == 'Base Sochi' and ev('texts(PlayerDynMenus.L.convois)') == 'Convoi Gudauta|Convoi nord'
lua.execute('CampaignStage = 4; CV.units[1].active = false; StrikeDead[N1.units[1]:getName()] = true; RefreshMissionMenus()')
assert ev('texts(PlayerDynMenus.L.bases)') == 'Campagne terminee' and ev('texts(PlayerDynMenus.L.convois)') == 'Aucun convoi en route'
# menu remplace (nouvelle apparition) : l'ancienne entree n'est plus mise a jour
lua.execute('PlayerMissionMenus.L = {}; RefreshMissionMenus()')
assert ev('PlayerDynMenus.L') is None

# Voix : chaque numero utilise existe dans VOIX et son .ogg est verrouille dans voix-ia/validees
codes = set(re.findall(r'"(c\d\d)"', src))
voix = dict(re.findall(r'(c\d\d) = \{ "([^"]+)"', src))
assert codes and codes <= set(voix), codes - set(voix)
valid = pathlib.Path(__file__).parent.parent.parent / 'voix-ia' / 'validees'
assert all((valid / f).exists() for f in voix.values())
assert all((valid / f).exists() for f in re.findall(r'"(c\d\d_\w+\.ogg)"', src))  # voix jouees hors VOIX (accueil)
# 12/11 : chaque base a sa voix de briefing et de chute, chaque convoi et Factory brief + reussite
assert [ev(f'BASE_DEFS[{i}].voice.brief') for i in (1, 2, 3)] == ['c32', 'c34', 'c36']
assert [ev(f'CONVOY_DEFS[{i}].voice.brief') for i in (1, 2, 3)] == ['c38', 'c39', 'c40'] and ev('CONVOY_DEFS[1].voice.success') == 'c42'
assert ev('NORTH_DEF.voice.brief') == 'c41' and ev('STRIKES[3].voice.brief') == 'c43' and ev('STRIKES[3].voice.success') == 'c44'
assert all(f'fallen = "c{n}"' in src for n in (33, 35, 37))
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

# interception (11/11) : briefing + code envoyes a tous les pilotes, pas seulement au groupe du lanceur
lua.execute('''
ALL, GMSG = {}, {}
MESSAGE = { New = function(_, text) return { ToGroup = function(_, g) GMSG[g:GetName()] = text end,
                                             ToAll = function() ALL[#ALL + 1] = text end } end }
PUB = OpStart("TEST PUBLIC", "Tu-95 en approche.", grp("Lanceur", "Alpha"), nil, nil, true)
''')
assert ev('#ALL') == 1 and ev('GMSG.Lanceur') is None
assert f"CODE DE LA MISSION : {ev('PUB.code')}" in ev('ALL[1]') and 'Tous les pilotes' in ev('ALL[1]')
assert ev('PUB.members.Alpha') is True   # le lanceur reste membre ; les autres rejoignent avec le code
lua.execute('GMSG = {}; PRIV = OpStart("TEST PRIVE", "b", grp("L2", "Bravo"))')
assert ev('#ALL') == 1 and 'Tes equipiers' in ev('GMSG.L2')   # les autres missions : groupe du lanceur
assert re.search(r'Icpt\.op = OpStart\(ICPT_LABEL, [^\n]*, true\)', src)   # l'interception utilise bien le mode public

# le script complet reste compilable
lua.compile(src)
print('OK')
