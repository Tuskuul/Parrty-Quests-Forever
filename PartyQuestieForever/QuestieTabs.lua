local _,P=...
local A=P.host
if not A then return end
-- Optional visual provider, shipped only on the Questie build branch. Questie's
-- named root is the sole foreign frame we reparent. No module imports, script
-- replacements, profile writes or quest-data hooks are needed.
local function read(frame,method,...)
    local fn=frame and frame[method]
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,frame,...)
    if ok and not A.secret(v) then return v end
end
local function number(v) return A.public(v,"number") and v==v and v>=0 and v<100000 end
function A:QuestieTabsRequested()
    local q=self.readable(Questie) and self.readable(Questie.db) and self.readable(Questie.db.profile) and Questie.db.profile
    return self.db and self.db.displayMode=="blizzard" and P:Layout()=="tabs"
        and q and q.trackerEnabled==true and self:QuestieOwnsTracker()
end
function A:QuestieTabsHeight(native,t)
    local h=read(native,"GetHeight")
    -- Questie's minimized root can be only 25px tall. Keep a usable party
    -- viewport without changing Questie's minimized state or saved dimensions.
    if number(h) and h>=128 then t.questieExpandedHeight=h end
    local screen=read(UIParent,"GetHeight") or 768
    local scale=read(native,"GetEffectiveScale") or 1
    local ui=read(UIParent,"GetEffectiveScale") or 1
    local top=read(native,"GetTop") or screen
    return math.max(48,math.min(t.questieExpandedHeight or 420,top-8,(screen-48)*ui/math.max(0.01,scale)))
end
function A:SyncQuestieTabsAppearance()
    local t,f=self.trackerTabs,self.sidebar
    local bg=f.trackerBackground
    if not bg.questieTabsArt then
        bg.questieTabsArt=CreateFrame("Frame",nil,bg,"BackdropTemplate")
        bg.questieTabsArt:SetAllPoints(bg)
    end
    local backdrop=read(t.native,"GetBackdrop")
    if self.readable(backdrop) then
        local i=self.readable(backdrop.insets) and backdrop.insets or {}
        local signature=table.concat({tostring(backdrop.bgFile),tostring(backdrop.edgeFile),tostring(backdrop.edgeSize),
            tostring(i.left),tostring(i.right),tostring(i.top),tostring(i.bottom)},":")
        if t.backdropSignature~=signature then
            bg.questieTabsArt:SetBackdrop(backdrop);t.backdropSignature=signature
        end
    end
    bg.art:Hide()
    if bg.questieArt then bg.questieArt:Hide() end
    local r,g,b,a,br,bc,bb,ba,alpha=self:ReadQuestieDockAppearance()
    local q=self.readable(Questie) and self.readable(Questie.db) and self.readable(Questie.db.profile) and Questie.db.profile
    -- The inactive Questie root no longer receives hover events. Apply its
    -- configured fill/border to our own surface, including hover fading.
    if q and self.db.trackerTab=="party" then
        local c=self.readable(q.trackerBackdropColor) and q.trackerBackdropColor
        if c and number(c.r) and number(c.g) and number(c.b) and number(c.a) then
            r,g,b=c.r,c.g,c.b
            local hovered=MouseIsOver and (MouseIsOver(f) or MouseIsOver(t.bar))
            local desired=q.trackerBackdropEnabled~=false and (q.trackerBackdropFader~=true or hovered) and c.a or 0
            local now=GetTime();local elapsed=t.fadeAt and math.max(0,now-t.fadeAt) or 1;t.fadeAt=now
            local previous=t.fadeAlpha or desired
            a=previous+math.max(-elapsed*3.3,math.min(elapsed*3.3,desired-previous));t.fadeAlpha=a
            br,bc,bb,ba=1,1,1,q.trackerBorderEnabled==true and a or 0
        end
    else t.fadeAt=nil;t.fadeAlpha=nil end
    bg.questieTabsArt:SetBackdropColor(r,g,b,a)
    bg.questieTabsArt:SetBackdropBorderColor(br,bc,bb,ba)
    bg.questieTabsArt:Show();bg:SetAlpha(alpha);f:SetAlpha(alpha)
end
function A:RestoreQuestieTabsAppearance()
    local f=self.sidebar
    if not f then return end
    local bg=f.trackerBackground
    if bg.questieTabsArt then bg.questieTabsArt:Hide() end
    bg.art:Show();bg:SetAlpha(1);f:SetAlpha(1)
    f.trackerBackgroundAlpha=nil;f.backgroundJoinSignature=nil
end
