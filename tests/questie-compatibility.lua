securecallfunction=function(fn,...) return fn(...) end
unpack=unpack or table.unpack
local locked,now=false,100
GetTime=function() return now end
InCombatLockdown=function() return locked end
local function frame()
 local f={scripts={},shown=true,attrs={}}
 function f:RegisterEvent() end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:SetShown(v) self.shown=v end
 function f:Hide() self.shown=false end
 function f:IsShown() return self.shown end
 function f:SetAttribute(k,v) assert(not locked,'protected attributes changed in combat');self.attrs[k]=v end
 function f:GetAttribute(k) return self.attrs[k] end
 return f
end
CreateFrame=function() return frame() end
local A={}
for _,file in ipairs({'Core.lua','QuestieCompatibility.lua','NativeTracker.lua','TrackerIntegration.lua','Settings.lua','Polling.lua'}) do
 assert(loadfile(file))('SimplyPartyQuests',A)
end
A.db={displayMode='blizzard',nativeTrackerRepair=true,combatAutoHide=true,collapsed=false}
A.window=frame();A.sidebar=frame();A.partyTrackerButton=frame()
local restored,visuals,reads,collapsed=0,0,0,false
function A:RestoreJoinedTrackerHeader() assert(not locked);restored=restored+1 end
function A:RestoreTrackerJoinVisuals() assert(not locked);visuals=visuals+1 end
function A:SetCollapsed(value) collapsed=value;self.db.collapsed=value end
function A:UpdateMinimapButton() end
function A:SyncSettings() end
function A:ShouldShowPartyView() return true end
local mutations=0
ObjectiveTrackerFrame=setmetatable({}, {__index=function() return function() mutations=mutations+1;error('unexpected native access') end end})
assert(not A:QuestieLoaded() and A:NativeTrackerWritesAllowed() and A:NativeCombatControlsAllowed())
Questie={}
A:QuestieCompatibilityTick()
assert(A:EffectiveDisplayMode()=='window' and not A:NativeTrackerWritesAllowed())
assert(not A:NativeCombatControlsAllowed() and A.db.displayMode=='blizzard')
A.nativeTracker.verify={};A.nativeTracker.due=0
A:QueueNativeTracker('manual',true);A:NativeTrackerTick()
assert(not A.nativeTracker.verify and not A.nativeTracker.due and A.db.nativeTrackerRepair)
A:TrackerIntegrationTick()
assert(A.window.shown and not A.sidebar.shown and not A.partyTrackerButton.shown and mutations==0)
A:TogglePartyTracker();assert(A.db.hidden and not A.window.shown)
A:TogglePartyTracker();assert(not A.db.hidden and A.window.shown)
A:SetViewCollapsed(true);assert(collapsed)
A:SetViewCollapsed(false);assert(not collapsed)
-- With the profile readable but its field missing or changed, retain safe mode.
Questie.db={profile={}}
assert(A:QuestieOwnsTracker())
Questie.db.profile.trackerEnabled='false';assert(A:QuestieOwnsTracker())
Questie.db.profile.trackerEnabled=false
A:QuestieCompatibilityTick()
assert(A:EffectiveDisplayMode()=='blizzard' and A:NativeTrackerWritesAllowed())
assert(not A:NativeCombatControlsAllowed(),'maps-only setup armed native secure controls')
A:PrepareCombatCollapseUnsafe();assert(not A.integration.combatController)
-- No imported internal modules or edits to Questie settings.
QuestieLoader={ImportModule=function() error('private import') end}
local profile=Questie.db.profile
Questie.db.profile.trackerEnabled=true;A:QuestieCompatibilityTick()
locked=true
A:TrackerIntegrationTick()
assert(collapsed and not A.db.collapsed and mutations==0,'own collapse touched native/saved state')
A:SetViewCollapsed(false);A:TrackerIntegrationTick()
assert(not collapsed,'manual combat reopening was undone')
Questie.db.profile.trackerEnabled=false;A:QuestieCompatibilityTick()
assert(A:EffectiveDisplayMode()=='window','tracker-off toggle entered native UI during combat')
A:TrackerIntegrationTick();assert(mutations==0)
locked=false;A:QuestieCompatibilityTick()
assert(A:EffectiveDisplayMode()=='blizzard' and not collapsed and Questie.db.profile==profile)
-- Public callbacks register once per API and wake only the authoritative reader.
local callbacks,registrations={},0
Questie.API={isReady=false,RegisterForQuestUpdates=function(fn) registrations=registrations+1;callbacks[#callbacks+1]=fn end}
A:QuestieCompatibilityTick();assert(registrations==0)
Questie.API.isReady=true
A:QuestieCompatibilityTick();A:QuestieCompatibilityTick();assert(registrations==1)
callbacks[1](42);assert(A.ownDue and A.questieCompatibility.updates==1)
callbacks[1]('42');assert(A.questieCompatibility.updates==1)
Questie.API={isReady=true,RegisterForQuestUpdates=function() registrations=registrations+1;error('unsupported') end}
A:QuestieCompatibilityTick();A:QuestieCompatibilityTick();assert(registrations==2)
now=111;A:QuestieCompatibilityTick();assert(registrations==3)
-- Provider-only installation, contract mismatch, nil/error/restricted values,
-- native title precedence and corrected data on subsequent reads.
Questie=nil;QuestieLoader=nil
local title='Database name'
LibQuestieDB={RequireContract=function(v) return v==1 end,Quest={Get=function(id,key)
 if id==42 and key=='name' then return title elseif key=='zoneOrSort' then return 12 end
end}}
C_QuestLog={GetTitleForQuestID=function() return 'Native title' end}
assert(A:QuestTitle(42)=='Native title')
C_QuestLog.GetTitleForQuestID=function() return nil end
assert(A:QuestTitle(42)=='Database name')
title='Corrected name';assert(A:QuestTitle(42)=='Corrected name')
assert(A:EffectiveDisplayMode()=='blizzard' and A:NativeCombatControlsAllowed())
LibQuestieDB.RequireContract=function() return false end
assert(A:QuestTitle(42)==nil)
LibQuestieDB.RequireContract=function() error('broken provider') end
assert(A:QuestTitle(42)==nil)
LibQuestieDB=nil;assert(A:QuestTitle(42)==nil)
C_AddOns={IsAddOnLoaded=function() return true end}
assert(A:QuestieLoaded() and A:QuestieOwnsTracker(),'loaded addon without a global was treated as absent')
assert(A:QuestieCompatibilityReport():find('private progress/protocol: unused',1,true))
-- Late out-of-combat takeover disables an old controller and restores only
-- the layout it had prepared, once; saved repair/layout choices survive.
C_AddOns=nil;Questie={db={profile={trackerEnabled=true}}}
local c=frame();c.attrs.enabled=true
A.integration.combatController=c;A.integration.combatMainButton=frame()
local restoredCollapse=0
A.integration.preparedNative={SetCollapsed=function(_,v) restoredCollapse=restoredCollapse+1;assert(v==true) end}
A.integration.preparedCollapsed=true
A:ReleaseNativeCombatControl();A:ReleaseNativeCombatControl()
assert(c.attrs.enabled==false and not A.integration.combatMainButton.shown and restoredCollapse==1)
local working={marker='working settings'};SimplyPartyQuestsDB=working
SimplyPartyQuestsAlphaDB={}
A.InitSettings=nil
A.events.scripts.OnEvent(nil,'ADDON_LOADED','SimplyPartyQuests')
assert(SimplyPartyQuestsDB==working and working.marker=='working settings' and A.db~=working)
assert(A.db==SimplyPartyQuestsAlphaDB)
local toc=assert(io.open('SimplyPartyQuests.toc')):read('*a')
assert(toc:find('## SavedVariables: SimplyPartyQuestsDB, SimplyPartyQuestsAlphaDB',1,true),
 'WoW would discard working settings from the shared addon save file')
print('PASS: Questie absent/starting/maps-only/tracker/unknown states, saved preference, native-write isolation, visibility and manual collapse, combat toggle deferral, callbacks/backoff, native-first provider reads and contract failure')
