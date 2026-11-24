r"""Refait les versions meteo de la mission DAY (dossier "Meteo dif" a cote de la .miz DAY), DCS ferme.
Chaque version = la DAY actuelle (script, voix, kneeboard, unites) + la meteo, la date et l'heure de depart de
l'ancienne version du meme nom (blocs ["weather"], ["date"] et ligne ["start_time"] de la table mission).
Comparaison du 24/11 : c'etaient les seules vraies differences (le reste : bruit de l'editeur).
A relancer apres chaque injection dans la DAY. Sauvegarde horodatee de chaque ancienne version dans "Meteo dif\bakup\",
nouvelle archive verifiee (memes entrees que la DAY, tout identique sauf la table mission, et dans celle-ci seuls
weather / date / start_time different de la DAY et sont egaux a ceux de l'ancienne version) avant de remplacer.
Usage : python fabriquer_meteo.py [dossier de la DAY]
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

DOSSIER = Path(sys.argv[1]) if len(sys.argv) > 1 else \
    Path(os.environ["USERPROFILE"]) / r"Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi"
DAY = DOSSIER / "Blue Sky Multi-joueur DAY_Caucasus.miz"
METEO = DOSSIER / "Météo dif"
LUAE = r"C:\Program Files\Eagle Dynamics\DCS World\bin\luae.exe"
BLOCS = [re.compile(r'^\t\["weather"\] = \n.*?^\t\}, -- end of \["weather"\]\n', re.S | re.M),
         re.compile(r'^\t\["date"\] = \n.*?^\t\}, -- end of \["date"\]\n', re.S | re.M),
         re.compile(r'^\t\["start_time"\] = [^\n]*\n', re.M)]

# Verification : charge les trois tables mission dans luae, compare cle par cle (hors weather/date/start_time)
VERIF = r'''
local function load(p) local env = {} local f = assert(loadfile(p)) setfenv(f, env) f() return env.mission end
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {} for k in pairs(v) do keys[#keys+1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local t = {} for _, k in ipairs(keys) do t[#t+1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(t, ",") .. "}"
end
local day, old, new = load(arg[1]), load(arg[2]), load(arg[3])
local METEO = { weather = true, date = true, start_time = true }
for k, v in pairs(day) do
  if not METEO[k] and ser(v) ~= ser(new[k]) then error("cle " .. k .. " differente de la DAY") end
end
for k in pairs(new) do if day[k] == nil then error("cle " .. k .. " en trop") end end
for k in pairs(METEO) do if ser(new[k]) ~= ser(old[k]) then error(k .. " pas celui de l'ancienne version") end end
print("ok")
'''

if subprocess.run(["tasklist", "/FI", "IMAGENAME eq DCS*"], capture_output=True, text=True).stdout.count("DCS") > 0:
    sys.exit("DCS est ouvert : ferme-le (et l'editeur) d'abord.")

with zipfile.ZipFile(DAY) as z:
    infos = z.infolist()
    day_data = {i.filename: z.read(i) for i in infos}
day_mission = day_data["mission"].decode("utf-8")
for b in BLOCS:
    assert len(b.findall(day_mission)) == 1, f"DAY : bloc introuvable ou double ({b.pattern[:20]})"

bak = METEO / "bakup"
bak.mkdir(exist_ok=True)
stamp = time.strftime("%Y-%m-%d_%H-%M-%S")
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    (tmp / "verif.lua").write_text(VERIF, encoding="utf-8")
    (tmp / "day.lua").write_bytes(day_data["mission"])
    for old in sorted(METEO.glob("*.miz")):
        with zipfile.ZipFile(old) as z:
            old_mission = z.read("mission").decode("utf-8")
        new_mission = day_mission
        for b in BLOCS:
            found = b.findall(old_mission)
            assert len(found) == 1, f"{old.name} : bloc introuvable ou double ({b.pattern[:20]})"
            new_mission = b.sub(lambda _m: found[0], new_mission, count=1)
        (tmp / "old.lua").write_text(old_mission, encoding="utf-8")
        (tmp / "new.lua").write_text(new_mission, encoding="utf-8")
        r = subprocess.run([LUAE, str(tmp / "verif.lua"), str(tmp / "day.lua"), str(tmp / "old.lua"), str(tmp / "new.lua")],
                           capture_output=True, text=True)
        assert r.stdout.strip() == "ok", f"{old.name} : verification ratee : {r.stdout} {r.stderr}"

        out = tmp / old.name
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            for i in infos:
                data = new_mission.encode("utf-8") if i.filename == "mission" else day_data[i.filename]
                z.writestr(i, data, compress_type=zipfile.ZIP_DEFLATED)
        with zipfile.ZipFile(out) as z:
            assert z.testzip() is None and [i.filename for i in z.infolist()] == [i.filename for i in infos]
            assert all(z.read(n) == day_data[n] for n in day_data if n != "mission")
        shutil.copy2(old, bak / f"{old.stem}_{stamp}.miz.bak")
        shutil.move(str(out), old)
        print(f"OK {old.name} : meteo, date et heure gardees, le reste = DAY")
print(f"Sauvegardes : {bak}")
