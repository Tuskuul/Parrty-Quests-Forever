local _, A = ...
local rows, cards = {}, {}
local function backdrop(frame)
    -- Warm translucent section panels over the same parchment as share dialogs.
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(0.46,0.32,0.15,0.12);frame:SetBackdropBorderColor(0.40,0.27,0.11,0.30)
end
local function label(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont(STANDARD_TEXT_FONT,size or 12,"");f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
    return f
end
local function button(parent,text,width,click)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,22);b:SetText(text);b:SetScript("OnClick",click);return b
end
local function age(t)
    if not t then return "" end
    local n=math.max(0,math.floor(GetTime()-t))
    return n<60 and (n.."s ago") or (math.floor(n/60).."m ago")
end
local function objective(o, remote)
    local text=A:DisplayText(o.text or "")
    if A:IsGenericObjective(text) then
        text="Unnamed quest step (see requirements)"
    end
    if o.total and o.total>0 and not text:find("%d+%s*/%s*%d+") then text=text.." ("..(o.done or "?").."/"..o.total..")" end
    local color=o.total and o.done and o.total>0 and o.done>=o.total and "|cff195c21" or "|cff332112"
    local suffix=""
    if remote then
        if o.done==nil or o.total==nil then suffix=" |cff62503b[progress unknown]|r"
        elseif o.observedAt then suffix=" |cff62503b["..age(o.observedAt).."]|r" end
    end
    return color..text.."|r"..suffix
end
function A:SetCollapsed(value)
    self.db.collapsed=value
    self.body:SetShown(not value)
    self.window:SetHeight(value and 34 or ((self.db.size and self.db.size.height) or 540))
    if self.resizeGrip then self.resizeGrip:SetShown(not value) end
    self.collapse:SetText(value and "+" or "-")
