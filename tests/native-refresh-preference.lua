-- Run from the addon directory with Lua 5.1+.
CreateFrame=function()
 return setmetatable({scripts={}},{__index=function(_,key)
  if key=='SetScript' then return function(self,name,fn) self.scripts[name]=fn end end
  return function() end
 end})
end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
local function init(saved)
 SimplyPartyQuestsDB=saved
 A.events.scripts.OnEvent(nil,'ADDON_LOADED','SimplyPartyQuests')
 return A.db
end
assert(init({}).nativeTrackerRepair==true,'new installation did not default on')
assert(init({displayMode='blizzard'}).nativeTrackerRepair==true,'unset preference did not default on')
assert(init({nativeTrackerRepair=false}).nativeTrackerRepair==false,'explicit opt-out was overwritten')
assert(init({nativeTrackerRepair=true}).nativeTrackerRepair==true)
local saved=A.db;saved.nativeTrackerRepair=false
assert(init(saved).nativeTrackerRepair==false,'automatic or manual off state did not survive reload')
assert(init({}).combatAutoHide==true,'combat auto-hide must default on')
assert(init({combatAutoHide=false}).combatAutoHide==false,'combat auto-hide opt-out overwritten')
print('PASS: native refresh default-on, existing unset preferences and saved opt-outs')
