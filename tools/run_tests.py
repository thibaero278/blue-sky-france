"""Tous les tests hors jeu en une commande : python site/tools/run_tests.py

Lance en parallèle chaque site/tools/test_*.py (anciens tests + scénarios test_scenarios.py). Code de sortie 1 si un
test échoue : le hook de Claude Code et injecter_script.ps1 s'en servent pour bloquer.
"""
import os
import pathlib
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

HERE = pathlib.Path(__file__).resolve().parent  # lancé via "mission\..\tools" (injecteur) : les tests remontent les dossiers
sys.stdout.reconfigure(encoding='utf-8', errors='replace')


def run(test):
    t0 = time.time()
    r = subprocess.run([sys.executable, str(test)], capture_output=True, encoding='utf-8', errors='replace',
                       env={**os.environ, 'PYTHONIOENCODING': 'utf-8'}, cwd=HERE.parent.parent)
    return test.name, r.returncode, (r.stdout + r.stderr).strip(), time.time() - t0


start = time.time()
tests = sorted(HERE.glob('test_*.py'))
with ThreadPoolExecutor(max_workers=len(tests)) as pool:
    results = list(pool.map(run, tests))

failed = [r for r in results if r[1] != 0]
for name, code, out, dt in results:
    print(f'{"OK   " if code == 0 else "ECHEC"} {name} ({dt:.1f} s)')
    if code != 0:
        print('\n'.join('      ' + line for line in out.splitlines()))
total = time.time() - start
print(f'{len(results) - len(failed)}/{len(results)} tests OK en {total:.1f} s')
if total > 10:
    print('ATTENTION : plus de 10 s, le hook devient lent')
sys.exit(1 if failed else 0)
