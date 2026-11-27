r"""Passe le groupe TRAIN de la DAY du bleu (USA) au rouge (CJTF Red), en activation retardee (27/11, demande de Thibaud).
Chirurgie sur le texte de la table mission (format de l'editeur garde) : le bloc du groupe est deplace a la fin des groupes
vehicules de CJTF Red, avec ["lateActivation"] = true. Verification : l'ancienne table, transformee a la main en Lua
(groupe retire du bleu, flag ajoute, ajoute au rouge), doit etre identique cle par cle a la nouvelle. DCS ferme obligatoire.
Sauvegarde horodatee dans bakup\ avant de remplacer. Usage : python train_rouge.py [chemin de la .miz DAY]
"""
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

DAY = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(os.environ["USERPROFILE"]) / \
    r"Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\Blue Sky Multi-joueur DAY_Caucasus.miz"
GROUP, RED_COUNTRY = "TRAIN", "CJTF Red"

if subprocess.run(["tasklist", "/FI", "IMAGENAME eq DCS*"], capture_output=True, text=True).stdout.count("DCS") > 0:
    sys.exit("DCS est ouvert : ferme-le (et l'editeur) d'abord.")

from lupa.lua51 import LuaRuntime  # noqa: E402
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
function LOAD(s) local e = {} local f = assert(loadstring(s)) setfenv(f, e) f() return e.mission end
function SER(v)
  if type(v) ~= "table" then return type(v) .. ":" .. (type(v) == "number" and string.format("%.17g", v) or tostring(v)) end
  local keys = {} for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local t = {} for _, k in ipairs(keys) do t[#t + 1] = tostring(k) .. "=" .. SER(v[k]) end
  return "{" .. table.concat(t, ",") .. "}"
end
-- ou est le groupe : coalition, indice du pays, indice du groupe ; et l'indice du pays rouge cible
function FIND(m, name, red)
  local where, target
  for _, side in ipairs({ "blue", "red", "neutrals" }) do
    for ci, c in ipairs((m.coalition[side] or {}).country or {}) do
      for gi, g in ipairs((c.vehicle or {}).group or {}) do
        if g.name == name then where = { side = side, ci = ci, gi = gi, n = #c.vehicle.group } end
      end
      if side == "red" and c.name == red then target = { ci = ci, n = #((c.vehicle or {}).group or {}) } end
    end
  end
  return where, target
end
function EXPECTED(m, w, t, red)
  local src = m.coalition[w.side].country[w.ci].vehicle.group
  local g = table.remove(src, w.gi)
  g.lateActivation = true
  local dst = m.coalition.red.country[t.ci].vehicle.group
  dst[#dst + 1] = g
  return m
end
''')
G = lua.globals()

with zipfile.ZipFile(DAY) as z:
    infos = z.infolist()
    data = {i.filename: z.read(i) for i in infos}
text = data["mission"].decode("utf-8")
old = G.LOAD(text)
w, t = G.FIND(old, GROUP, RED_COUNTRY)
assert w is not None, f"groupe {GROUP} introuvable"
assert t is not None and t.n > 0, f"pays {RED_COUNTRY} sans groupe vehicule"
if w.side == "red":
    sys.exit(f"{GROUP} est deja rouge : rien a faire")
assert w.gi == w.n, f"{GROUP} n'est pas le dernier groupe de son pays ({w.gi}/{w.n}) : renumerotation pas prevue"

lines = text.split("\n")
# fin du bloc : la ligne ["name"] = "TRAIN" au niveau du groupe, puis start_time, puis "}, -- end of [gi]"
end = next(i for i in range(len(lines) - 2) if lines[i].strip() == f'["name"] = "{GROUP}",'
           and lines[i + 1].strip().startswith('["start_time"]') and lines[i + 2].strip() == f"}}, -- end of [{w.gi}]")
end += 2
ind = lines[end][:len(lines[end]) - len(lines[end].lstrip("\t"))]
start = max(i for i in range(end) if lines[i] == f"{ind}[{w.gi}] = ")
assert lines[start + 1] == f"{ind}{{", "ouverture du bloc inattendue"
block = lines[start:end + 1]
rest = lines[:start] + lines[end + 1:]

# cible : derniere ligne "}, -- end of [n]" des groupes vehicules du pays rouge, juste avant "-- end of ["group"]"
# plusieurs sections ont un ["red"] (bullseye, forces...) : celui de la coalition finit juste avant end of ["coalition"]
red_end = next(i for i in range(len(rest) - 1) if rest[i] == '\t\t}, -- end of ["red"]'
               and rest[i + 1] == '\t}, -- end of ["coalition"]')
red_start = max(i for i in range(red_end) if rest[i] == '\t\t["red"] = ')
name_line = next(i for i in range(red_start, red_end) if rest[i].strip() == f'["name"] = "{RED_COUNTRY}",')
country_ind = rest[name_line][:len(rest[name_line]) - len(rest[name_line].lstrip("\t"))]
c_start = max(i for i in range(red_start, name_line) if rest[i] == country_ind[:-1] + "{")
c_end = next(i for i in range(name_line, red_end) if rest[i].startswith(country_ind[:-1] + "}, -- end of ["))
veh_end = next(i for i in range(c_start, c_end) if rest[i] == country_ind + '}, -- end of ["vehicle"]')
grp_end = veh_end - 1
assert rest[grp_end].strip() == '}, -- end of ["group"]' and rest[grp_end - 1] == f"{ind}}}, -- end of [{t.n}]", \
    "fin des groupes vehicules du pays rouge introuvable (indentation differente ?)"

n = t.n + 1
moved = [f"{ind}[{n}] = ", f"{ind}{{", f'{ind}\t["lateActivation"] = true,'] + block[2:-1] + [f"{ind}}}, -- end of [{n}]"]
new_text = "\n".join(rest[:grp_end] + moved + rest[grp_end:])

new = G.LOAD(new_text)
expected = G.EXPECTED(G.LOAD(text), w, t, RED_COUNTRY)
assert G.SER(new) == G.SER(expected), "verification ratee : la nouvelle table differe d'autre chose que le train"
w2, _ = G.FIND(new, GROUP, RED_COUNTRY)
assert w2.side == "red" and new.coalition.red.country[w2.ci].vehicle.group[w2.gi].lateActivation is True

stamp = time.strftime("%Y-%m-%d_%H-%M-%S")
bak = DAY.parent / "bakup" / f"{DAY.stem}_{stamp}_avant-train-rouge.miz.bak"
shutil.copy2(DAY, bak)
tmp = DAY.with_suffix(".miz.tmp")
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
    for i in infos:
        z.writestr(i, new_text.encode("utf-8") if i.filename == "mission" else data[i.filename], compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(tmp) as z:
    assert z.testzip() is None and [i.filename for i in z.infolist()] == [i.filename for i in infos]
    assert all(z.read(k) == v for k, v in data.items() if k != "mission")
    assert z.read("mission").decode("utf-8") == new_text
shutil.move(str(tmp), DAY)
print(f"OK : {GROUP} passe de {w.side} (pays {w.ci}, groupe {w.gi}) a rouge {RED_COUNTRY} (groupe {n}), activation retardee ; "
      f"{len(infos)} entrees, seule la table mission change ; sauvegarde {bak.name}")
