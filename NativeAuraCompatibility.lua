local _, A = ...
-- Older Forever builds query a MAW aura from ShouldShowMawBuffs even when
-- auras are secret. Both Edit Mode anchor broadcasts and scenario layouts
-- reach that predicate. Guard the predicate, not the aura API or its callers.
-- Newer clients have C_MawBuffs.HasAnyMawBuffs and need no addon workaround.
A.nativeAuraCompatibility = {status="waiting for native Maw predicate"}
function A:InstallNativeAuraCompatibility()
    local state=self.nativeAuraCompatibility
    if type(GetBuildInfo)~="function" then state.status="client version unavailable";return end
    local _,_,_,interface=GetBuildInfo()
    if not self.public(interface,"number") or interface~=16001 then
        state.status="not a Forever client";return
    end
    if state.wrapper then
        state.status=ShouldShowMawBuffs==state.wrapper and "legacy secret-aura guard active" or "native predicate changed; guard not reapplied"
        return
    end
    if C_MawBuffs and type(C_MawBuffs.HasAnyMawBuffs)=="function" then
        state.status="native Maw presence API available; workaround not installed";return
    end
    local original=ShouldShowMawBuffs
    if type(original)~="function" then state.status="waiting for native Maw predicate";return end
    local secrecy=C_Secrets and C_Secrets.ShouldAurasBeSecret
    if type(secrecy)~="function" then state.status="aura secrecy predicate unavailable; workaround not installed";return end
    state.original=original
    local wrapper=function(...)
        local ok,hidden=pcall(secrecy)
        -- Never branch on a restricted predicate result. A failed/unknown
        -- secrecy check is not permission to read an aura either.
        if ok and A.public(hidden,"boolean") and not hidden then return original(...) end
        -- Preserve the other native condition without reading any aura data.
        local towerOK,tower=false,nil
        if type(IsInJailersTower)=="function" then towerOK,tower=pcall(IsInJailersTower) end
        return towerOK and A.public(tower,"boolean") and tower or false
    end
    state.wrapper=wrapper
    ShouldShowMawBuffs=wrapper
    state.status="legacy secret-aura guard active"
end
function A:NativeAuraCompatibilityReport()
    return "Native aura compatibility: "..self.nativeAuraCompatibility.status
end
local frame=CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent",function() A:InstallNativeAuraCompatibility() end)
A:InstallNativeAuraCompatibility()
