"""Scénarios hors jeu sur le script entier : python site/tools/test_scenarios.py (lupa).

Rejoue chaque site/tools/scenarios/*.lua dans le faux DCS/MOOSE partagé (mocks/), puis retire un à un chaque objet de
la mission pour lister ceux dont l'absence fait disparaître F10 > SPAWN > HOST A/A AERA.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent / 'mocks'))
import fakedcs  # noqa: E402

ko = 0
for path in sorted((pathlib.Path(__file__).parent / 'scenarios').glob('*.lua')):
    fails, trace, desc = fakedcs.run_scenario(path)
    if fails:
        ko += 1
        print(f'ECHEC {path.stem} ({desc})')
        print('\n'.join('  ' + f for f in fails))
        print('  derniers messages :\n' + trace)
    else:
        print(f'OK {path.stem} : {desc}')

# Depuis le 15/11 (statiques de la Croix protégées), aucun objet manquant de la .miz ne doit couper les menus.
# Si la liste n'est plus vide, un objet de la .miz peut arrêter le script : le dire à Thibaud.
broken = fakedcs.probe('SPAWN > HOST A/A AERA > Mig21 > Mig21-1')
if broken:
    ko += 1
    print('ECHEC objets de la .miz dont l\'absence coupe SPAWN > HOST A/A AERA :', sorted(broken))
else:
    print('OK sonde : aucun objet manquant de la .miz ne coupe SPAWN > HOST A/A AERA')

sys.exit(1 if ko else 0)
