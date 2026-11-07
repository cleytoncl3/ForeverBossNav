-- Forever Boss Nav
-- Mostra a lista de bosses (na ordem do cliente) da dungeon/raid em que voce esta,
-- marca os mortos, destaca o proximo e aponta uma seta para o boss vivo mais proximo
-- QUANDO o cliente fornece a posicao do jogador.
--
-- IMPORTANTE: desde o patch 7.1 a Blizzard bloqueia UnitPosition() e GetPlayerFacing()
-- dentro de instancias, e o cliente Classic/Forever herdou esse bloqueio. Por isso a
-- seta direcional so funciona se o cliente devolver posicao; caso contrario o addon cai
-- para o modo "proximo boss na ordem", que funciona sempre.

local ADDON, ns = ...

local DB                     -- ForeverBossNavDB (SavedVariables)
local current                -- instancia atual (tabela de ns.Instances) ou nil
local preview                -- instancia aberta via /fbn show fora da dungeon
local bossList = {}          -- lista montada para a instancia exibida
local rows = {}

local MAX_ROWS = 26
local ROW_H = 15
local WIDTH = 270

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffForever Boss Nav:|r " .. tostring(msg))
end

local function norm(s)
    if not s then return "" end
    return (s:lower():gsub("[%s%p]", ""))
end

local function NpcIDFromGUID(guid)
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

---------------------------------------------------------------------------
-- Banco de dados
---------------------------------------------------------------------------
local function InitDB()
    ForeverBossNavDB = ForeverBossNavDB or {}
    DB = ForeverBossNavDB
    DB.coords = DB.coords or {}        -- [instanceID][bossName] = { n, w }   (coordenadas de mundo)
    DB.learned = DB.learned or {}      -- [instanceID] = { "Nome", ... }      (bosses vistos via ENCOUNTER_START)
    DB.encounters = DB.encounters or {} -- [encounterID] = bossName
    DB.localNames = DB.localNames or {} -- [npcID] = nome localizado visto no jogo
    DB.run = DB.run or { killed = {} }
    if DB.shown == nil then DB.shown = true end
end

local byID, byName = {}, {}
local function IndexInstances()
    for _, inst in ipairs(ns.Instances) do
        if inst.instanceID then byID[inst.instanceID] = inst end
        byName[norm(inst.name)] = inst
    end
end

local function FindInstance()
    local name, itype, _, _, _, _, _, iid = GetInstanceInfo()
    if itype ~= "party" and itype ~= "raid" then return nil end
    local inst = byID[iid] or byName[norm(name)]
    if not inst then
        -- instancia nova que ainda nao esta na base: cria uma entrada dinamica
        inst = { key = "dyn-" .. tostring(iid), name = name or "?", instanceID = iid,
                 kind = itype, bosses = {}, dynamic = true }
        byID[iid] = inst
    elseif not inst.instanceID and iid then
        inst.instanceID = iid
        byID[iid] = inst
    end
    return inst
end

