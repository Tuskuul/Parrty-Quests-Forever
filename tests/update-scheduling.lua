local now=100
GetTime=function() return now end
InCombatLockdown=function() return false end
local frames={}
CreateFrame=function(_,name)
 local f={scripts={}}
 function f:RegisterEvent() end
 function f:SetScript(k,v) self.scripts[k]=v end
 frames[#frames+1]={name=name,frame=f}
 return f
end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogLinks.lua'))('SimplyPartyQuests',A)
A.db={displayMode='window'}
A.window={SetShown=function() end}
local checks,shown=0,0
function A:QuestieCompatibilityTick() checks=checks+1 end
function A:NativeTrackerWritesAllowed() return false end
function A:ShouldShowPartyView() return true end
function A.window:SetShown(value) shown=shown+1;assert(value) end
WorldMapFrame=setmetatable({},{__index=function() error('addon accessed the map after shortcut removal') end})
A.events.scripts.OnUpdate(nil,0.2)
assert(checks==1 and shown==1,'normal update repeated compatibility polling')
A:TrackerIntegrationTick()
assert(checks==2,'direct UI update skipped the required compatibility refresh')
A.questLinkFrame.scripts.OnEvent(nil,'PLAYER_LOGIN')
for _,f in ipairs(frames) do assert(f.name~='SimplyPartyQuestsShareLogButton','map shortcut was still created') end
print('PASS: one compatibility pass per normal update, fresh direct UI updates, and no map shortcut/frame access')
