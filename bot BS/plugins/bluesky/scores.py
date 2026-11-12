"""Lecture de Scores.lua (écrit par mission/script Caucase.lua) et grades Blue Sky."""

import json
import re
from datetime import date

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


def parse_scores(data: bytes) -> dict[str, dict] | None:
    """{pseudo: {champ: valeur}} ; None si le contenu est illisible ou en cours d'écriture."""
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
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


MAX_FIELDS = {'maxFlightTime', 'maxRefuel', 'maxKillsFlight', 'maxKillsFlightAA', 'maxKillsFlightAS', 'maxKillDistance', 'maxKillDistanceAS', 'maxAltitude', 'maxSpeed'}  # record, pas un compteur : on garde le plus grand
MIN_FIELDS = {'minKillDistance', 'minKillDistanceAS'}  # record où l'on garde le plus petit ; 0 = pas encore de record
RECORD_FIELDS = MAX_FIELDS | MIN_FIELDS


def best(k: str, a: float, b: float) -> float:
    """Meilleure des deux valeurs d'un record."""
    if k in MIN_FIELDS:
        return min(a or b, b or a)  # 0 ignoré : min(0, 50) = 50, min(0, 0) = 0
    return max(a, b)


def merge(total: dict[str, dict], base: dict[str, dict], new: dict[str, dict], first_read: bool,
          alias: dict[str, str] | None = None) -> dict[str, dict]:
    """Total de tous les serveurs + ce que ce serveur a gagné depuis sa dernière lecture (base).

    Le total est rangé par pilote (pseudo actuel, alias) : le gain d'un ancien pseudo est crédité au pilote,
    une seule fois. base et new restent par pseudo (clés du fichier).
    first_read : serveur jamais lu (démarrage de la fusion) → maximum par stat, pseudos du fichier regroupés
    d'abord, pour ne pas compter deux fois une base commune. Une valeur qui baisse n'enlève jamais rien.
    """
    alias = alias or {}
    if first_read:
        new, base = group(new, alias), {}
    out = {n: dict(p) for n, p in total.items()}
    for name, p in new.items():
        b = base.get(name)
        who = alias.get(name, name)
        if who not in out and b is not None and not any(
                isinstance(v, (int, float)) and v > (b.get(k, 0) or 0) for k, v in p.items() if k != 'rang'):
            continue  # pilote supprimé (RGPD) encore dans ce fichier : il ne revient que s'il rejoue
        counters = {k: v for k, v in p.items() if isinstance(v, (int, float)) and k not in RECORD_FIELDS
                    and k != 'rang' and not k.endswith('At')}
        if not first_read and who in out and counters and all(out[who].get(k, 0) == v for k, v in counters.items()):
            continue  # copie exacte du total (Scores.lua remplacé à la main le 11/11, envoi appliqué sans confirmation) : rien de gagné
        t = out.setdefault(who, {})
        for k, v in p.items():
            if k == 'rang' or k.endswith('At'):
                continue
            if not isinstance(v, (int, float)):
                if b is None or b.get(k) != v or k not in t:
                    t[k] = v  # niveau choisi en F10 : la dernière modification gagne
            elif k in RECORD_FIELDS:
                if b is not None and b.get(k) == v:
                    continue  # record déjà lu dans ce fichier : un record effacé sur R2D2 ne revient pas
                old = t.get(k, 0)
                t[k] = best(k, old, v)
                if t[k] != old and not first_read:  # record battu : date du jour (AAAAMMJJ, un nombre passe tel quel dans Sheets)
                    t[k + 'At'] = int(date.today().strftime('%Y%m%d'))
            elif first_read:
                t[k] = max(t.get(k, 0), v)
            else:  # gain depuis la dernière lecture (pilote nouveau sur ce serveur : tout est gagné)
                t[k] = t.get(k, 0) + max(0, v - (b.get(k, 0) if b else 0))
        t['rang'] = rank_for(t.get('points', 0))[0]
    return out


