local _,A=...
function A:QuestLinkTrace(stage,detail)
    local d=self.questLinkDiagnostics
    if not d then d={counts={},recent={}};self.questLinkDiagnostics=d end
    d.counts[stage]=(d.counts[stage] or 0)+1
    d.recent[#d.recent+1]=string.format("%.1f %s %s",GetTime(),stage,detail or "")
    if #d.recent>80 then table.remove(d.recent,1) end
end
function A:QuestLogTransferReport()
    local d=self.questLinkDiagnostics or {counts={},recent={}}
    local counters={};for key,value in pairs(d.counts) do counters[#counters+1]=key.."="..value end;table.sort(counters)
    local out={"Quest-log transfer counters: "..table.concat(counters,"; ")}
    local state=self:QuestLinkState()
    for token,q in pairs(state.published) do
        out[#out+1]=string.format("Local snapshot %s: published=%s; age=%.1fs; bytes=%d",token,tostring(q.published),GetTime()-q.localTime,#q.payload)
    end
    for token,p in pairs(state.pending) do
        local parts=0;for _ in pairs(p.parts) do parts=parts+1 end
        out[#out+1]=string.format("Pending %s: route=%s; age=%.1fs; packets=%d/%s",token,p.owner,GetTime()-p.started,parts,tostring(p.total or "?"))
    end
    out[#out+1]="Outgoing snapshot packets queued: "..#state.outgoing
    out[#out+1]="Recent quest-log transfer stages (bounded; no quest payload text):"
    for _,line in ipairs(d.recent) do out[#out+1]=line end
    return table.concat(out,"\n")
end
