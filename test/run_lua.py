"""Kör testriggen med OBS medföljande lua51.dll (LuaJIT = Lua 5.1-semantik som WoW).

    python test\\run_lua.py

Ingen Lua-tolk finns installerad, men OBS har en lua51.dll som går att driva via
ctypes. Addon-mappen skickas in som den globala ADDON_DIR.
"""
import ctypes
import pathlib
import sys

DLL = r"C:\Program Files\obs-studio\bin\64bit\lua51.dll"
LUA_GLOBALSINDEX = -10002

here = pathlib.Path(__file__).resolve().parent
script = here / "test_ulatekeggs.lua"
addon_dir = here.parent.as_posix() + "/"

lua = ctypes.CDLL(DLL)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.lua_pushstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadfile.restype = ctypes.c_int
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_pcall.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]

state = lua.luaL_newstate()
lua.luaL_openlibs(state)
lua.lua_pushstring(state, addon_dir.encode("utf-8"))
lua.lua_setfield(state, LUA_GLOBALSINDEX, b"ADDON_DIR")

status = lua.luaL_loadfile(state, str(script).encode("utf-8")) or lua.lua_pcall(state, 0, 0, 0)
sys.stdout.flush()
if status != 0:
    message = lua.lua_tolstring(state, -1, None)
    print("LUA-FEL:", message.decode("utf-8", "replace"))
lua.lua_close(state)
sys.exit(1 if status != 0 else 0)
