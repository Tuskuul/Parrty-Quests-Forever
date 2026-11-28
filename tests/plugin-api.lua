local locked=false
InCombatLockdown=function() return locked end
local host={engine={}}
assert(loadfile('PluginAPI.lua'))('SimplyPartyQuests',host)
assert(PartyQuestsForeverAPI.contract==1)
assert(not PartyQuestsForeverAPI.RegisterTrackerPlugin('',1))
assert(not PartyQuestsForeverAPI.RegisterTrackerPlugin('PartyQuestieForever',2))
locked=true
assert(not PartyQuestsForeverAPI.RegisterTrackerPlugin('PartyQuestieForever',1))
locked=false
local shared=PartyQuestsForeverAPI.RegisterTrackerPlugin('PartyQuestieForever',1)
assert(shared==host and shared.engine==host.engine,'plugin created a separate engine')
assert(not PartyQuestsForeverAPI.RegisterTrackerPlugin('PartyQuestieForever',1))
assert(not PartyQuestsForeverAPI.RegisterTrackerPlugin('AnotherTrackerPlugin',1))
print('PASS: optional plugin contract, shared host, invalid/duplicate/competing registration and combat rejection')
