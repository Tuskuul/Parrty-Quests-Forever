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
    local compact=not next(self.members or {}) and not self.demo
    if compact then width=180 end
    local side=self.db.trackerSide=="right" and "right" or "left"
    local gap=2
    local roomLeft,roomRight=left-gap,sw-right-gap
    if side=="left" and roomLeft<width and roomRight>roomLeft then side="right"
    elseif side=="right" and roomRight<width and roomLeft>roomRight then side="left" end
    local room=side=="left" and roomLeft or roomRight
    if room<(compact and 180 or 320) then return end -- retain the standalone fallback if neither side fits
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
    if not compact and top-bottom>=128 then height=math.min(height,top-bottom) end
    local x=side=="left" and left-gap-width or right+gap
    return {target=target,x=x,top=top,width=width,height=height,side=side,compact=compact,scale=ratio}
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
local function rgba(frame,method)
    local fn=frame and frame[method]
    if type(fn)~="function" then return end
    local ok,r,g,b,a=pcall(fn,frame)
    if not ok then return end
    for _,v in ipairs({r,g,b,a}) do if not number(v) or v<0 or v>1 then return end end
    if not number(r) or not number(g) or not number(b) or not number(a) then return end
    return r,g,b,a
end
function A:ReadQuestieDockAppearance()
    local target=Questie_BaseFrame
    local p=self.readable(Questie) and self.readable(Questie.db) and self.readable(Questie.db.profile) and Questie.db.profile or nil
    local r,g,b,a=rgba(target,"GetBackdropColor")
    if not r then
        local c=p and self.readable(p.trackerBackdropColor) and p.trackerBackdropColor
        if c and p.trackerBackdropEnabled==true and p.trackerBackdropFader~=true and number(c.r) and number(c.g) and number(c.b) and number(c.a) then
            r,g,b,a=math.max(0,math.min(1,c.r)),math.max(0,math.min(1,c.g)),math.max(0,math.min(1,c.b)),math.max(0,math.min(1,c.a))
        else r,g,b,a=0,0,0,0 end
    end
    if p and p.trackerBackdropEnabled==false then a=0 end
    local br,bg,bb,ba=rgba(target,"GetBackdropBorderColor")
    if not br then br,bg,bb,ba=1,1,1,(p and p.trackerBorderEnabled==true and a or 0) end
    if p and (p.trackerBackdropEnabled==false or p.trackerBorderEnabled==false) then ba=0 end
    local alpha=target and call(target.GetEffectiveAlpha,target)
    local parentAlpha=UIParent and call(UIParent.GetEffectiveAlpha,UIParent)
    if not number(alpha) then alpha=target and call(target.GetAlpha,target) end
    if not number(parentAlpha) or parentAlpha<=0 then parentAlpha=1 end
    alpha=number(alpha) and math.max(0,math.min(1,alpha/parentAlpha)) or 1
    return r,g,b,a,br,bg,bb,ba,alpha
end
function A:OpenQuestieDockMenu()
    local f=self.sidebar
    if not f or not f:IsShown() then return end
    local menu=self.questieDockMenu
    if not menu then
        menu=CreateFrame("Frame","SimplyPartyQuestsDockMenu",UIParent,"BackdropTemplate")
        self.questieDockMenu=menu
        menu:SetSize(154,112);menu:SetFrameStrata("DIALOG");menu:EnableMouse(true)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        menu:SetBackdropColor(0.06,0.06,0.06,0.95)
        local choices={{"Share quests",function(draft) A:OpenQuestLogShare(draft) end},
            {"Refresh",function() A:RefreshParty() end},{"Settings",function() A:OpenSettings() end}}
        menu.buttons={}
        for i,choice in ipairs(choices) do
            local button=CreateFrame("Button",nil,menu,"UIPanelButtonTemplate")
            button:SetSize(138,26);button:SetPoint("TOPLEFT",8,-8-(i-1)*32);button:SetText(choice[1])
            local action=choice[2]
            button:SetScript("OnClick",function() local draft=menu.draft;menu:Hide();action(draft) end)
            menu.buttons[i]=button
        end
        menu:SetScript("OnHide",function() menu.draft=nil end)
        menu:SetScript("OnUpdate",function()
            if not A:QuestieDockActive() or not A.sidebar:IsShown() or (menu.dismissAt and GetTime()>menu.dismissAt) then menu:Hide() end
        end)
        menu:Hide()
    end
    if menu:IsShown() then menu:Hide();self.questieCompatibility.dockDraft=nil;return end
    menu.draft=self.questieCompatibility.dockDraft or self:CaptureQuestLogChatDraft()
    self.questieCompatibility.dockDraft=nil
    menu:ClearAllPoints();menu:SetPoint("TOPRIGHT",f.settings,"BOTTOMRIGHT",0,-3)
    menu:SetClampedToScreen(true);menu.dismissAt=GetTime()+12;menu:Show();menu:Raise()
