local _,A=...
local function combat() return InCombatLockdown and InCombatLockdown() end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and not A.secret(v) then return v end
end
local function number(v) return A.public(v,"number") and v==v and math.abs(v)<100000 end
-- Read named UI geometry only. Never import Questie's runtime modules, parent
-- our pane to its tracker, or change its anchors, scripts, settings or children.
function A:ReadQuestieDockRect()
    local target=Questie_BaseFrame
    if not target or call(target.IsShown,target)~=true then return end
    local scale=call(target.GetEffectiveScale,target)
    local uiScale=UIParent and call(UIParent.GetEffectiveScale,UIParent)
    if not number(scale) or not number(uiScale) or scale<=0 or uiScale<=0 then return end
    local left,right,top,bottom=call(target.GetLeft,target),call(target.GetRight,target),call(target.GetTop,target),call(target.GetBottom,target)
    if not number(left) or not number(right) or not number(top) or not number(bottom) or right<=left or top<=bottom then return end
    local ratio=scale/uiScale
    left,right,top,bottom=left*ratio,right*ratio,top*ratio,bottom*ratio
    local sw,sh=call(UIParent.GetWidth,UIParent),call(UIParent.GetHeight,UIParent)
    if not number(sw) or not number(sh) or sw<=0 or sh<=0 then return end
    local width=math.max(320,math.min(640,self.db.sidebarWidth or 420))
    local side=self.db.trackerSide=="right" and "right" or "left"
    local gap=8
    local roomLeft,roomRight=left-gap,sw-right-gap
    if side=="left" and roomLeft<width and roomRight>roomLeft then side="right"
    elseif side=="right" and roomRight<width and roomLeft>roomRight then side="left" end
    local room=side=="left" and roomLeft or roomRight
    if room<320 then return end -- retain the standalone fallback if neither side fits
    width=math.min(width,room)
    local s=self.questieCompatibility
    local height=top-bottom
    if height>=128 then s.dockExpandedHeight=height else height=s.dockExpandedHeight or 420 end
    height=math.min(math.max(128,height),sh-16)
    local header=Questie_HeaderFrame
    local headerTop=header and call(header.IsShown,header)==true and call(header.GetTop,header)
    local hs=header and call(header.GetEffectiveScale,header)
    if number(headerTop) and number(hs) and hs>0 and math.abs(headerTop*hs/uiScale-top)<64 then top=headerTop*hs/uiScale+6 end
    top=math.max(48,math.min(sh-4,top))
    if top<128 then return end
    height=math.min(height,top-4)
    local x=side=="left" and left-gap-width or right+gap
    return {target=target,x=x,top=top,width=width,height=height,side=side}
end
function A:RefreshQuestieDockTarget()
    local s=self.questieCompatibility
    local requested=self.db.displayMode=="blizzard" and self:QuestieOwnsTracker()
    local rect=requested and (not s.dockRetryAt or GetTime()>=s.dockRetryAt) and self:ReadQuestieDockRect() or nil
    -- Do not move a formerly Blizzard-attached pane into a different layout
    -- during lockdown. An already-independent dock may follow Questie normally.
    if combat() and not s.dockActive then rect=nil end
    s.dockRect=rect;s.dockReady=rect~=nil
end
function A:QuestieDockActive()
    local s=self.questieCompatibility
    return not not (s and s.dockReady and self.db and self.db.displayMode=="blizzard" and self:QuestieOwnsTracker())
end
function A:SyncQuestieDockBackground()
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    local bg=f.trackerBackground
    local signature=tostring(f:GetWidth())..":"..tostring(f:GetHeight())
    local q=self.questieCompatibility
    if q.dockBackground~=signature then
        q.dockBackground=signature
        bg:ClearAllPoints();bg:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
        bg:SetWidth(f:GetWidth());bg:SetHeight(f:GetHeight());bg:SetAlpha(0.35)
    end
    f.trackerBackgroundAlpha=nil;f.backgroundJoinSignature=nil
    bg:SetShown(f:IsShown())
end
function A:QuestieDockTick()
    if not self:QuestieDockActive() then return false end
    local q,s=self.questieCompatibility,self.integration
    local rect=q.dockRect
    self:InitTrackerSidebar()
    local f=self.sidebar
    if not q.dockActive then
        q.dockActive=true;s.anchor=nil;s.side=nil;s.appearanceSignature=nil;s.sidebarScale=nil
        s.nativeVisible=false;s.nativeCollapsed=false;s.dirty=true;s.due=nil
        f:SetScale(1)
    end
    if combat() then
        if not q.dockInCombat then q.dockInCombat=true;q.dockCombatCollapsed=self.db.combatAutoHide~=false or self.db.trackerCollapsed==true end
    else q.dockInCombat=nil;q.dockCombatCollapsed=nil end
    local collapsed
    if q.dockInCombat then collapsed=q.dockCombatCollapsed else collapsed=not not self.db.trackerCollapsed end
    local signature=table.concat({rect.x,rect.top,rect.width,rect.height},":")
    if q.dockGeometry~=signature then
        q.dockGeometry=signature
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",rect.x,rect.top)
        f:SetWidth(rect.width);f.heightLimit=rect.height;s.dirty=true;s.due=nil
    end
    self:SetTrackerSidebarHeaderLayout(false)
    f.viewCollapsed=collapsed;f.scroll:SetShown(not collapsed);f.collapse:Show()
    local atlas=collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
    f.collapse.normal:SetAtlas(atlas);f.collapse.pushed:SetAtlas(atlas.."-pressed")
    local visible=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    f:SetShown(visible)
    if self.window then self.window:Hide() end
    if visible and s.dirty and (not s.due or GetTime()>=s.due) then
        local ok,err=pcall(function()
            s.entries,s.memberCount=self:BuildTrackerEntries()
            self:RenderTrackerSidebar(s.entries,s.memberCount)
        end)
        if ok then s.dirty=false;s.due=nil;s.lastError=nil
        else
            s.lastError=self.public(err,"string") and err:sub(1,180) or "Questie sidebar render failed"
            f:Hide();f.trackerBackground:Hide();q.dockReady=false;q.dockActive=nil
            q.dockRetryAt=GetTime()+10
            return false
        end
    end
    self:SizeTrackerSidebar();self:SyncQuestieDockBackground()
    s.attached=true;s.status="Questie sidebar "..rect.side
    return true
end
function A:LeaveQuestieDock()
    local q,s=self.questieCompatibility,self.integration
    if not q.dockActive then return end
    q.dockActive=nil;q.dockGeometry=nil;q.dockBackground=nil;q.dockInCombat=nil;q.dockCombatCollapsed=nil
    s.anchor=nil;s.side=nil;s.appearanceSignature=nil;s.sidebarScale=nil;s.nativeCollapsed=nil
    s.dirty=true;s.due=nil
    if self.sidebar then self.sidebar:Hide();self.sidebar.trackerBackground:Hide() end
end
