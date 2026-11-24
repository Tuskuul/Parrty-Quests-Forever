local frames={}
CreateFrame=function()
    local f={RegisterEvent=function() end,SetScript=function(self,k,v) self[k]=v end}
    frames[#frames+1]=f;return f
end
local interface=16001
GetBuildInfo=function() return '1.60.1','70938','Nov 12 2026',interface end
local restricted={}
local function public(v,t) return v~=restricted and type(v)==t end
local hidden=false
C_Secrets={ShouldAurasBeSecret=function() return hidden end}
local auraReads=0
local icon
local tower=false
IsInJailersTower=function() return tower end
local legacy=function()
    auraReads=auraReads+1
    assert(hidden==false,'secret aura read reached from native layout')
    return tower or icon or false
end
local function loadGuard()
    local A={public=public}
    assert(loadfile('NativeAuraCompatibility.lua'))('SimplyPartyQuests',A)
    return A
end
-- Model the two reported native entry paths, not merely a direct predicate call.
ShouldShowMawBuffs=legacy
local A=loadGuard()
local wrapper=ShouldShowMawBuffs
local layouts,anchors=0,0
local function scenarioLayout() local shown=ShouldShowMawBuffs();layouts=layouts+1;return shown end
local function anchorBroadcast() scenarioLayout();anchors=anchors+1 end
hidden=true
scenarioLayout();anchorBroadcast()
assert(auraReads==0 and layouts==2 and anchors==1,'native update/broadcast was interrupted')
tower=true;assert(ShouldShowMawBuffs()==true and auraReads==0)
tower=false;hidden=false;icon=123
assert(ShouldShowMawBuffs()==123 and auraReads==1,'readable legacy result changed')
icon=nil;assert(ShouldShowMawBuffs()==false and auraReads==2)
hidden=restricted;assert(ShouldShowMawBuffs()==false and auraReads==2)
C_Secrets.ShouldAurasBeSecret=function() error('unavailable') end
assert(ShouldShowMawBuffs()==false and auraReads==2)
-- Repeated addon loads do not stack wrappers or clobber a later replacement.
A:InstallNativeAuraCompatibility();assert(ShouldShowMawBuffs==wrapper)
local replacement=function() return 'replacement' end
ShouldShowMawBuffs=replacement
A:InstallNativeAuraCompatibility();assert(ShouldShowMawBuffs==replacement)
assert(A:NativeAuraCompatibilityReport():find('not reapplied',1,true))
-- Native module loading later is supported through ADDON_LOADED.
C_Secrets.ShouldAurasBeSecret=function() return false end
ShouldShowMawBuffs=nil;local B=loadGuard();assert(not B.nativeAuraCompatibility.wrapper)
ShouldShowMawBuffs=legacy;frames[#frames].OnEvent();assert(B.nativeAuraCompatibility.wrapper==ShouldShowMawBuffs)
-- Never replace the predicate on other clients or clients with the upstream API.
ShouldShowMawBuffs=legacy;interface=120107
assert(not loadGuard().nativeAuraCompatibility.wrapper and ShouldShowMawBuffs==legacy)
interface=16001;C_MawBuffs={HasAnyMawBuffs=function() return false end}
assert(not loadGuard().nativeAuraCompatibility.wrapper and ShouldShowMawBuffs==legacy)
C_MawBuffs=nil;C_Secrets=nil
assert(not loadGuard().nativeAuraCompatibility.wrapper and ShouldShowMawBuffs==legacy)
print('PASS: legacy Forever aura guard, both native layout entry paths, readable behavior, restricted/failing predicates, late load, idempotence, replacement ownership and modern/non-Forever exclusions (live test required)')