end
function A:StyleQuestieDock()
    local f,q=self.sidebar,self.questieCompatibility
    if not q.dockStyle then
        local font,size,flags=f.title:GetFont()
        q.dockStyle={font=font,size=size,flags=flags,settingsClick=f.settings:GetScript("OnClick"),settingsDown=f.settings:GetScript("OnMouseDown")}
        f.questieHeaderClick=f.questieHeaderClick or CreateFrame("Button",nil,f)
        f.questieHeaderClick:SetAllPoints(f.title);f.questieHeaderClick:RegisterForClicks("LeftButtonUp","RightButtonUp")
        local function capture() A.questieCompatibility.dockDraft=A:CaptureQuestLogChatDraft() end
        f.questieHeaderClick:SetScript("OnMouseDown",capture)
        f.settings:SetScript("OnMouseDown",capture)
        f.questieHeaderClick:SetScript("OnClick",function(_,button)
            if button=="RightButton" then A:OpenQuestieDockMenu()
            else A:SetViewCollapsed(not A.sidebar.viewCollapsed) end
        end)
        f.settings:SetScript("OnClick",function() A:OpenQuestieDockMenu() end)
    end
    local h=Questie_HeaderFrame
    local label=h and self.readable(h.trackedQuests) and h.trackedQuests.label
    if label and type(label.GetFont)=="function" then
        local ok,font,size,flags=pcall(label.GetFont,label)
        if ok and self.public(font,"string") and number(size) and size>0 and size<60 then
            local ratio=q.dockRect and q.dockRect.scale or 1
            f.title:SetFont(font,math.max(8,math.min(32,size*ratio)),self.public(flags,"string") and flags or "")
        end
    else f.title:SetFontObject(GameFontNormalSmall or GameFontNormal) end
    f.headerArt:Hide();f.share:Hide();f.refresh:Hide()
    f.settings:SetText("...");f.settings:SetSize(20,20)
    f.collapse:ClearAllPoints();f.collapse:SetPoint("LEFT",f.title,"RIGHT",5,0)
    f.settings:ClearAllPoints();f.settings:SetPoint("LEFT",f.collapse,"RIGHT",3,0)
    f.questieHeaderClick:Show()
    f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7,-26)
    f.questiePlain=true
end
function A:RestoreQuestieDockStyle()
    local f,q=self.sidebar,self.questieCompatibility
    local saved=q.dockStyle
    if not f or not saved then return end
    q.dockStyle=nil;q.dockAppearance=nil
    f.questiePlain=nil;f:SetAlpha(1);f.headerOffset=nil
    if saved.font and saved.size then f.title:SetFont(saved.font,saved.size,saved.flags) end
    f.headerArt:Show();f.share:Show();f.refresh:Show()
    f.settings:SetText("Settings");f.settings:SetSize(56,22);f.settings:SetScript("OnClick",saved.settingsClick);f.settings:SetScript("OnMouseDown",saved.settingsDown)
    if f.questieHeaderClick then f.questieHeaderClick:Hide() end
    if self.questieDockMenu then self.questieDockMenu:Hide() end
    if f.trackerBackground.questieArt then f.trackerBackground.questieArt:Hide() end
    f.trackerBackground.art:Show();f.trackerBackground:SetAlpha(1)
end

function A:SyncQuestieDockBackground()
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    local bg,q=f.trackerBackground,self.questieCompatibility
    if not bg.questieArt then
        bg.questieArt=CreateFrame("Frame",nil,bg,"BackdropTemplate");bg.questieArt:SetAllPoints(bg)
        bg.questieArt:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    end
    bg.art:Hide();bg.questieArt:Show()
    local signature=tostring(f:GetWidth())..":"..tostring(f:GetHeight())
    if q.dockBackground~=signature then
        q.dockBackground=signature;bg:ClearAllPoints();bg:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
        bg:SetWidth(f:GetWidth());bg:SetHeight(f:GetHeight())
    end
    local r,g,b,a,br,bgColor,bb,ba,alpha=self:ReadQuestieDockAppearance()
    local appearance=table.concat({r,g,b,a,br,bgColor,bb,ba,alpha},":")
    if q.dockAppearance~=appearance then
        q.dockAppearance=appearance
        bg.questieArt:SetBackdropColor(r,g,b,a);bg.questieArt:SetBackdropBorderColor(br,bgColor,bb,ba)
        bg:SetAlpha(alpha);f:SetAlpha(alpha)
    end
    f.trackerBackgroundAlpha=nil;f.backgroundJoinSignature=nil;bg:SetShown(f:IsShown())
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
    self:StyleQuestieDock()
    if rect.compact then collapsed=true end
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
    if not q.dockActive and not q.dockStyle then return end
    self:RestoreQuestieDockStyle()
    q.dockActive=nil;q.dockGeometry=nil;q.dockBackground=nil;q.dockInCombat=nil;q.dockCombatCollapsed=nil
    s.anchor=nil;s.side=nil;s.appearanceSignature=nil;s.sidebarScale=nil;s.nativeCollapsed=nil
    s.dirty=true;s.due=nil
    if self.sidebar then self.sidebar:Hide();self.sidebar.trackerBackground:Hide() end
end
