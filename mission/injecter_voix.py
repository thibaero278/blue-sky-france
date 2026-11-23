r"""Remplace des voix (.ogg) dans la .miz DAY par celles d'un dossier (23/11 : voix plus fortes, accueil refait), DCS ferme.
Seules les entrees .ogg qui existent deja dans la .miz et dans le dossier sont remplacees (memes noms : les declencheurs
de l'editeur continuent de les trouver). Sauvegarde horodatee dans bakup\ a cote de la .miz, archive refaite dans un
fichier temporaire puis relue (memes entrees, voix identiques au dossier, le reste identique a avant) avant de remplacer.
Usage : python injecter_voix.py <dossier des .ogg> [mission.miz]
"""
import hashlib
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

MIZ = Path(os.environ["USERPROFILE"]) / r"Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\Blue Sky Multi-joueur DAY_Caucasus.miz"

src = Path(sys.argv[1])
miz = Path(sys.argv[2]) if len(sys.argv) > 2 else MIZ
if subprocess.run(["tasklist", "/FI", "IMAGENAME eq DCS*"], capture_output=True, text=True).stdout.count("DCS") > 0:
    sys.exit("DCS est ouvert : ferme-le (et l'editeur) avant d'injecter.")
voix = {p.name: p.read_bytes() for p in src.glob("*.ogg")}
md5 = lambda b: hashlib.md5(b).hexdigest()

with zipfile.ZipFile(miz) as z:
    avant = {i.filename: z.read(i) for i in z.infolist()}
    infos = z.infolist()
cibles = {n for n in avant if n.lower().endswith(".ogg") and n.split("/")[-1] in voix}
if not cibles:
    sys.exit("Aucune voix du dossier n'existe dans la .miz : rien fait.")

bak = miz.parent / "bakup" / f"{miz.stem}_{time.strftime('%Y-%m-%d_%H-%M-%S')}.miz.bak"
bak.parent.mkdir(exist_ok=True)
shutil.copy2(miz, bak)
print("Sauvegarde :", bak)

tmp = miz.with_suffix(".miz.tmp")
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
    for i in infos:
        data = voix[i.filename.split("/")[-1]] if i.filename in cibles else avant[i.filename]
        z.writestr(i, data, compress_type=zipfile.ZIP_DEFLATED)

with zipfile.ZipFile(tmp) as z:
    assert z.testzip() is None, "archive abimee"
    apres = {i.filename: z.read(i) for i in z.infolist()}
assert list(apres) == list(avant), "entrees differentes"
for n in avant:
    attendu = voix[n.split("/")[-1]] if n in cibles else avant[n]
    assert md5(apres[n]) == md5(attendu), n
os.replace(tmp, miz)
print(f"Archive OK : {len(apres)} entrees, {len(cibles)} voix remplacees, le reste identique ; md5 .miz {md5(miz.read_bytes())}")
