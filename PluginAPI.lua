local _,A=...
-- Contract 1 is for trusted, explicitly installed tracker companions. The host
-- remains the sole quest engine, event/polling loop and settings owner.
local registered={}
PartyQuestsForeverAPI={contract=1}
function PartyQuestsForeverAPI.RegisterTrackerPlugin(id,contract)
    if type(id)~="string" or id=="" or contract~=1 then return nil,"Unsupported tracker plugin contract" end
    if InCombatLockdown and InCombatLockdown() then return nil,"Load tracker plugins outside combat; reload required" end
    if registered[id] then return nil,"Tracker plugin already registered" end
    if next(registered) then return nil,"Another tracker plugin is already registered" end
    registered[id]=true
    return A
end