def safe_base(old: dict[str, dict] | None, sent: dict[str, dict]) -> dict[str, dict]:
    """Base d'un serveur pendant un envoi pas (encore) confirmé : on ne sait pas si le fichier a été remplacé.
    Maximum par stat de l'ancienne base et de l'envoi → aucun des deux cas ne compte un gain en double
    (au pire, des gains de ce serveur ne sont comptés qu'une fois l'envoi dépassé)."""
    out = {n: dict(p) for n, p in (old or {}).items()}
    for name, p in sent.items():
        t = out.setdefault(name, {})
        for k, v in p.items():
            o = t.get(k)
            t[k] = max(o, v) if isinstance(v, (int, float)) and isinstance(o, (int, float)) else v
    return out


def resolve(alias: dict[str, str]) -> dict[str, str]:
    """Suit les chaînes A → B → C (boucle = s'arrête) ; retire les pseudos qui pointent sur eux-mêmes."""
    out = {}
    for name in alias:
        seen, now = {name}, alias[name]
        while now in alias and now not in seen:
            seen.add(now)
            now = alias[now]
        if now != name:
            out[name] = now
    return out


def aliases(rows: list[tuple[str, str, str]]) -> dict[str, str]:
    """rows = (ucid, pseudo actuel, pseudo déjà utilisé) → {pseudo: pseudo actuel du même compte DCS}.

    Un pseudo porté par plusieurs UCID (ou dont le pseudo actuel l'est) est ambigu : on n'y touche pas.
    """
    ucids: dict[str, set[str]] = {}
    current: dict[str, str] = {}
    for ucid, now, name in rows:
        if not ucid:
            continue  # UCID vide en base (fourre-tout de DCSServerBot) : pas un compte, rendrait tout pseudo ambigu
        current[ucid] = now
        for n in (now, name):
            if n:
                ucids.setdefault(n, set()).add(ucid)
    out = {}
    for name, owners in ucids.items():
        if len(owners) == 1:
            now = current[next(iter(owners))]
            if now and len(ucids.get(now, ())) == 1:
                out[name] = now
    return out


def group(total: dict[str, dict], alias: dict[str, str]) -> dict[str, dict]:
    """Total par pilote : les pseudos d'un même UCID additionnés sous son pseudo actuel."""
    out: dict[str, dict] = {}
    for name, p in total.items():
        t = out.setdefault(alias.get(name, name), {})
        for k, v in p.items():
            if k == 'rang' or k.endswith('At'):
                continue  # date d'un record : suit le record ci-dessous
            if k in RECORD_FIELDS:
                if k not in t or best(k, t[k], v) != t[k]:
                    t[k] = v
                    if p.get(k + 'At'):
                        t[k + 'At'] = p[k + 'At']
                    else:
                        t.pop(k + 'At', None)
            elif isinstance(v, (int, float)):
                t[k] = t.get(k, 0) + v
            else:
                t.setdefault(k, v)
    for t in out.values():
        t['rang'] = rank_for(t.get('points', 0))[0]
    return out


def for_mission(total: dict[str, dict], alias: dict[str, str]) -> dict[str, dict]:
    """Ce qu'on envoie en jeu (et qui devient la base du serveur une fois confirmé) : le total par pilote.
    Les anciens pseudos ne sont plus envoyés à 0 (une base à 0 recomptait tout si le fichier n'était pas
    remplacé) : push_scores les met dans la liste « remove » et la mission les retire du fichier."""
    return group(total, alias)


def chunks(scores: dict[str, dict], limit: int = 4000) -> list[dict[str, dict]]:
    """Découpe l'envoi : DCS lit les commandes du bot en UDP avec receive() sans taille, limité à 8192 octets
    (LuaSocket) ; au-delà le message est tronqué et perdu. limit = taille JSON d'un morceau (échappé deux fois
    dans le message, d'où la marge)."""
    out, cur, size = [], {}, 2
    for name, p in scores.items():
        n = len(json.dumps({name: p})) + 1
        if cur and size + n > limit:
            out.append(cur)
            cur, size = {}, 2
        cur[name] = p
        size += n
    return out + [cur] if cur or not out else out
