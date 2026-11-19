securecallfunction=function(fn,...) return fn(...) end
-- Run from the test addon directory with Lua 5.1+.
local now=10
local combat=false
GetTime=function() return now end
InCombatLockdown=function() return combat end
CreateFrame=function() return setmetatable({scripts={}},{__index=function(_,k)
 if k=='SetScript' then return function(self,name,fn) self.scripts[name]=fn end end
 return function() end
end}) end
local A={}
for _,file in ipairs({'Core.lua','NativeTracker.lua','Settings.lua'}) do
 assert(loadfile(file))('SimplyPartyQuests',A)
end
local logText,visible,mode,requests,busy,hidden
local parent={IsShown=function() return not hidden end,IsCollapsed=function() return false end}
local font={GetText=function() return visible end}
local block={GetExistingLine=function() return {Text=font} end}
QuestObjectiveTracker={parentContainer=parent,CanUpdate=function() return not busy end,
 IsCollapsed=function() return false end,GetExistingBlock=function() return block end,
 MarkDirty=function()
  requests=requests+1
  if mode=='fix' then visible=logText elseif mode=='blank' then visible='' elseif mode=='error' then error('test error') end
 end}
C_QuestLog={GetLogIndexForQuestID=function(id) assert(id==101);return 1 end,
 GetQuestWatchType=function() return 0 end}
GetNumQuestLeaderBoards=function() return 1 end
GetQuestLogLeaderBoard=function() return logText end
local function reset(nextMode)
 now=10;combat=false;busy=false;hidden=false;requests=0;mode=nextMode
 logText='5/6 Abandoned Training Weapon';visible='1/6 Abandoned Training Weapon'
 A.db={nativeTrackerRepair=true};A.own={[101]={objectives={{text=logText,done=5,total=6}}}}
 A.nativeTracker={queued=0,requested=0,errors=0,history={}}
end
local function queue()
 A:QueueNativeTracker('local objective change');now=now+1;A:NativeTrackerTick()
end
reset('fix');visible=logText;queue();assert(requests==0,'matching counters were redrawn')
reset('fix');queue();assert(requests==1 and A.nativeTracker.verify,'verified mismatch did not request one refresh')
now=now+2;A:NativeTrackerTick()
assert(not A.nativeTracker.verify and A.nativeTracker.result:find('1 match',1,true),'successful redraw was not verified')
reset('stale');queue();now=now+2;A:NativeTrackerTick()
assert(A.nativeTracker.result:find('1 stale',1,true))
queue();assert(requests==1,'same stale counters triggered repeated redraws')
reset('blank');queue();now=now+2;A:NativeTrackerTick()
assert(A.nativeTracker.suspended and not A.db.nativeTrackerRepair,'blank-pane result did not pause refresh')
A:QueueNativeTracker('manual',true);assert(not A.nativeTracker.due,'suspended refresh was requeued')
A:SetNativeRepair(true);assert(not A.nativeTracker.suspended and A.db.nativeTrackerRepair,'explicit re-enable did not reset test pause')
A:SetNativeRepair(false);assert(not A.nativeTracker.verify and not A.nativeTracker.due)
reset('error');queue();assert(A.nativeTracker.suspended and not A.db.nativeTrackerRepair)
reset('fix');combat=true;queue();assert(requests==0 and A.nativeTracker.due,'redraw ran in combat')
combat=false;A:NativeTrackerTick();assert(requests==1)
reset('fix');busy=true;queue();assert(requests==0 and A.nativeTracker.due,'busy native module was redrawn')
busy=false;now=now+2;A:NativeTrackerTick();assert(requests==1)
hidden=true;now=now+10;A:NativeTrackerTick()
assert(A.nativeTracker.suspended and not A.db.nativeTrackerRepair,'unverifiable hidden result did not time out safely')
reset('fix');visible='';queue();assert(requests==0,'already blank native pane was force-redrawn')
reset('fix');logText='progress unavailable';queue();assert(requests==0,'unreadable progress forced a redraw')
reset('fix');combat=true
A.db.displayMode='blizzard';A.integration={attached=true}
local invalidations=0
function A:InvalidateTrackerIntegration() invalidations=invalidations+1 end
A.nativeTrackerEvents.scripts.OnEvent(nil,'ADDON_ACTION_BLOCKED','SimplyPartyQuests','test expansion')
assert(A.db.displayMode=='blizzard' and A.integration.blockedRestore and invalidations==1,'blocked action changed docked mode')
assert(not A.nativeTracker.suspended and A.db.nativeTrackerRepair,'unrelated UI block disabled native repair')
local before=invalidations
A.nativeTracker.verify={at=100}
A.nativeTrackerEvents.scripts.OnEvent(nil,'ADDON_ACTION_BLOCKED','SimplyPartyQuests','OpenSettingsPanel()')
assert(A.nativeTracker.verify and A.db.nativeTrackerRepair and invalidations==before,'settings block interfered with repair or docked state')
A.nativeTrackerEvents.scripts.OnEvent(nil,'ADDON_ACTION_BLOCKED','SimplyPartyQuests','Frame:Show()')
assert(A.nativeTracker.suspended and not A.nativeTracker.verify and not A.db.nativeTrackerRepair,'blocked action during verification did not pause repair')
reset('fix')
QuestObjectiveTracker.MarkDirty=function()
 A.nativeTrackerEvents.scripts.OnEvent(nil,'ADDON_ACTION_BLOCKED','SimplyPartyQuests','Frame:Show()')
end
queue()
assert(A.nativeTracker.suspended and not A.nativeTracker.verify and not A.db.nativeTrackerRepair,'synchronously blocked repair started verification anyway')
print('PASS: mismatch-only requests, result verification, duplicate suppression, blank/error pauses, busy/combat deferral and no progress guessing')


-- A visual collapse must defer repair even though its prepared native layout is expanded.
reset('fix')
A.IsNativeTrackerCollapsed=function(self,container) assert(container==parent);return true end
queue()
assert(requests==0 and A.nativeTracker.due,'visually collapsed prepared tracker was redrawn')
A.IsNativeTrackerCollapsed=nil