local function BuildBossList(inst)
    wipe(bossList)
    if not inst then return end
    local seen = {}
    for i, b in ipairs(inst.bosses) do
        bossList[#bossList + 1] = { name = b.name, npc = b.npc, wing = b.wing, new = b.new, order = i }
        seen[norm(b.name)] = true
    end
    local learned = inst.instanceID and DB.learned[inst.instanceID]
    if learned then
        for _, n in ipairs(learned) do
            if not seen[norm(n)] then
                bossList[#bossList + 1] = { name = n, learned = true, order = #bossList + 1 }
                seen[norm(n)] = true
            end
        end
    end
end

local function DisplayName(b)
    if b.npc and DB.localNames[b.npc] and norm(DB.localNames[b.npc]) ~= norm(b.name) then
        return DB.localNames[b.npc] .. " |cff888888(" .. b.name .. ")|r"
    end
    return b.name
end

local function IsKilled(b)
    return current ~= nil and DB.run.killed[b.name] == true
end

local function NextBoss()
    for _, b in ipairs(bossList) do
        if not IsKilled(b) then return b end
    end
end

local function FindBoss(name, npcID)
    if npcID then
        for _, b in ipairs(bossList) do
            if b.npc == npcID then return b end
        end
    end
    if name then
        local n = norm(name)
        for _, b in ipairs(bossList) do
            if norm(b.name) == n then return b end
            if b.npc and DB.localNames[b.npc] and norm(DB.localNames[b.npc]) == n then return b end
        end
    end
end

---------------------------------------------------------------------------
-- Posicao (so funciona se o cliente nao bloquear dentro da instancia)
---------------------------------------------------------------------------
local function PlayerPos()
    local n, w, _, iid = UnitPosition("player")
    if not n or not w then return nil end
    return n, w, iid
end

local function SaveCoord(b)
    if not (current and current.instanceID and b) then return false end
    local n, w = PlayerPos()
    if not n then return false end
    DB.coords[current.instanceID] = DB.coords[current.instanceID] or {}
    DB.coords[current.instanceID][b.name] = { n, w }
    return true
end

local function CoordOf(b)
    local inst = current
    if not (inst and inst.instanceID) then return nil end
    local t = DB.coords[inst.instanceID]
    local c = t and t[b.name]
    if c then return c[1], c[2] end
    local stock = ns.Coords and ns.Coords[inst.instanceID] and ns.Coords[inst.instanceID][b.name]
    if stock then return stock[1], stock[2] end
end

local function NearestAlive()
    local pn, pw = PlayerPos()
    if not pn then return nil end
    local best, bestD, bdn, bdw
    for _, b in ipairs(bossList) do
        if not IsKilled(b) then
            local n, w = CoordOf(b)
            if n then
                local dn, dw = n - pn, w - pw
                local d = math.sqrt(dn * dn + dw * dw)
                if not bestD or d < bestD then best, bestD, bdn, bdw = b, d, dn, dw end
            end
        end
    end
    return best, bestD, bdn, bdw
end

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "ForeverBossNavFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(WIDTH, 80)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetScript("OnDragStart", function(self) if not DB.locked then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB.point = { p, rp, x, y }
end)
if frame.SetBackdrop then
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.75)
    frame:SetBackdropBorderColor(0.4, 0.6, 0.9, 1)
