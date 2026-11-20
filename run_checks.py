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
# Keep repository-only artwork out of packages without dropping runtime files
# or required attribution. This project's ignore list contains literal paths.
ignore=[];in_ignore=False
for line in (root/'.pkgmeta').read_text().splitlines():
 if line=='ignore:': in_ignore=True;continue
 if in_ignore and line.startswith('    - '): ignore.append(line[6:].strip())
 elif in_ignore and line.strip() and not line[0].isspace(): in_ignore=False
def excluded(path):
 return any(path==entry or path.startswith(entry+'/') for entry in ignore)
required=[line.strip().replace('\\','/') for line in (root/'SimplyPartyQuests.toc').read_text().splitlines() if line.strip() and not line.lstrip().startswith('#')]
required+=['Assets/Icon.tga','LICENSE','third_party/QuestieDB-NOTICE.txt','third_party/QuestieDB-LICENSE.md']
package_errors=[]
for path in required:
 if not (root/path).is_file() or excluded(path): package_errors.append('required runtime/attribution file missing from package: '+path)
for path in (root/'docs').rglob('*.png'):
 if not excluded(path.relative_to(root).as_posix()): package_errors.append('repository artwork would enter the addon package: '+path.name)
for msg in package_errors: print('FAIL:',msg)
for msg in fail: print('FAIL:',msg)
print(f'{len(list(w.glob("*.lua")))} source files syntax checked; {len(list(tests.glob("*.lua")))-len(fail)} regression suites passed')
print(f'Package manifest: {len(required)} runtime/attribution paths checked; {len(package_errors)} errors')
raise SystemExit(bool(fail or package_errors))