end
-- Include every quest shared with the player; subset-shared quests must not vanish.
function A:GetCombinedQuests(members,own)
    local quests,ids={},{}
    if #members==0 then return quests,ids end
    for id,q in pairs(own) do
        local participants={}
        for _,m in ipairs(members) do if m.quests[id] then participants[#participants+1]=m end end
        if #participants>0 then
            quests[#quests+1]={id=id,title=q.title or participants[1].quests[id].title,participants=participants}
            ids[id]=true
        end
    end
    table.sort(quests,function(a,b) return a.title<b.title end)
    return quests,ids
end
-- Both presentations consume one membership/split model; layout must not decide
-- whether a member or quest exists.
function A:BuildPartyViewData()
    local own=self.demo and self.demoOwn or self.own
    local members={}
    for _,m in pairs(self.demo and self.demoMembers or self.members) do members[#members+1]=m end
    table.sort(members,function(a,b) return a.name<b.name end)
    local combined,ids={},{}
    if self.db.combineShared then combined,ids=self:GetCombinedQuests(members,own) end
    local sections={}
    for _,m in ipairs(members) do
        local shared,other,count={},{},0
        for id,q in pairs(m.quests) do
            count=count+1
            if not ids[id] then
                local dst=own[id] and shared or other;dst[#dst+1]=q
            end
        end
        local function sort(a,b) if a.title==b.title then return a.id<b.id end;return a.title<b.title end
        table.sort(shared,sort);table.sort(other,sort)
        sections[m.guid]={shared=shared,other=other,count=count}
    end
    return {own=own,members=members,combined=combined,combinedIDs=ids,sections=sections}
end
function A:SetCombineShared(value)
    self.db.combineShared=not not value
    self:Render()
end
function A:QuestZone(id)
    local own=(self.demo and self.demoOwn or self.own)[id]
    if own and own.zoneName then return "header:"..own.zoneName,own.zoneName end
    local area=self.QuestieField and self:QuestieField(id,"zoneOrSort")
    if not self.validInteger(area,-10000000,10000000) then area=(self.questZones or {})[id] end
    if not area or area==0 then return "unknown","Unknown zone" end
    local name
    if area>0 and GetAreaInfo then
        local ok,value=pcall(GetAreaInfo,area)
        if ok and self.public(value,"string") and value~="" then name=value end
    end
    name=name or (self.zoneNames or {})[area]
    if not name then return "unknown","Unknown zone" end
    return "header:"..name,name
end
function A:GroupQuestsByZone(quests)
    local groups,byKey={},{}
    for _,q in ipairs(quests) do
        local key,name=self:QuestZone(q.id)
        local g=byKey[key]
        if not g then g={key=key,name=name,quests={}};byKey[key]=g;groups[#groups+1]=g end
        g.quests[#g.quests+1]=q
    end
    table.sort(groups,function(a,b)
        if a.key=="unknown" then return false elseif b.key=="unknown" then return true end
        return a.name<b.name
    end)
    for _,g in ipairs(groups) do table.sort(g.quests,function(a,b) if a.title==b.title then return a.id<b.id end;return a.title<b.title end) end
    return groups
end
function A:SetGroupByZone(value)
    self.db.groupByZone=not not value;self:Render()
end
function A:Render()
    if self.InvalidateTrackerIntegration then self:InvalidateTrackerIntegration() end
    if self.SyncSettings then self:SyncSettings() end
    if not self.window then return end
    for _,r in ipairs(rows) do r:Hide() end
    for _,c in ipairs(cards) do c:Hide() end
    local n, cn, y=0,0,0
    local contentWidth=self.contentWidth or 414
    local function textRow(text,size,color,indent)
        n=n+1
        local row=rows[n]
        if not row then
            row=CreateFrame("Button",nil,A.child);row.text=label(row,size);rows[n]=row
            row.text:SetPoint("TOPLEFT",row, "TOPLEFT",8, -3)
        end
        row:SetScript("OnClick",nil);row:EnableMouse(false)
        row:SetScript("OnDoubleClick",nil)
        row:ClearAllPoints();row:SetPoint("TOPLEFT",A.child,"TOPLEFT",indent or 0,-y)
        row:SetWidth(contentWidth-2-(indent or 0));row.text:SetWidth(contentWidth-18-(indent or 0))
        row.text:SetFont(STANDARD_TEXT_FONT,size or 12,"");row.text:SetText(text)
        -- Dark ink on parchment, including class-colored names. Font height
        -- stays explicit so resizing and reused rows preserve their hierarchy.
        local ink=color or {0.48,0.34,0.20}
        row.text:SetTextColor(ink[1]*0.48,ink[2]*0.48,ink[3]*0.48)
        local height=math.max(20,row.text:GetStringHeight()+7)
        row:SetHeight(height);row:Show();y=y+height
        return row
    end
    self.db.zoneCollapsed=self.db.zoneCollapsed or {}
    self.demoZoneCollapsed=self.demoZoneCollapsed or {}
    local zoneCollapsed=self.demo and self.demoZoneCollapsed or self.db.zoneCollapsed
    local function questRows(quests,context,indent,draw)
        if not self.db.groupByZone then for _,q in ipairs(quests) do draw(q) end;return end
        for _,group in ipairs(self:GroupQuestsByZone(quests)) do
            local key=context..":"..group.key
            local closed=zoneCollapsed[key]
            local h=textRow((closed and "[+] " or "[-] ")..group.name.." ("..#group.quests..")",12,{0.63,0.79,0.96},indent)
            h:EnableMouse(true);h:SetScript("OnClick",function() zoneCollapsed[key]=not zoneCollapsed[key];self:Render() end)
            if not closed then for _,q in ipairs(group.quests) do draw(q) end end
        end
    end
    local view=self:BuildPartyViewData()
    local list=view.members
    if #list==0 then
        textRow(IsInRaid() and "Party view is available in groups of up to five." or "Join a party to see its members.",13)
        textRow("Native tooltips discover relevant quests. Installing this addon on both players also enables full quest-log comparison.",12,{0.6,0.66,0.74})
    end
    local own=view.own
    self.demoQuestExpanded=self.demoQuestExpanded or {}
    local questExpansion=self.demo and self.demoQuestExpanded or self.db.questExpanded
    self.demoSectionCollapsed=self.demoSectionCollapsed or {}
    local sectionCollapsed=self.demo and self.demoSectionCollapsed or self.db.sectionCollapsed
    if self.combineButton then self.combineButton:SetText((self.db.combineShared and "[x] " or "[ ] ").."Combine shared quests") end
    if self.zoneButton then self.zoneButton:SetText((self.db.groupByZone and "[x] " or "[ ] ").."Group by zone") end
    local combined,combinedIDs={},{}
    if self.db.combineShared then
        cn=cn+1
        local card=cards[cn]
        if not card then card=CreateFrame("Frame",nil,A.child,"BackdropTemplate");backdrop(card,0.065,0.085,0.11);card:SetFrameLevel(A.child:GetFrameLevel());cards[cn]=card end
        local start=y
        card:ClearAllPoints();card:SetPoint("TOPLEFT",A.child,"TOPLEFT",0,-start);card:SetWidth(contentWidth-2);card:Show()
        combined,combinedIDs=view.combined,view.combinedIDs
        local closed=self.db.combinedCollapsed
        local h=textRow((closed and "[+] " or "[-] ").."Shared quests ("..#combined..")",13,{0.45,0.8,0.86})
        h:EnableMouse(true);h:SetScript("OnClick",function() self.db.combinedCollapsed=not self.db.combinedCollapsed;self:Render() end)
        if not closed then
            if #combined==0 then textRow("No shared quests discovered yet.",12,{0.6,0.66,0.74},12) end
            questRows(combined,"all",8,function(q)
                local key="all:"..q.id
                local open=questExpansion[key]
                local hq=textRow((open and "[-] " or "[+] ")..self:QuestTitleText(q.id,q.title).." |cff62503b["..(#q.participants+1).."/"..(#list+1).." players]|r",13,{0.98,0.82,0.42},12)
                hq:EnableMouse(true);hq:SetScript("OnClick",function() questExpansion[key]=not questExpansion[key];self:Render() end)
                if open then
                    local requirements
                    for _,m in ipairs(q.participants) do
                        local r=m.quests[q.id].requirements
                        if r and #r>0 then requirements=r;break end
                    end
                    if requirements then
                        textRow("Quest requirements",11,{0.66,0.72,0.8},22)
                        for _,r in ipairs(requirements) do textRow(self:DisplayText(r.text),12,nil,22) end
                    end
                    local function progress(name,quest,remote,m)
                        local c=m and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
                        textRow(name..(m and m.connected==false and " - offline (cached)" or ""),12,c and {c.r,c.g,c.b} or {0.66,0.72,0.8},22)
                        if self:IsQuestReady(quest) then textRow("Ready for turn-in",12,{0,1,0},30)
                        elseif #(quest.objectives or {})==0 then textRow("Progress unknown",12,{0.67,0.64,0.5},30)
                        else for _,o in ipairs(quest.objectives) do textRow(objective(o,remote),12,nil,30) end end
                    end
                    progress("You",own[q.id],false)
                    for _,m in ipairs(q.participants) do progress(m.name,m.quests[q.id],true,m) end
                end
            end)
        end
        card:SetHeight(y-start+4);y=y+9
    end
    for _,m in ipairs(list) do
        local data=view.sections[m.guid]
        local shared,other,count=data.shared,data.other,data.count
        local expanded=self.db.expanded[m.guid]
        local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
        local header=textRow((expanded and "[-] " or "[+] ")..m.name.."  |cff62503b("..count..")|r",14,c and {c.r,c.g,c.b} or nil)
        header:EnableMouse(true);header:SetScript("OnClick",function() self.db.expanded[m.guid]=not self.db.expanded[m.guid];self:Render() end)
        if expanded then
            local status
            if m.syncedAt then status="Full log synced "..age(m.syncedAt)..(GetTime()-m.syncedAt>120 and " |cff79500a- awaiting update|r" or "")
            else status="Discovered quests" end
            if m.connected==false then status=status.." - offline" end
            textRow(status,11,{0.65,0.71,0.8},14)
            local function section(title,quests,both)
                cn=cn+1
                local card=cards[cn]
                if not card then card=CreateFrame("Frame",nil,A.child,"BackdropTemplate");backdrop(card,0.065,0.085,0.11);card:SetFrameLevel(A.child:GetFrameLevel());cards[cn]=card end
                local start=y
                card:ClearAllPoints();card:SetPoint("TOPLEFT",A.child,"TOPLEFT",12,-start);card:SetWidth(contentWidth-14);card:Show()
                local sectionKey=m.guid..":"..(both and "shared" or "other")
                local isClosed=sectionCollapsed[sectionKey]
                local sectionHeader=textRow((isClosed and "[+] " or "[-] ")..title.." ("..#quests..")",12,{0.45,0.8,0.86},20)
                sectionHeader:EnableMouse(true)
                sectionHeader:SetScript("OnClick",function()
                    sectionCollapsed[sectionKey]=not sectionCollapsed[sectionKey];self:Render()
                end)
                if isClosed then card:SetHeight(y-start+4);y=y+9;return end
                if #quests==0 then textRow(m.syncedAt and "No quests in this section." or "None discovered yet.",12,{0.52,0.58,0.66},26) end
                questRows(quests,sectionKey,24,function(q)
                    local questKey=m.guid..":"..q.id
                    local questOpen=questExpansion[questKey]
                    local questHeader=textRow((questOpen and "[-] " or "[+] ")..self:QuestTitleText(q.id,q.title)..(self:IsQuestReady(q) and " |cff195c21[Ready]|r" or ""),13,{0.98,0.82,0.42},26)
                    questHeader:EnableMouse(true)
                    if not both then self:BindQuestShareClick(questHeader,q.id,m.guid) end
                    questHeader:SetScript("OnClick",function()
                        self.shareProbeSelected=q.id
                        questExpansion[questKey]=not questExpansion[questKey];self:Render()
                    end)
                    if questOpen then
                        if q.requirements and #q.requirements>0 then
                            textRow("Quest requirements",11,{0.66,0.72,0.8},32)
                            for _,r in ipairs(q.requirements) do textRow(self:DisplayText(r.text),12,{0.73,0.78,0.84},32) end
                        elseif #q.objectives==0 then
                            textRow("Requirements not available yet.",11,{0.55,0.6,0.68},32)
                        end
                        if self:IsQuestReady(q) then
                            textRow("Objectives complete - ready for turn-in.",12,{0.51,0.81,0.60},32)
                        elseif #q.objectives>0 then
                            textRow(m.name.." - last known progress",11,{0.66,0.72,0.8},32)
                            for _,o in ipairs(q.objectives) do textRow(objective(o,true),12,nil,32) end
                        else textRow("Progress unknown - hover an objective to observe counts.",11,{0.67,0.64,0.5},32) end
                        if both and own[q.id] then
                            textRow("You:",11,{0.66,0.72,0.8},32)
                            for _,o in ipairs(own[q.id].objectives) do textRow(objective(o),12,nil,32) end
                        end
                        if not m.syncedAt or GetTime()-m.syncedAt>120 then
                            if q.polledAt then textRow("Quest membership checked "..age(q.polledAt),10,{0.57,0.62,0.7},32) end
                        end
                    end
                    y=y+2
                end)
                card:SetHeight(y-start+4);y=y+9
            end
            if not self.db.combineShared then section("Both on",shared,true) end
            section("They're on, I'm not",other,false)
        end
        y=y+6
    end
    self.child:SetHeight(math.max(1,y))
    if self.scroll then
        local height=self.scroll:GetHeight()
        if self.public(height,"number") and height>0 then
            local maxScroll=math.max(0,y-height)
            if self.scroll:GetVerticalScroll()>maxScroll then self.scroll:SetVerticalScroll(maxScroll) end
        end
    end
    self.footer:SetText(self.demo and "PREVIEW - sample quests" or
        ((self.QuestieOwnsTracker and self:QuestieOwnsTracker()) and "Questie enabled - party quests in a separate window") or
        self.sweepStatus or "Native discovery + optional full-log sync")
end
function A:SaveWindowSize()
    if self.db.collapsed then return end
    self.db.size={width=self.window:GetWidth(),height=self.window:GetHeight()}
    self.db.position={x=self.window:GetLeft(),y=self.window:GetTop()}
end
function A:ResizeLayout(width,height)
    self.contentWidth=math.max(334,width-46)
    if self.child then self.child:SetWidth(self.contentWidth) end
    if self.footer then self.footer:SetWidth(math.max(280,width-45)) end
    if not self.db.collapsed and height>=280 then self.db.size={width=width,height=height} end
    self.layoutDirty=true
end
function A:InitUI()
    local w=CreateFrame("Frame","SimplyPartyQuestsFrame",UIParent,"BasicFrameTemplateWithInset")
    self.window=w
    local size=self.db.size or {}
    local width=type(size.width)=="number" and math.max(380,math.min(1200,size.width)) or 460
    local height=type(size.height)=="number" and math.max(280,math.min(1200,size.height)) or 540
    self.db.size={width=width,height=height}
    w:SetSize(width,height);w:SetResizable(true)
    if w.SetResizeBounds then w:SetResizeBounds(380,280,1200,1200)
    else w:SetMinResize(380,280);w:SetMaxResize(1200,1200) end
    self:StyleQuestDialog(w)
    if self.readable(w.TitleText) then w.TitleText:Hide() end
    if self.readable(w.CloseButton) then
        w.CloseButton:SetScript("OnClick",function() self:SetViewShown(false) end)
    end
    w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true);w:SetFrameStrata("MEDIUM")
    local pos=self.db.position
    if pos then w:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",pos.x,pos.y) else w:SetPoint("CENTER",UIParent,"CENTER",310,0) end
    local bar=CreateFrame("Frame",nil,w);bar:SetPoint("TOPLEFT");bar:SetPoint("TOPRIGHT");bar:SetHeight(34)
    if self.readable(w.CloseButton) then w.CloseButton:SetFrameLevel(bar:GetFrameLevel()+2) end
    bar:EnableMouse(true);bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function() if not self.db.locked then w:StartMoving() end end)
    bar:SetScript("OnDragStop",function() w:StopMovingOrSizing();self.db.position={x=w:GetLeft(),y=w:GetTop()} end)
    local title=label(bar,14);title:SetPoint("LEFT",12,0);title:SetText("Party Quests - Alpha");title:SetTextColor(1,0.82,0)
    self.collapse=button(bar,"-",26,function() self:SetViewCollapsed(self.body:IsShown()) end);self.collapse:SetPoint("RIGHT",-32,0)
    self.settingsButton=button(bar,"Settings",74,function() self:OpenSettings() end);self.settingsButton:SetPoint("RIGHT",self.collapse,"LEFT",-6,0)
    local body=CreateFrame("Frame",nil,w);self.body=body;body:SetPoint("TOPLEFT",0,-34);body:SetPoint("BOTTOMRIGHT")
    local refresh=button(body,"Refresh",76,function() if not self.demo then self:RefreshParty() end end);refresh:SetPoint("TOPLEFT",12,-5)
    self.combineButton=button(body,"",240,function() self:SetCombineShared(not self.db.combineShared) end);self.combineButton:SetPoint("LEFT",refresh,"RIGHT",10,0)
    self.zoneButton=button(body,"",160,function() self:SetGroupByZone(not self.db.groupByZone) end);self.zoneButton:SetPoint("TOPLEFT",12,-32)
    self.trackerButton=button(body,"Dock beside tracker",164,function() self:SetDisplayMode("blizzard") end);self.trackerButton:SetPoint("LEFT",self.zoneButton,"RIGHT",8,0)
    self.windowShareButton=button(body,"Share quest log",140,function()
        local draft=self.questLogShareDraft;self.questLogShareDraft=nil
        self:OpenQuestLogShare(draft)
    end)
    self.windowShareButton:SetScript("OnMouseDown",function()
        if self.CaptureQuestLogChatDraft then self.questLogShareDraft=self:CaptureQuestLogChatDraft() end
    end)
    self.windowShareButton:SetPoint("TOPLEFT",12,-60)
    local scroll=CreateFrame("ScrollFrame",nil,body,"UIPanelScrollFrameTemplate");self.scroll=scroll
    scroll:SetPoint("TOPLEFT",12,-91);scroll:SetPoint("BOTTOMRIGHT",-32,29)
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(414,1);scroll:SetScrollChild(child);self.child=child
    self.footer=label(body,10);self.footer:SetPoint("BOTTOMLEFT",12,10);self:StyleQuestDialogText(self.footer,"muted")
    local grip=CreateFrame("Button",nil,w);self.resizeGrip=grip
    grip:SetSize(20,20);grip:SetPoint("BOTTOMRIGHT",-1,1)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown",function(_,key)
        if key=="LeftButton" and not self.db.locked and not self.db.collapsed then self.resizing=true;w:StartSizing("BOTTOMRIGHT") end
    end)
    local function stopSizing()
        if not self.resizing then return end
        self.resizing=nil;w:StopMovingOrSizing();self:SaveWindowSize()
        self:ResizeLayout(w:GetWidth(),w:GetHeight());self.layoutDirty=nil;self:Render()
    end
    grip:SetScript("OnMouseUp",stopSizing);grip:SetScript("OnHide",stopSizing)
    w:SetScript("OnSizeChanged",function(_,newWidth,newHeight) self:ResizeLayout(newWidth,newHeight) end)
    self:ResizeLayout(width,height)
    self:SetCollapsed(self.db.collapsed);w:SetShown(self:EffectiveDisplayMode()~="blizzard" and not self.db.hidden);self:Render()
end
function A:Demo()
    self.demo=not self.demo
    self.demoOwn={[101]={id=101,title="A Hunter's Request",objectives={{text="Boar tusks: 4/6",done=4,total=6}}}}
    self.demoMembers={
        a={guid="preview-a",name="Mara",class="MAGE",connected=true,syncedAt=GetTime(),quests={
            [101]={id=101,title="A Hunter's Request",objectives={{text="Boar tusks: 2/6",done=2,total=6}}},
            [102]={id=102,title="Supplies for the Road",objectives={{text="Linen cloth: 5/10",done=5,total=10}}}}},
        b={guid="preview-b",name="Rowan",class="WARRIOR",connected=true,quests={
            [101]={id=101,title="A Hunter's Request",objectives={{text="Boar tusks: 1/6",done=1,total=6}}},
            [103]={id=103,title="Trouble at the Mine",seen=GetTime(),objectives={{text="Kobolds slain: 3/8",done=3,total=8}}}}}}
    self.db.expanded["preview-a"]=true;self.db.expanded["preview-b"]=false
    self.window:Show();self:SetCollapsed(false);self:Render()
end
SLASH_SIMPLYPARTYQUESTS1="/spq"
SLASH_SIMPLYPARTYQUESTS2="/ppq"
SlashCmdList.SIMPLYPARTYQUESTS=function(msg)
    msg=(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg=="" or msg=="settings" or msg=="options" or msg=="help" then A:OpenSettings()
    elseif msg=="demo" then A:SetDisplayMode("window");A:Demo()
    elseif msg=="tracker" then A:SetDisplayMode("blizzard")
    elseif msg=="window" then A:SetDisplayMode("window")
    elseif msg=="combine" or msg=="combine on" or msg=="combine off" then A:SetCombineShared(msg=="combine on" or (msg=="combine" and not A.db.combineShared))
    elseif msg=="zone" or msg=="zone on" or msg=="zone off" then A:SetGroupByZone(msg=="zone on" or (msg=="zone" and not A.db.groupByZone))
    elseif msg=="blizzard" or msg=="blizzard refresh" then
        if A:NativeTrackerWritesAllowed() then
            A:QueueNativeTracker("manual",true);print("Party Quests Forever: native tracker redraw queued; waits until out of combat.")
        else print("Party Quests Forever: native tracker repair is paused while Questie owns the tracker.") end
    elseif msg=="blizzard on" or msg=="blizzard off" then
        A:SetNativeRepair(msg=="blizzard on")
        print("Party Quests Forever: delayed native tracker redraw "..(A.db.nativeTrackerRepair and "on." or "off."))
    elseif msg=="clear" then
        for _,m in pairs(A.members) do if not m.syncedAt then m.quests={} end end;A:Render()
    elseif msg=="lock" then A.db.locked=not A.db.locked;print("Party Quests Forever: dragging "..(A.db.locked and "locked." or "unlocked."))
    elseif msg=="reset" then A:ResetWindowLayout(true)
    elseif msg=="refresh" then A:RefreshParty()
    elseif msg=="scan" then A:StartSweep()
    elseif msg=="status" then print("Party Quests Forever: "..(A.sweepStatus or "Idle").."; "..A:SweepSummary())
        local s=A.liveStats
        if s then print(string.format("Live progress: %d calls, %d count changes, %d repeated counts, %d errors. /spq report",s.queries,s.changes,s.repeated,s.errors)) end
    elseif msg=="diag on" then
        A:SetDetailedDiagnostics(true,true)
        print("Party Quests Forever: diagnostic capture on. Use /spq report to copy it.")
    elseif msg=="diag off" then A:SetDetailedDiagnostics(false);print("Party Quests Forever: diagnostic capture off.")
    elseif msg=="inspect" then A:StartShareApiProbe()
    elseif msg=="report" then A:ShowDiagnosticReport()
    elseif msg=="show" then A:SetViewShown(true)
    elseif msg=="hide" then A:SetViewShown(false)
    elseif msg=="toggle" then
        local visible=A:EffectiveDisplayMode()=="blizzard" and not A.db.trackerHidden or A:EffectiveDisplayMode()=="window" and not A.db.hidden
        A:SetViewShown(not visible)
    else A:OpenSettings() end
    if A.SyncSettings then A:SyncSettings() end
end