end
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 10, -9)
title:SetPoint("TOPRIGHT", -24, -9)
title:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetSize(22, 22)
close:SetPoint("TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() DB.shown = false; frame:Hide() end)

local arrow = frame:CreateTexture(nil, "OVERLAY")
arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
arrow:SetSize(38, 38)
arrow:SetPoint("TOPLEFT", 8, -24)

local navText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
navText:SetPoint("TOPLEFT", 50, -28)
navText:SetPoint("TOPRIGHT", -10, -28)
navText:SetJustifyH("LEFT")

local navSub = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
navSub:SetPoint("TOPLEFT", navText, "BOTTOMLEFT", 0, -2)
navSub:SetPoint("TOPRIGHT", navText, "BOTTOMRIGHT", 0, -2)
navSub:SetJustifyH("LEFT")

local LIST_TOP = -66

local function RowTooltip(self)
    local b = self.boss
    if not b then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(DisplayName(b), 1, 1, 1)
    if b.wing then GameTooltip:AddLine("Ala: " .. b.wing, 0.7, 0.7, 1) end
    if b.learned then GameTooltip:AddLine("Aprendido em jogo (ENCOUNTER_START)", 0.6, 0.6, 0.6) end
    if b.new then GameTooltip:AddLine("Boss novo do WoW Forever", 1, 0.82, 0) end
    local n = CoordOf(b)
    GameTooltip:AddLine(n and "Posicao conhecida" or "Sem posicao registrada", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Clique: marcar/desmarcar como morto", 0.5, 1, 0.5)
    GameTooltip:AddLine("Shift+clique: gravar sua posicao como local deste boss", 0.5, 1, 0.5)
    GameTooltip:Show()
end

for i = 1, MAX_ROWS do
    local r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 8, LIST_TOP - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", -8, LIST_TOP - (i - 1) * ROW_H)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetAllPoints()
    r.text:SetJustifyH("LEFT")
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(0.2, 0.5, 1, 0.25)
    r.hl:Hide()
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnClick", function(self)
        local b = self.boss
        if not b or not current then return end
        if IsShiftKeyDown() then
            if SaveCoord(b) then
                Print("Posicao de " .. b.name .. " gravada.")
            else
                Print("O cliente nao fornece sua posicao dentro desta instancia (bloqueio da Blizzard).")
            end
        else
            DB.run.killed[b.name] = not DB.run.killed[b.name] or nil
        end
        ns.Refresh()
    end)
    r:SetScript("OnEnter", RowTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    rows[i] = r
end

local function UpdateNav()
    local shown = current or preview
    if not shown then return end
    local nxt = NextBoss()
    if preview and not current then
        arrow:Hide()
        navText:SetText("Visualizacao")
        navSub:SetText((preview.minLevel and ("Nivel " .. preview.minLevel .. "  ") or "") .. #bossList .. " bosses")
        return
    end
    if not nxt then
        arrow:Hide()
        navText:SetText("|cff00ff00Todos os bosses mortos!|r")
        navSub:SetText("/fbn reset para reiniciar a contagem")
        return
    end
    local b, d, dn, dw = NearestAlive()
    local facing = GetPlayerFacing()
    if b and facing then
        local bearing = math.atan2(dw, dn)   -- 0 = norte, anti-horario (mesma convencao do GetPlayerFacing)
        arrow:SetRotation(bearing - facing)
        arrow:SetVertexColor(1, 1, 1)
        arrow:Show()
        navText:SetText(DisplayName(b))
        navSub:SetText(string.format("%d m  |  proximo na ordem: %d. %s", math.floor(d + 0.5), nxt.order, nxt.name))
    else
        arrow:SetRotation(0)
        arrow:SetVertexColor(1, 0.82, 0)
        arrow:Show()
        navText:SetText(nxt.order .. ". " .. DisplayName(nxt))
        if PlayerPos() then
            navSub:SetText("Proximo na ordem (sem posicao gravada; shift+clique no boss para gravar)")
        else
            navSub:SetText("Proximo na ordem - a Blizzard bloqueia sua posicao em instancias")
        end
    end
end

function ns.Refresh()
    local shown = current or preview
    if not shown then frame:Hide(); return end
    BuildBossList(shown)
    local kills = 0
    for _, b in ipairs(bossList) do if IsKilled(b) then kills = kills + 1 end end
    local label = shown.name
    if shown.announced then label = label .. " |cffaaaaaa(anunciada)|r" end
    title:SetText(label .. string.format("  |cffaaaaaa%d/%d|r", kills, #bossList))

    local nxt = current and NextBoss()
    local lastWing
    local i = 0
    for _, b in ipairs(bossList) do
        if i >= MAX_ROWS then break end
        if b.wing and b.wing ~= lastWing then
            i = i + 1
            local r = rows[i]
            if not r then break end
            r.boss = nil
            r.text:SetText("|cff7fb2ff-- " .. b.wing .. " --|r")
            r.hl:Hide()
            r:Show()
            lastWing = b.wing
            if i >= MAX_ROWS then break end
        end
        i = i + 1
        local r = rows[i]
        r.boss = b
        local mark, color
        if IsKilled(b) then
            mark, color = "|cff00ff00x|r", "|cff777777"
        elseif b == nxt then
            mark, color = "|cffffd100>|r", "|cffffd100"
        else
            mark, color = " ", "|cffffffff"
        end
        local extra = ""
        if b.new then extra = extra .. " |cffffd100*|r" end
        if b.learned then extra = extra .. " |cff888888(aprendido)|r" end
        if CoordOf(b) then extra = extra .. " |cff33ccff@|r" end
        r.text:SetText(string.format("%s %2d. %s%s|r%s", mark, b.order, color, DisplayName(b), extra))
        if b == nxt then r.hl:Show() else r.hl:Hide() end
        r:Show()
    end
    for j = i + 1, MAX_ROWS do rows[j]:Hide(); rows[j].boss = nil end
    if #bossList == 0 then
        i = 1
        rows[1].boss = nil
        rows[1].text:SetText("|cffaaaaaaBosses ainda desconhecidos - serao aprendidos ao puxar cada um.|r")
        rows[1].hl:Hide()
        rows[1]:Show()
    end
    frame:SetHeight(-LIST_TOP + i * ROW_H + 10)
    UpdateNav()
    if DB.shown then frame:Show() end
end

local elapsedAcc = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedAcc = elapsedAcc + elapsed
    if elapsedAcc < 0.1 then return end
    elapsedAcc = 0
    if current then UpdateNav() end
end)

---------------------------------------------------------------------------
-- Deteccao de kills
---------------------------------------------------------------------------
local function MarkKilled(b, how)
    if not b or IsKilled(b) then return end
    DB.run.killed[b.name] = true
    Print("|cff00ff00" .. b.name .. " morto|r" .. (how and (" (" .. how .. ")") or ""))
    ns.Refresh()
end

local function ScanUnitsForBoss()
    local units = { "boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus", "mouseover" }
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    for _, u in ipairs(units) do
        if UnitExists(u) then
            local id = NpcIDFromGUID(UnitGUID(u))
            local b = FindBoss(nil, id)
            if b then
                DB.localNames[id] = UnitName(u)
                return b
            end
        end
    end
end

local function Learn(name)
    if not (current and current.instanceID and name) then return end
    if FindBoss(name) then return end
    DB.learned[current.instanceID] = DB.learned[current.instanceID] or {}
    table.insert(DB.learned[current.instanceID], name)
    Print("Novo boss aprendido: " .. name)
    BuildBossList(current)
end

local function OnEncounterStart(encounterID, encounterName)
    if not current then return end
    local b = (DB.encounters[encounterID] and FindBoss(DB.encounters[encounterID])) or FindBoss(encounterName) or ScanUnitsForBoss()
    if not b then
        Learn(encounterName)
        b = FindBoss(encounterName)
    end
    if b then
        DB.encounters[encounterID] = b.name
        SaveCoord(b) -- grava a posicao do pull, se o cliente permitir
    end
    ns.Refresh()
end

local function OnEncounterEnd(encounterID, encounterName, _, _, success)
    if not current or success ~= 1 then return end
    local b = (DB.encounters[encounterID] and FindBoss(DB.encounters[encounterID])) or FindBoss(encounterName)
    MarkKilled(b, "encontro")
end

local function OnCombatLog()
    local _, sub, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    if sub ~= "UNIT_DIED" then return end
    local id = NpcIDFromGUID(destGUID)
    if not id then return end
    local b = FindBoss(nil, id) or FindBoss(destName)
    if b then
        if b.npc and destName then DB.localNames[b.npc] = destName end
        MarkKilled(b)
    end
end

-- guarda o nome localizado quando voce mira um boss conhecido (clientes pt-BR etc.)
local function OnTarget()
    if not current or not UnitExists("target") then return end
    local id = NpcIDFromGUID(UnitGUID("target"))
    if id and FindBoss(nil, id) and DB.localNames[id] ~= UnitName("target") then
        DB.localNames[id] = UnitName("target")
        ns.Refresh()
    end
end

local function OnZone()
    local inst = FindInstance()
    if inst then
        if DB.run.instanceID ~= inst.instanceID then
            DB.run = { instanceID = inst.instanceID, killed = {}, started = time() }
        end
        current, preview = inst, nil
    else
        current = nil
    end
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        InitDB()
        IndexInstances()
        if DB.point then
            frame:ClearAllPoints()
            frame:SetPoint(DB.point[1], UIParent, DB.point[2], DB.point[3], DB.point[4])
        end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START",
                             "ENCOUNTER_END", "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_TARGET_CHANGED", "BOSS_KILL" }) do
            pcall(self.RegisterEvent, self, e)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        OnZone()
    elseif event == "ENCOUNTER_START" then
        OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd(...)
    elseif event == "BOSS_KILL" then
        local id, name = ...
        if current then
            MarkKilled((DB.encounters[id] and FindBoss(DB.encounters[id])) or FindBoss(name), "encontro")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if current then OnCombatLog() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnTarget()
    end
end)

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
local function SortedInstances()
    local t = {}
    for _, inst in ipairs(ns.Instances) do t[#t + 1] = inst end
    table.sort(t, function(a, b)
        if a.kind ~= b.kind then return a.kind == "party" end
        local la = tonumber((a.minLevel or ""):match("%d+")) or 99
        local lb = tonumber((b.minLevel or ""):match("%d+")) or 99
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return t
end

local function Help()
    Print("comandos:")
    Print("  /fbn - mostra/esconde a janela")
    Print("  /fbn list - lista todas as dungeons e raids")
    Print("  /fbn show <nome> - ve os bosses de uma instancia fora dela")
    Print("  /fbn reset - zera os kills da instancia atual")
    Print("  /fbn mark - grava sua posicao como local do proximo boss (ou do alvo)")
    Print("  /fbn lock - trava/destrava a janela")
end

SLASH_FOREVERBOSSNAV1 = "/fbn"
SLASH_FOREVERBOSSNAV2 = "/bossnav"
SlashCmdList.FOREVERBOSSNAV = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        DB.shown = not frame:IsShown()
        if DB.shown then
            if not current and not preview then Print("Voce nao esta em uma dungeon. Use /fbn show <nome>.") end
            ns.Refresh()
        else
            frame:Hide()
        end
    elseif cmd == "list" then
        for _, inst in ipairs(SortedInstances()) do
            Print(string.format("%s%s - %s, %d bosses%s", inst.kind == "raid" and "[Raid] " or "",
                inst.name, inst.minLevel and ("nivel " .. inst.minLevel) or "nivel ?",
                #inst.bosses, inst.announced and " (anunciada)" or ""))
        end
    elseif cmd == "show" then
        local q = norm(rest)
        if q == "" then Help(); return end
        for _, inst in ipairs(SortedInstances()) do
            if norm(inst.name):find(q, 1, true) or inst.key:find(rest:lower(), 1, true) then
                preview = inst
                if not current then
                    DB.shown = true
                    ns.Refresh()
                else
                    Print("Voce esta dentro de " .. current.name .. "; saia para visualizar outra instancia.")
                end
                return
            end
        end
        Print("Nenhuma instancia encontrada para '" .. rest .. "'.")
    elseif cmd == "reset" then
        DB.run.killed = {}
        Print("Kills zerados.")
        ns.Refresh()
    elseif cmd == "mark" then
        if not current then Print("Entre em uma dungeon primeiro."); return end
        local b
        if UnitExists("target") then
            b = FindBoss(UnitName("target"), NpcIDFromGUID(UnitGUID("target")))
        end
        b = b or NextBoss()
        if b and SaveCoord(b) then
            Print("Posicao de " .. b.name .. " gravada.")
            ns.Refresh()
        else
            Print("O cliente nao fornece sua posicao dentro desta instancia (bloqueio da Blizzard).")
        end
    elseif cmd == "lock" then
        DB.locked = not DB.locked
        Print(DB.locked and "Janela travada." or "Janela destravada.")
    else
        Help()
    end
end
