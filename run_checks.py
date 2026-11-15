from pathlib import Path
import ctypes,ctypes.util,os
root=Path(__file__).resolve().parent
w=root;tests=root/'tests';os.chdir(w)
lua_library=ctypes.util.find_library('lua5.4')
if not lua_library: raise SystemExit('Install liblua5.4 (e.g. apt install liblua5.4-0), or run the Lua suites with a compatible Lua interpreter from source/SimplyPartyQuests.')
lib=ctypes.CDLL(lua_library)
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p];lib.lua_close.argtypes=[ctypes.c_void_p]
fail=[]
for f in [*w.glob('*.lua'),*sorted(tests.glob('*.lua'))]:
 s=lib.luaL_newstate();lib.luaL_openlibs(s)
 status=lib.luaL_loadfilex(s,str(f).encode(),None)
 if not status and f.parent==tests: status=lib.lua_pcallk(s,0,0,0,0,None)
 if status: fail.append(str(f)+': '+lib.lua_tolstring(s,-1,None).decode())
 lib.lua_close(s)
for msg in fail: print('FAIL:',msg)
print(f'{len(list(w.glob("*.lua")))} source files syntax checked; {len(list(tests.glob("*.lua")))-len(fail)} regression suites passed')
raise SystemExit(bool(fail))
