"""Faux DCS + MOOSE partagé (lupa, Lua 5.1 comme DCS) pour les tests hors jeu de site/mission/script Caucase.lua.

runtime()            : Lua neuf avec le faux DCS/MOOSE (fakedcs.lua) et le moteur de scénarios (scenario.lua).
run_scenario(chemin) : rejoue un scénario (scenarios/*.lua) sur le script entier, renvoie (échecs, trace).
"""
import pathlib
import tempfile

from lupa.lua51 import LuaRuntime

HERE = pathlib.Path(__file__).parent
SCRIPT = HERE.parent.parent / 'mission' / 'script Caucase.lua'


def load_file(lua, path, name=None):
    """Exécute un fichier Lua (nom de fichier dans les erreurs) et renvoie ce qu'il renvoie."""
    chunk = compile_lua(lua, pathlib.Path(path).read_text(encoding='utf-8'), name or pathlib.Path(path).name)
    return chunk()


def compile_lua(lua, src, name):
    return lua.eval('function(s, n) local f, e = loadstring(s, n) if not f then error(e, 0) end return f end')(src, '@' + name)


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    load_file(lua, HERE / 'fakedcs.lua')
    load_file(lua, HERE / 'scenario.lua')
    return lua


def script_chunk(lua):
    return compile_lua(lua, SCRIPT.read_text(encoding='utf-8'), SCRIPT.name)


def run_scenario(path):
    lua = runtime()
    mission = load_file(lua, HERE / 'mission_defaut.lua')()
    sc = load_file(lua, path)
    with tempfile.TemporaryDirectory() as d:
        fails = lua.globals().Sc.run(sc, mission, script_chunk(lua), d.replace('\\', '/') + '/')
        fails = [fails[i] for i in range(1, len(fails) + 1)]
        return fails, lua.globals().Sc.trace(12), sc.description


def probe(path_menu):
    """Retire chaque objet de la mission un par un : renvoie {nom: erreur de chargement} de ceux qui font disparaître path_menu."""
    lua = runtime()
    make = load_file(lua, HERE / 'mission_defaut.lua')
    chunk = script_chunk(lua)
    names = make().names()
    broken = {}
    with tempfile.TemporaryDirectory() as d:
        lua.globals().Fake.writedir = d.replace('\\', '/') + '/'
        for i in range(1, len(names) + 1):
            present, err = lua.globals().Sc.probe(make(), chunk, names[i], path_menu)
            if not present:
                broken[names[i]] = err
    return broken
