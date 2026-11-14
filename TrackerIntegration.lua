local _, A = ...
local function combat() return InCombatLockdown and InCombatLockdown() end
local function invoke(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a=pcall(fn,...);if ok then return a end
end
local function nativeColor(role)
    local c=OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR[role]
    if c then return {c.r,c.g,c.b} end
    if role=="Header" then return {1,0.82,0} end
    if role=="Complete" then return {0.51,0.81,0.6} end
    return {0.8,0.8,0.8}
end
local function completeColor()
    return "|cff00ff00"
end
A.integration={dirty=true,nextTry=0,status="waiting for Blizzard tracker"}
local function progress(name,q,remote,connected)
    local label=name..(connected==false and " (offline, cached)" or "")..": "
    if A:IsQuestReady(q) then return label..completeColor().."Ready for turn-in|r" end
    local parts={}
    for _,o in ipairs(q.objectives or {}) do
        local text=o.text or "Objective"
        if A:IsGenericObjective(text) then text="Unnamed step" end
        if o.total and o.total>0 and not text:find("%d+%s*/%s*%d+") then text=text.." "..(o.done or "?").."/"..o.total end
        if remote and (o.done==nil or o.total==nil) then text=text.." (progress unknown)" end
        parts[#parts+1]=text
    end
    return label..(#parts>0 and table.concat(parts,"; ") or "progress unknown")
end
function A:BuildTrackerEntries()
    local view=self:BuildPartyViewData()
    local members=view.members
    local entries,sources={},{}
    local function source(key,name,quests,member)
        sources[#sources+1]={key=key,name=name,quests=quests,member=member}
    end
    if self.db.combineShared and #view.combined>0 then source("all","Shared quests",view.combined) end
    for _,m in ipairs(members) do
        local data=view.sections[m.guid]
        sources[#sources+1]={kind="member",member=m,count=data.count}
        if not (self.db.trackerMembersClosed or {})[m.guid] then
            if not self.db.combineShared and #data.shared>0 then source(m.guid..":shared",m.name.." — Both on",data.shared,m) end
            if #data.other>0 then source(m.guid..":other",m.name.." — Other quests",data.other,m) end
        end
    end
    local closed=self.db.trackerGroupsClosed or {}
    for _,s in ipairs(sources) do
        if s.kind=="member" then
            local m=s.member
            entries[#entries+1]={kind="member",key=m.guid,closed=(self.db.trackerMembersClosed or {})[m.guid],title=m.name.." ("..s.count..")",name=m.name,class=m.class,count=s.count,connected=m.connected,syncedAt=m.syncedAt,sweepAt=m.sweepAt}
            if s.count==0 and not (self.db.trackerMembersClosed or {})[m.guid] then
                entries[#entries+1]={kind="empty",title=m.connected==false and "No cached quests." or (m.syncedAt and "No active quests." or "No quests discovered yet.")}
            end
        else
        local groups=self.db.groupByZone and self:GroupQuestsByZone(s.quests) or {{key="flat",name="",quests=s.quests}}
        if #groups==0 then groups={{key="flat",name="",quests={}}} end
        for _,g in ipairs(groups) do
            table.sort(g.quests,function(a,b) if a.title==b.title then return a.id<b.id end;return a.title<b.title end)
            local groupKey=s.key..":"..g.key
            entries[#entries+1]={kind="group",key=groupKey,title=s.name..(g.name~="" and (" / "..g.name) or "").." ("..#g.quests..")",memberName=s.member and s.member.name,section=s.member and (s.key:match(":shared$") and "Shared with you" or "Other quests") or "Shared quests",sourceKey=s.key,zone=g.name,count=#g.quests,closed=closed[groupKey]}
            if not closed[groupKey] then
                if #g.quests==0 then entries[#entries+1]={kind="empty",title=s.member and (s.member.syncedAt and "No quests in this section." or "None discovered yet.") or "No shared quests discovered yet."} end
                for _,q in ipairs(g.quests) do
                    local key=s.member and (s.member.guid..":"..q.id) or ("all:"..q.id)
                    local lines={}
                    if view.own[q.id] then lines[#lines+1]=progress("You",view.own[q.id],false) end
                    local participants=q.participants or {s.member}
                    for _,m in ipairs(participants) do
                        if m and m.quests[q.id] then lines[#lines+1]=progress(m.name,m.quests[q.id],true,m.connected) end
                    end
                    local requirements=q.requirements
                    if not requirements and q.participants then
                        for _,m in ipairs(q.participants) do
                            local r=m.quests[q.id].requirements
                            if r and #r>0 then requirements=r;break end
                        end
                    end
                    local title=q.title..(self:IsQuestReady(q) and (" "..completeColor().."[Ready]|r") or "")
                    if q.participants then title=title.." ["..(#q.participants+1).."/"..(#members+1).." players]" end
                    entries[#entries+1]={kind="quest",key=key,id=q.id,title=title,ownerGuid=s.member and s.member.guid,lines=lines,requirements=requirements,context=s.name..(g.name~="" and (" / "..g.name) or ""),open=self.db.questExpanded[key]}
                end
            end
        end
    end
    end
    return entries,#members
end
function A:InvalidateTrackerIntegration()
    local s=self.integration
    s.dirty=true;s.due=s.due or (GetTime()+0.25)
end
function A:SetDisplayMode(mode)
    if mode~="blizzard" and mode~="window" then return end
    self.db.displayMode=mode;self.db.trackerHidden=false
    if mode=="window" then self.db.hidden=false end
    self.integration.nextTry=0;self:InvalidateTrackerIntegration()
    if self.window then self.window:SetShown(mode=="window") end
    self:TrackerIntegrationTick()
end
function A:RefreshParty()
    self:ReadOwn();self:Request();self:ScanUnit("target");self:RefreshKnown();self:StartSweep()
end
-- This panel is anchored beside the tracker, never inserted into its module list.
-- Its own scroll area and fonts are independent of Blizzard's narrow columns.
function A:SetTrackerSide(side)
    if side~="left" and side~="right" then return end
    self.db.trackerSide=side;self:InvalidateTrackerIntegration();self:SyncSettings()
end
function A:SetSidebarWidth(width)
    self.db.sidebarWidth=math.max(320,math.min(640,width))
    self:InvalidateTrackerIntegration();self:SyncSettings()
end
function A:ShouldShowPartyView()
    return self.demo or next(self.members)~=nil or self.soloOverride==true
end
function A:TogglePartyTracker()
    local frame=self.db.displayMode=="blizzard" and self.sidebar or self.window
    self:SetViewShown(not (frame and frame:IsShown()))
    self:TrackerIntegrationTick()
end
function A:EnsurePartyTrackerButton(tracker)
    if not self.partyTrackerButton then
        local b=CreateFrame("Button","SimplyPartyQuestsMainToggle",UIParent,"UIPanelButtonTemplate")
        b:SetNormalFontObject(ObjectiveTrackerLineFont or GameFontNormal)
        b:SetSize(96,20);b:SetText("Party Quests");b:SetFrameStrata("MEDIUM")
        b:SetScript("OnClick",function() A:TogglePartyTracker() end)
        self.partyTrackerButton=b
    end
    local b=self.partyTrackerButton
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local minimize=header and self.readable(header.MinimizeButton) and header.MinimizeButton or nil
    local anchor=minimize or header or tracker
    if self.integration.buttonAnchor~=anchor then
        b:ClearAllPoints()
        if minimize then b:SetPoint("RIGHT",minimize,"LEFT",-6,0)
        else b:SetPoint("TOPRIGHT",anchor,"TOPRIGHT",-24,-3) end
        b:SetFrameLevel(tracker:GetFrameLevel()+10)
        self.integration.buttonAnchor=anchor
    end
    -- Parent visibility handles header hiding immediately, including during combat.
    -- A tracker frame can remain shown even when its empty header is hidden.
    b:SetParent(header or tracker)
    b:SetShown(header~=nil and header:IsShown() and tracker:IsShown())
end
function A:TrackerEntryClick(row,button)
    if row.kind=="quest" then self.shareProbeSelected=row.id end
    if combat() then return end
    if IsShiftKeyDown and IsShiftKeyDown() then self:RefreshParty();return end
    if row.kind=="member" then
        self.db.trackerMembersClosed=self.db.trackerMembersClosed or {}
        self.db.trackerMembersClosed[row.key]=not self.db.trackerMembersClosed[row.key]
    elseif row.kind=="group" then self.db.trackerGroupsClosed[row.key]=not self.db.trackerGroupsClosed[row.key]
    elseif row.kind=="quest" then
        if button=="RightButton" and self.own[row.id] and type(QuestMapFrame_OpenToQuestDetails)=="function" then
            QuestMapFrame_OpenToQuestDetails(row.id);return
        end
        self.db.questExpanded[row.key]=not self.db.questExpanded[row.key]
    end
    self:Render();self:InvalidateTrackerIntegration()
end
local function applyFont(f,role)
    f:SetFontObject(role=="header" and (ObjectiveTrackerHeaderFont or GameFontNormal) or (ObjectiveTrackerLineFont or GameFontHighlightSmall))
end
local function text(parent,role,color)
    local f=parent:CreateFontString(nil,"ARTWORK")
    applyFont(f,role);f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
    f:SetTextColor(unpack(color));return f
end
function A:InitTrackerSidebar()
    if self.sidebar then return end
    local f=CreateFrame("Frame","SimplyPartyQuestsSidebar",UIParent,"BackdropTemplate")
    self.sidebar=f;f:SetSize(420,540);f:SetClampedToScreen(true);f:SetFrameStrata("MEDIUM")
    -- Keep the party sidebar background strictly inside our own frame.
    -- A simple texture avoids NineSlice edge bleed into Blizzard's tracker.
    f.trackerBackground=f:CreateTexture(nil,"BACKGROUND")
    f.trackerBackground:SetAllPoints(f)
    f.trackerBackground:SetColorTexture(0,0,0,1)
    f.trackerBackground:SetAlpha(0)
    f.title=text(f,"header",nativeColor("Header"));f.title:SetPoint("TOPLEFT",7,-38);f.title:SetText("Party Quests")
    local headerArt=f:CreateTexture(nil,"BACKGROUND");f.headerArt=headerArt
    headerArt:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
    headerArt:SetPoint("TOPLEFT",0,-32);headerArt:SetPoint("TOPRIGHT",0,-32);headerArt:SetHeight(26)
    local function button(label,width,callback)
        local b=CreateFrame("Button",nil,f);b:SetSize(width,22)
        local labelFont=text(b,"line",nativeColor("Header"));labelFont:SetPoint("CENTER");labelFont:SetText(label)
        b.caption=labelFont;b.SetText=function(_,v) labelFont:SetText(v) end
        b:SetScript("OnClick",callback)
        b:SetScript("OnEnter",function() labelFont:SetTextColor(1,1,1) end)
        b:SetScript("OnLeave",function() labelFont:SetTextColor(unpack(nativeColor("Header"))) end)
        return b
    end
    -- Blizzard's native tracker minimize button is the only master collapse control.
    f.settings=button("Settings",56,function() A:OpenSettings() end);f.settings:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-38)
    f.refresh=button("Refresh",54,function() A:RefreshParty() end);f.refresh:SetPoint("RIGHT",f.settings,"LEFT",-6,0)
    f.share=button("Share",42,function()
        local draft=A.questLogShareDraft;A.questLogShareDraft=nil
        A:OpenQuestLogShare(draft);A.questLogShareDraft=nil
    end)
    f.share:SetPoint("RIGHT",f.refresh,"LEFT",-6,0)
    f.share:SetScript("OnMouseDown",function()
        if not A.questLogShareDraft then A.questLogShareDraft=A:CaptureQuestLogChatDraft() end
    end)
    f.share:SetScript("OnEnter",function(button)
        f.share.caption:SetTextColor(1,1,1)
        A.questLogShareHover=true;A.questLogShareDraft=A:CaptureQuestLogChatDraft()
        GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
        GameTooltip:SetText("Share Quest Log")
        GameTooltip:AddLine("Draft a chat link to your current quests and objective progress.",1,1,1,true)
        GameTooltip:Show()
    end)
    f.share:SetScript("OnLeave",function()
        f.share.caption:SetTextColor(unpack(nativeColor("Header")))
        A.questLogShareHover=false;A.questLogShareDraft=nil;GameTooltip:Hide()
    end)
    f.hint=text(f,"line",nativeColor("Normal"));f.hint:SetPoint("BOTTOMLEFT",4,0);f.hint:SetText("Mouse wheel to scroll")
    f.scroll=CreateFrame("ScrollFrame",nil,f)
    f.scroll:SetPoint("TOPLEFT",7,-68)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel",function(_,delta)
        local max=f.maxScroll or 0
        f.scroll:SetVerticalScroll(math.max(0,math.min(max,(f.scroll:GetVerticalScroll() or 0)-delta*36)))
    end)
    f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(380,1);f.scroll:SetScrollChild(f.child)
    f.rows={};f.contentHeight=1;f.heightLimit=420;f.maxScroll=0;f:Hide()
end
function A:SetTrackerSidebarHeaderLayout(nativeVisible)
    local f=self.sidebar
    local offset=nativeVisible and 32 or 0
    if f.headerOffset==offset then return end
    f.headerOffset=offset
    -- Only reserve an All Objectives row when Blizzard actually displays it.
    f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",f,"TOPLEFT",7,-6-offset)
    f.headerArt:ClearAllPoints()
    f.headerArt:SetPoint("TOPLEFT",f,"TOPLEFT",0,-offset)
    f.headerArt:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,-offset)
    f.settings:ClearAllPoints();f.settings:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-6-offset)
    f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7,-36-offset)
    self.integration.dirty=true
end
function A:RenderTrackerSidebar(entries,memberCount)
    local f=self.sidebar;local width=f:GetWidth()-8
    f.child:SetWidth(width)
    local used,y=0,0
    local function row(label,role,color,indent,entry,liveQuestKey,liveLine)
        used=used+1
        local b=f.rows[used]
        if not b then
            b=CreateFrame("Button",nil,f.child);b.label=text(b,role,color)
            b.headerBackground=false
            b.label:SetPoint("TOPLEFT",0,0);b:RegisterForClicks("LeftButtonUp","RightButtonUp")
            b:SetScript("OnClick",function(_,key) if b.entry then A:TrackerEntryClick(b.entry,key) end end)
            b:SetScript("OnDoubleClick",function(_,key)
                local e=b.entry
                if key=="LeftButton" and e and e.kind=="quest" and e.ownerGuid and not A.own[e.id] then A:RequestQuestShare(e.id,e.ownerGuid) end
            end)
            f.rows[used]=b
        end
        b.entry=entry;b.liveQuestKey=liveQuestKey;b.liveLine=liveLine
        applyFont(b.label,role);b.label:SetTextColor(unpack(color))
        local heading=entry and (entry.kind=="member" or entry.kind=="group")
        if heading and not b.headerBackground then
            b.headerBackground=b:CreateTexture(nil,"BACKGROUND")
            b.headerBackground:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
            b.headerBackground:SetAllPoints(b)
        end
        if b.headerBackground then b.headerBackground:SetShown(not not heading) end
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT",heading and 7 or 0,heading and -5 or 0)
        b.label:SetWidth(width-indent-(heading and 14 or 0));b.label:SetText(label)
        local height=math.max(heading and 26 or 1,b.label:GetStringHeight()+(heading and 10 or 3))
        b:ClearAllPoints();b:SetPoint("TOPLEFT",indent,-y);b:SetSize(width-indent,height)
        b:EnableMouse(entry~=nil);b:Show();y=y+height+2
    end
    if memberCount==0 then row("Join a party to see available quests.","line",nativeColor("Normal"),0)
    elseif #entries==0 then row("No party quests discovered yet. Try Refresh or Scan in Settings.","line",nativeColor("Normal"),0)
    else
        local previousSource,previousMember
        for _,e in ipairs(entries) do
            if e.kind=="member" then
                if used>0 then y=y+10 end
                row((e.closed and "+ " or "- ")..e.title,"header",nativeColor("Header"),0,e)
                local status=e.syncedAt and "Full log synced" or "Discovered quests"
                if e.connected==false then status=status.." - offline, cached" end
                if not e.closed then row(status,"line",nativeColor("Normal"),8) end
                previousMember=e.name;previousSource=nil
            elseif e.kind=="empty" then
                row(e.title,"line",nativeColor("Normal"),20)
            elseif e.kind=="group" then
                if e.sourceKey~=previousSource then
                    if used>0 then y=y+10 end
                    if e.memberName and e.memberName~=previousMember then
                        row(e.memberName,"line",nativeColor("Header"),0)
                        previousMember=e.memberName
                    end
                    if e.zone and e.zone~="" then row(e.section,"line",nativeColor("Normal"),8) end
                    previousSource=e.sourceKey
                end
                local heading=(e.zone and e.zone~="" and e.zone or e.section).." ("..e.count..")"
                row((e.closed and "+ " or "- ")..heading,"header",nativeColor("Header"),8,e)
            else
                row((e.open and "- " or "+ ")..e.title,"line",nativeColor("Header"),20,e,e.key,0)
                if e.open then
                    for _,r in ipairs(e.requirements or {}) do row(r.text,"line",nativeColor("Normal"),34) end
                    for i,line in ipairs(e.lines or {}) do row(line,"line",nativeColor("Normal"),34,nil,e.key,i) end
                end
            end
        end
    end
    for i=used+1,#f.rows do f.rows[i].entry=nil;f.rows[i].liveQuestKey=nil;f.rows[i].liveLine=nil;f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,y))
    f.contentHeight=y
    self:SizeTrackerSidebar()
end
function A:SizeTrackerSidebar()
    local f=self.sidebar
    local limit=f.heightLimit or 420
    local content=f.contentHeight or 1
    local padding=44+(f.headerOffset or 32)
    local overflow=content+padding>limit
    local viewport=math.max(1,math.min(content,limit-padding-(overflow and 14 or 0)))
    f.scroll:SetSize(f:GetWidth()-6,math.max(1,viewport))
    f.maxScroll=math.max(0,content-viewport)
    f.hint:SetShown(overflow)
    f:SetHeight(math.min(limit,content+padding+(overflow and 14 or 0)))
    local offset=f.scroll:GetVerticalScroll() or 0
    if offset>f.maxScroll then f.scroll:SetVerticalScroll(f.maxScroll) end
end
-- Extend only the native header's visual anchors, never its quest column width.
-- Keep original anchors so hiding/detaching restores Blizzard's header exactly.
function A:RestoreJoinedTrackerHeader()
    local saved=self.integration.joinedHeader
    if not saved then return end
    for _,item in ipairs(saved.items) do
        item.region:ClearAllPoints()
        for _,point in ipairs(item.points) do item.region:SetPoint(unpack(point)) end
    end
    self.integration.joinedHeader=nil
end
function A:JoinTrackerHeader(tracker,enabled)
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local side=self.db.trackerSide=="right" and "right" or "left"
    local saved=self.integration.joinedHeader
    if saved and (not enabled or saved.header~=header or saved.side~=side) then self:RestoreJoinedTrackerHeader();saved=nil end
    if not enabled or not header or saved then return end
    local background=self.readable(header.Background) and header.Background or nil
    local title=self.readable(header.Text) and header.Text or nil
    local state={header=header,side=side,items={}}
    local function save(region)
        local points={}
        for i=1,region:GetNumPoints() do points[#points+1]={region:GetPoint(i)} end
        state.items[#state.items+1]={region=region,points=points}
        region:ClearAllPoints()
    end
    local left=side=="left" and self.sidebar or header
    local right=side=="right" and self.sidebar or header
    if background then
        save(background)
        background:SetPoint("TOPLEFT",left,"TOPLEFT",0,0)
        background:SetPoint("BOTTOMRIGHT",right,"TOPRIGHT",0,-26)
    end
    if title then
        save(title);title:SetPoint("LEFT",left,"TOPLEFT",7,-13)
    end
    self.integration.joinedHeader=state
end
function A:UpdateTrackerSidebarCombat()
    local f,s=self.sidebar,self.integration
    if not f or not f:IsShown() or not s.dirty or (s.due and GetTime()<s.due) then return end
    -- The sidebar's existing FontStrings belong to our own non-secure rows.
    -- Never create/move/resize frames or touch Blizzard's tracker while locked.
    local ok,err=pcall(function()
        local byKey={}
        for _,e in ipairs(self:BuildTrackerEntries()) do
            if e.kind=="quest" then byKey[e.key]=e end
        end
        for _,row in ipairs(f.rows) do
            local e=row.liveQuestKey and byKey[row.liveQuestKey]
            if e and row:IsShown() then
                local value=row.liveLine==0 and ((e.open and "- " or "+ ")..e.title)
                    or (e.lines or {})[row.liveLine]
                if value then row.label:SetText(value) end
            end
        end
    end)
    if ok then s.dirty=false;s.due=nil
    else
        s.lastError=self.public(err,"string") and err:sub(1,180) or "combat text refresh failed"
        s.due=GetTime()+1
    end
end
function A:SyncTrackerSidebarOpacity(tracker)
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    -- This is the normalized background value used by Blizzard's Forever
    -- ObjectiveTrackerManager:SetOpacity, not the whole frame's text alpha.
    local manager=ObjectiveTrackerManager
    local alpha=self.readable(manager) and manager.backgroundAlpha or nil
    if not self.public(alpha,"number") or alpha~=alpha then alpha=0.28 end
    alpha=math.max(0.12,math.min(0.38,alpha))
    if f.trackerBackgroundAlpha~=alpha then
        f.trackerBackground:SetAlpha(alpha);f.trackerBackgroundAlpha=alpha
    end
end
function A:SyncTrackerSidebarAppearance(tracker)
    if combat() then return end
    local f,s=self.sidebar,self.integration
    if not f then return end
    local now=GetTime()
    if s.nextAppearance and now<s.nextAppearance then return end
    s.nextAppearance=now+0.25
    local parts={}
    local function add(value)
        if self.public(value,"string") or self.public(value,"number") or self.public(value,"boolean") then
            parts[#parts+1]=tostring(value)
        else parts[#parts+1]="-" end
    end
    -- Font objects can change in place after Edit Mode or accessibility changes.
    -- Include their shadow/outline/spacing as well as face and point size.
    for _,font in ipairs({ObjectiveTrackerHeaderFont or GameFontNormal,ObjectiveTrackerLineFont or GameFontHighlightSmall}) do
        for _,method in ipairs({"GetFont","GetShadowOffset","GetShadowColor","GetSpacing"}) do
            if type(font[method])=="function" then
                local ok,a,b,c,d=pcall(font[method],font)
                if ok then add(a);add(b);add(c);add(d) end
            end
        end
    end
    for _,role in ipairs({"Header","Normal","NormalHighlight","Complete"}) do
        for _,v in ipairs(nativeColor(role)) do add(v) end
    end
    local scale=tracker and invoke(tracker.GetEffectiveScale,tracker)
    local parentScale=UIParent and invoke(UIParent.GetEffectiveScale,UIParent)
    if self.public(scale,"number") and self.public(parentScale,"number") and scale>0 and parentScale>0 then
        scale=scale/parentScale
        if scale==scale and scale<100 then add(scale) else scale=nil end
    else scale=nil end
    local signature=table.concat(parts,";")
    if s.appearanceSignature==signature then return end
    s.appearanceSignature=signature
    if scale and s.sidebarScale~=scale then f:SetScale(scale);s.sidebarScale=scale end
    local function refresh(region,role,color)
        if not region then return end
        applyFont(region,role);region:SetTextColor(unpack(nativeColor(color)))
    end
    refresh(f.title,"header","Header");refresh(f.partyOnlyTitle,"header","Header")
    refresh(f.hint,"line","Normal")
    for _,name in ipairs({"share","refresh","settings"}) do
        local button=f[name]
        if button then refresh(button.caption,"line","Header") end
    end
    -- Rebuild our rows to recalculate wrapping and height for the live fonts.
    s.dirty=true;s.due=nil
end
function A:TrackerSidebarHeightLimit(tracker)
    local function valid(value)
        return self.public(value,"number") and value==value and value>0 and value<math.huge
    end
    local setting=Enum and Enum.EditModeObjectiveTrackerSetting and Enum.EditModeObjectiveTrackerSetting.Height
    local height=tracker and setting and invoke(tracker.GetSettingValue,tracker,setting)
    if not valid(height) then height=tracker and tracker.editModeHeight end
    if not valid(height) then height=tracker and invoke(tracker.GetHeight,tracker) end
    if not valid(height) then height=420 end
    return height
end
function A:TrackerIntegrationTick()
    if not self.db then return end
    if combat() then self:UpdateTrackerSidebarCombat();return end
    if self.UpdateMinimapButton then self:UpdateMinimapButton() end
    local s=self.integration
    if ObjectiveTrackerFrame then self:EnsurePartyTrackerButton(ObjectiveTrackerFrame)
    elseif self.partyTrackerButton then self.partyTrackerButton:Hide() end
    if self.db.displayMode~="blizzard" then
        self:RestoreJoinedTrackerHeader()
        if self.sidebar then self.sidebar:Hide() end
        s.attached=false;s.status="pop-out window"
        if self.window then self.window:SetShown(not self.db.hidden and self:ShouldShowPartyView()) end
        return
    end
    local tracker=ObjectiveTrackerFrame
    if not tracker then
        self:RestoreJoinedTrackerHeader()
        if self.sidebar then self.sidebar:Hide() end
        s.attached=false;s.status="Blizzard tracker unavailable; using pop-out"
        if self.window then self.window:SetShown(not self.db.hidden and not self.db.trackerHidden and self:ShouldShowPartyView()) end
        return
    end
    self:InitTrackerSidebar()
    self:SyncTrackerSidebarOpacity(tracker)
    self:SyncTrackerSidebarAppearance(tracker)
    local f=self.sidebar
    local side=self.db.trackerSide=="right" and "right" or "left"
    local width=math.max(320,math.min(640,self.db.sidebarWidth or 420))
    -- Auto-size to our content, capped by the shared Edit Mode height setting.
    -- The native tracker can currently be empty/shorter than its configured cap.
    local height=self:TrackerSidebarHeightLimit(tracker)
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local nativeVisible=tracker:IsShown() and (not header or header:IsShown())
    local anchor=nativeVisible and header or tracker
    if s.anchor~=anchor or s.side~=side or s.nativeVisible~=nativeVisible then
        f:ClearAllPoints()
        f:SetParent(UIParent);f:SetFrameLevel(tracker:GetFrameLevel()+2)
        f:SetClampedToScreen(not nativeVisible)
        if not nativeVisible then f:SetPoint("TOPLEFT",anchor,"TOPLEFT",0,0)
        elseif side=="right" then f:SetPoint("TOPLEFT",anchor,"TOPRIGHT",0,0)
        else f:SetPoint("TOPRIGHT",anchor,"TOPLEFT",0,0) end
        s.anchor=anchor;s.side=side;s.nativeVisible=nativeVisible;s.dirty=true
    end
    self:SetTrackerSidebarHeaderLayout(nativeVisible)
    if f:GetWidth()~=width or f.heightLimit~=height then f:SetWidth(width);f.heightLimit=height;s.dirty=true end
    f.scroll:SetShown(true)
    self:SizeTrackerSidebar()
    local visible=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    self:JoinTrackerHeader(tracker,visible and nativeVisible)
    local allCollapsed=nativeVisible and invoke(tracker.IsCollapsed,tracker)==true
    f:SetShown(visible and not allCollapsed)
    self.window:Hide();s.attached=true
    s.status=nativeVisible and ("sidebar "..side) or "party-only tracker; native tracker empty/hidden"
    if s.dirty and (not s.due or GetTime()>=s.due) then
        local ok,err=pcall(function()
            s.entries,s.memberCount=self:BuildTrackerEntries()
            self:RenderTrackerSidebar(s.entries,s.memberCount)
        end)
        if ok then s.dirty=false;s.due=nil;s.lastError=nil
        else
            s.lastError=self.public(err,"string") and err:sub(1,180) or "unreadable error"
            s.status="sidebar layout failed; using pop-out";self.db.displayMode="window"
            f:Hide();self:RestoreJoinedTrackerHeader();self.db.hidden=false;self.window:Show();s.attached=false
        end
    end
end
local events=CreateFrame("Frame")
A.integrationEvents=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() A:InvalidateTrackerIntegration() end)
