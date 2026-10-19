"""Lecture de Scores.lua (écrit par mission/script Caucase.lua) et grades Blue Sky."""

import os
import re
from datetime import datetime, timezone

# Mêmes paliers que la table RANKS de script Caucase.lua et que web/js/data.js (à garder synchronisés).
RANKS = [
    (0, 'Aspirant'), (10, 'Sous-lieutenant'), (30, 'Lieutenant'), (60, 'Capitaine'), (120, 'Commandant'),
    (200, 'Lieutenant-colonel'), (350, 'Colonel'), (600, 'Général de brigade aérienne'),
    (1000, 'Général de division aérienne'), (1800, 'Général de corps aérien'), (3000, "Général d'armée aérienne"),
]

_ENTRY = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*\{(.*?)\}', re.S)
_FIELD = re.compile(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|[-\d.]+)')


def _unlua(s: str) -> str:
    # chaîne Lua %q (octets UTF-8 bruts + échappements \" \\ \n) → str Python
    return s.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8')


def read_scores(path: str) -> dict[str, dict] | None:
    """{pseudo: {champ: valeur}} ; None si le fichier est absent ou en cours d'écriture."""
    try:
        with open(path, encoding='utf-8') as f:
            text = f.read()
    except (OSError, UnicodeDecodeError):
        return None
    if not text.rstrip().endswith('}'):
        return None  # écriture en cours : on relira au prochain tour
    pilots = {}
    for name, body in _ENTRY.findall(text):
        p = {}
        for key, val in _FIELD.findall(body):
            p[key] = _unlua(val[1:-1]) if val.startswith('"') else (float(val) if '.' in val else int(val))
        pilots[_unlua(name)] = p
    return pilots


def mtime(path: str) -> datetime | None:
    try:
        return datetime.fromtimestamp(os.path.getmtime(path), timezone.utc)
    except OSError:
        return None


def rank_for(points: float) -> tuple[str, tuple[int, str] | None]:
    """Grade correspondant aux points, et palier suivant (ou None)."""
    idx = 0
    for i, (low, _) in enumerate(RANKS):
        if (points or 0) >= low:
            idx = i
    return RANKS[idx][1], RANKS[idx + 1] if idx + 1 < len(RANKS) else None


def hours(seconds: float) -> str:
    s = int(seconds or 0)
    return f'{s // 3600} h {s % 3600 // 60:02d}'


def find_pilot(scores: dict[str, dict], name: str) -> tuple[str, dict] | None:
    """Pseudo exact, sinon premier pseudo qui contient le texte (sans tenir compte de la casse)."""
    if name in scores:
        return name, scores[name]
    low = name.lower()
    for key, val in scores.items():
        if low in key.lower():
            return key, val
    return None
