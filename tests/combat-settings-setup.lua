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
local registerCategory=A.RegisterSettingsCategory
A.CombatControlNotice=function() notices=notices+1 end
A.InitSettings=function() assert(not locked);init=init+1 end
A.RegisterSettingsCategory=function() assert(not locked) end
A.SyncSettings=function() end
A.settingsCategory={GetID=function() return 1 end}
A.questSharePicker={shown=true,selected={[701]=true},draft={text='keep this'}}
local selection,draft=A.questSharePicker.selected,A.questSharePicker.draft
Settings={OpenToCategory=function(id) assert(not locked and id==1);opens=opens+1 end}
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

-- Register the real controls directly, with no launcher or second dialog.
A.settingsPanel={name='Party Quests Forever'};A.settingsCategory=nil;A.settingsLegacy=nil
local registered,added
Settings.RegisterCanvasLayoutCategory=function(panel,name)
 assert(panel==A.settingsPanel and name==panel.name);registered=panel
 return {GetID=function() return 1 end}
end
Settings.RegisterAddOnCategory=function(category) added=category end
registerCategory(A)
assert(registered==A.settingsPanel and A.settingsCategoryPanel==A.settingsPanel and added==A.settingsCategory)
A:OpenSettings()
assert(opens==2 and not A.settingsDialog and not A.ShowSettingsDialog)
assert(A.questSharePicker.shown and A.questSharePicker.selected==selection and A.questSharePicker.draft==draft,'native settings mutated a sharing window')
-- Older clients still open their actual native category directly.
A.settingsCategory=nil;A.settingsLegacy=nil;Settings=nil
local legacy
InterfaceOptions_AddCategory=function(panel) legacy=panel end
registerCategory(A);assert(legacy==A.settingsPanel and A.settingsLegacy)
InterfaceOptionsFrame_OpenToCategory=function(panel) assert(panel==A.settingsPanel);opens=opens+1 end
assert(A:OpenSettings() and opens==3)
print('PASS: native AddOns category contains the actual controls, direct modern/legacy opening, no extra dialog and preserved sharing selections/drafts')
