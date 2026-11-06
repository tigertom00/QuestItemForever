-- QuestItemForever: adds "which quest is this item for" lines to item tooltips.
-- Data comes from LibQuestieDB (the QuestieDB addon), so it works for quests not in your log.

local ADDON_NAME = ...

local HEADER_COLOR = "|cffffd100"
local DONE_TAG = " |cff20ff20(done)|r"
local LOG_TAG = " |cff66bbff(in log)|r"

-- itemId -> list of { questId, role }
local index
local playerRaceMask

local function IsQuestForPlayer(questId)
    local races = LibQuestieDB.Quest.Get(questId, "requiredRaces")
    if races and races ~= 0 and bit.band(races, playerRaceMask) == 0 then
        return false
    end
    return true
end

local function Add(itemId, questId, role)
    if not itemId or itemId == 0 then return end
    local list = index[itemId]
    if not list then
        list = {}
        index[itemId] = list
    end
    for _, entry in ipairs(list) do
        if entry.questId == questId then return end -- objective wins over other roles
    end
    list[#list + 1] = { questId = questId, role = role }
end

-- Walk every quest once, spread over several frames so login doesn't hitch.
local function BuildIndex()
    index = {}
    local ids = LibQuestieDB.Quest.GetAllIds()
    local Get = LibQuestieDB.Quest.Get
    local pos, total, chunk = 1, #ids, 500

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(self)
        local last = math.min(pos + chunk - 1, total)
        for i = pos, last do
            local questId = ids[i]
            if IsQuestForPlayer(questId) then
                local objectives = Get(questId, "objectives")
                local itemObjectives = objectives and objectives[3]
                if itemObjectives then
                    for _, objective in ipairs(itemObjectives) do
                        Add(objective[1], questId, "objective")
                    end
                end
                local required = Get(questId, "requiredSourceItems")
                if required then
                    for _, itemId in ipairs(required) do
                        Add(itemId, questId, "needed")
                    end
                end
                Add(Get(questId, "sourceItemId"), questId, "provided")
            end
        end
        pos = last + 1
        if pos > total then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function IsCompleted(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId)
    end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questId)
end

local function IsInLog(questId)
    if C_QuestLog and C_QuestLog.IsOnQuest then
        return C_QuestLog.IsOnQuest(questId)
    end
    return GetQuestLogIndexByID and (GetQuestLogIndexByID(questId) or 0) > 0
end

local function QuestLine(questId, prefix)
    local name = LibQuestieDB.Quest.Get(questId, "name") or ("Quest #" .. questId)
    local level = LibQuestieDB.Quest.Get(questId, "questLevel")
    if not level or level <= 0 then
        level = UnitLevel("player")
    end
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level) or NORMAL_FONT_COLOR
    local text = string.format("%s|cff%02x%02x%02x[%d] %s|r", prefix, math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), level, name)
    if IsInLog(questId) then
        text = text .. LOG_TAG
    elseif IsCompleted(questId) then
        text = text .. DONE_TAG
    end
    return text
end

local ROLE_PREFIX = {
    objective = "",
    needed = "Needed for: ",
    provided = "Provided by: ",
}

local function AddLines(tooltip, itemId)
    local lines = {}

    local startQuest = LibQuestieDB.Item.Get(itemId, "startQuest")
    if startQuest and startQuest ~= 0 then
        lines[#lines + 1] = QuestLine(startQuest, "Starts: ")
    end
    if index then
        for _, entry in ipairs(index[itemId] or {}) do
            lines[#lines + 1] = QuestLine(entry.questId, ROLE_PREFIX[entry.role])
        end
    end

    if #lines == 0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(HEADER_COLOR .. "Quest Item|r")
    for _, line in ipairs(lines) do
        tooltip:AddLine(line, 1, 1, 1, true)
    end
    tooltip:Show()
end

local function OnTooltipSetItem(tooltip, data)
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    -- Tooltip-data clients pass the item ID; comparison tooltips there have no GetItem.
    local itemId = type(data) == "table" and data.id
    if not itemId and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        itemId = link and tonumber(link:match("item:(%d+)"))
    end
    if itemId then
        AddLines(tooltip, itemId)
    end
end

local function HookTooltips()
    local usesTooltipData = type(GameTooltip.GetPrimaryTooltipData) == "function"
        and TooltipDataProcessor and Enum and Enum.TooltipDataType
    if usesTooltipData then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
    else
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
            if tooltip and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
            end
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not LibQuestieDB then
        print("|cffff5555" .. ADDON_NAME .. ":|r QuestieDB not found, addon disabled.")
        return
    end
    playerRaceMask = bit.lshift(1, select(3, UnitRace("player")) - 1)
    HookTooltips()
    -- Give Questie a moment to apply its corrections before reading quest data.
    C_Timer.After(3, BuildIndex)
end)
