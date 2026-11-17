unpack=unpack or table.unpack
local locked=true
local now=100
GetTime=function() return now end
InCombatLockdown=function() return locked end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={}
for _,f in ipairs({'Core.lua','TrackerIntegration.lua','Settings.lua'}) do assert(loadfile(f))('SimplyPartyQuests',A) end
A.db={displayMode='blizzard'};A.members={}
local notices,init,opens=0,0,0
A.CombatControlNotice=function() notices=notices+1 end
A.InitSettings=function() assert(not locked);init=init+1 end
A.RegisterSettingsCategory=function() assert(not locked) end
A.SyncSettings=function() end
A.settingsCategory={GetID=function() return 1 end}
Settings={OpenToCategory=function() error('opened native Settings behind dialogs') end}
local showDialog=A.ShowSettingsDialog
A.ShowSettingsDialog=function() assert(not locked);opens=opens+1 end
for _=1,4 do A:OpenSettings() end
A:ApplyPendingSettings()
assert(A.settingsOpenPending and notices==1 and init==0 and opens==0,'combat settings request accessed native UI or repeated feedback')
locked=false;A:ApplyPendingSettings();A:ApplyPendingSettings()
assert(not A.settingsOpenPending and opens==1 and init==1,'queued settings request was lost or opened repeatedly')
-- The report must distinguish disabled setup from missing globals.
ObjectiveTrackerFrame={}
RegisterStateDriver=nil;SecureHandlerWrapScript=nil
A.db.combatAutoHide=false;A:PrepareCombatCollapse()
assert(A.integration.combatSetupStatus=='disabled in settings')
local r=A:CombatTrackerReport()
assert(r:find('auto-collapse=false',1,true) and r:find('controller=false',1,true))
A.db.combatAutoHide=true;A:PrepareCombatCollapse()
assert(A.integration.combatSetupStatus=='unavailable: RegisterStateDriver')
RegisterStateDriver=function() end;A:PrepareCombatCollapse()
assert(A.integration.combatSetupStatus=='unavailable: SecureHandlerWrapScript')
SecureHandlerWrapScript=function() end;ObjectiveTrackerFrame=nil;A:PrepareCombatCollapse()
assert(A.integration.combatSetupStatus=='waiting for Blizzard tracker')
-- Failed setup records the actual phase and does not retry every frame.
local attempts=0
A.PrepareCombatCollapseUnsafe=function(self)
 attempts=attempts+1;self.integration.combatSetupPhase='state driver';error('registration failed')
end
A:PrepareCombatCollapse();A:PrepareCombatCollapse()
assert(attempts==1 and A.integration.combatSetupStatus=='setup failed at state driver' and A.integration.combatSetupError:find('registration failed',1,true))
now=111;A:PrepareCombatCollapse();assert(attempts==2,'setup retry did not recover after its backoff')
print('PASS: queued combat settings access, coalesced feedback, one post-combat open, explicit setup status/API reporting and bounded failed-setup retries')

-- The real settings host must coexist with open share windows and raise itself.
local function widget()
 local w={scripts={}}
 return setmetatable(w,{__index=function(_,key)
  if key=='SetScript' then return function(self,n,fn) self.scripts[n]=fn end end
  if key=='Show' then return function(self) self.shown=true end end
  if key=='Raise' then return function(self) self.raised=true end end
  if key=='SetFrameStrata' then return function(self,strata) self.strata=strata end end
  if key=='SetParent' then return function(self,parent) self.parent=parent end end
  return function() end
 end})
end
CreateFrame=function() return widget() end
A.settingsPanel=widget();A.settingsDialog=nil
A.questSharePicker={shown=true,selected={[701]=true},draft={text='keep this'}}
local selection,draft=A.questSharePicker.selected,A.questSharePicker.draft
showDialog(A)
assert(A.settingsDialog.shown and A.settingsDialog.raised and A.settingsPanel.parent==A.settingsDialog)
assert(A.settingsDialog.strata=="MEDIUM","settings host covers native map panels")
assert(A.questSharePicker.shown and A.questSharePicker.selected==selection and A.questSharePicker.draft==draft)
print('PASS: movable settings host raises alongside sharing without closing it or changing drafts/selections')
