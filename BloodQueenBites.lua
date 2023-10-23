local ADDON = CreateFrame("Frame", "BloodQueenBites", UIParent)

local AceGUI = LibStub("AceGUI-3.0")

ADDON:SetScript("OnEvent", function(self, event, ...)
  return self[event](self, event, ...)
end)

ADDON:RegisterEvent("PLAYER_LOGIN")

-- Gets the number of people that can fit in this raid or the max raid size, whichever is smaller
-- Ex: 28 people are in raid for a 25man raid. Returns=25
-- Ex: 23 people are in raid for a 25man raid. Returns=23
local function GetMaxRaidMembers()
  local _, _, _, _, maxPlayers = GetInstanceInfo()
  local numPlayers = GetNumGroupMembers()

  local max = numPlayers

  if maxPlayers ~= 0 then
    max = (numPlayers > maxPlayers) and maxPlayers or numPlayers
  end

  return max
end

local function GetAllRaidMembersByRole()

  local melee, ranged, tanks, healers = "", "", "", ""

  local max = GetMaxRaidMembers()

  for i = 1, max do

    local name, _, _, _, class, _, _, _, _, _, _, role = GetRaidRosterInfo(i)

    if role == "DAMAGER" then
      if class == "Warlock" or class == "Mage" or class == "Priest" or class == "Hunter" then
        ranged = ranged .. name .. "\n"
      else
        melee = melee .. name .. "\n"
      end
    elseif role == "HEALER" then
      healers = healers .. name .. "\n"
    elseif role == "TANK" then
      tanks = tanks .. name .. "\n"
    end

  end

  return melee, ranged, tanks, healers
end

-------------------------------------------------------------------------------
-- User Interface
-------------------------------------------------------------------------------
local function ClickSave()
  BloodQueenBitesDB.melee_prio = strsplittable("\n", ADDON.config_frame.melee_box:GetText())
  BloodQueenBitesDB.ranged_prio = strsplittable("\n", ADDON.config_frame.ranged_box:GetText())

  local _, _, tanks, heals = GetAllRaidMembersByRole()
  BloodQueenBitesDB.tank_prio = strsplittable("\n", tanks)
  BloodQueenBitesDB.healer_prio = strsplittable("\n", heals)
end

local function ClickDemoteAll()
  for i = 1, GetMaxRaidMembers() do
    local name, rank = GetRaidRosterInfo(i)
    if rank == 1 then
      DemoteAssistant(name)
    end
  end

end

local function TableToLineSeparatedString(t)
  local result = ""
  for _, v in ipairs(t) do
    result = result .. v .. "\n"
  end
  return result
end

local function CreateUI()
  local frame = AceGUI:Create("Frame")
  ADDON.config_frame = frame

  -- General frame setup
  frame:SetTitle("Blood Queen Bites")
  frame:SetStatusText("TODO")
  frame:SetLayout("Flow")
  frame:SetCallback(
    "OnClose",
    function(widget)
      AceGUI:Release(widget)
    end
  )

  -- Header label setup
  local label = AceGUI:Create("Label")
  label:SetFullWidth(true)
  label:SetText([[

Create a ranged and melee priority list below.
The first character listed will be the highest priority to receive a bite.

]] )
  frame:AddChild(label)

  -- Generate button
  local generate_button = AceGUI:Create("Button")
  generate_button:SetText("Generate Data")
  generate_button:SetWidth(200)
  frame:AddChild(generate_button)

  local save_button = AceGUI:Create("Button")
  save_button:SetText("Save")
  save_button:SetWidth(200)
  save_button:SetCallback("OnClick", ClickSave)
  frame:AddChild(save_button)

  local demote_button = AceGUI:Create("Button")
  demote_button:SetText("Demote All")
  demote_button:SetWidth(200)
  demote_button:SetCallback("OnClick", ClickDemoteAll)
  frame:AddChild(demote_button)

  local empty_label = AceGUI:Create("Label")
  empty_label:SetFullWidth(true)
  empty_label:SetText("")
  frame:AddChild(empty_label)

  -- Melee edit box
  local melee_box = AceGUI:Create("MultiLineEditBox")
  frame.melee_box = melee_box
  melee_box:SetLabel("Melee")
  melee_box:SetFullHeight(true)
  melee_box:DisableButton(true)
  melee_box:SetRelativeWidth(0.5)
  melee_box:SetText(TableToLineSeparatedString(BloodQueenBitesDB.melee_prio))
  frame:AddChild(melee_box)

  local ranged_box = AceGUI:Create("MultiLineEditBox")
  frame.ranged_box = ranged_box
  ranged_box:SetLabel("Ranged")
  ranged_box:SetFullHeight(true)
  ranged_box:DisableButton(true)
  ranged_box:SetRelativeWidth(0.5)
  ranged_box:SetText(TableToLineSeparatedString(BloodQueenBitesDB.ranged_prio))
  frame:AddChild(ranged_box)

  generate_button:SetCallback("OnClick", function()
    local melee, ranged, tanks, healers = GetAllRaidMembersByRole()

    melee_box:SetText(melee)
    ranged_box:SetText(ranged)
  end)
end

-------------------------------------------------------------------------------
-- Addon initialization
-------------------------------------------------------------------------------
local function SetupSlashHandler()
  -- Configure slash handler
  SlashCmdList.BloodQueenBites = function()
    CreateUI()
  end
  SLASH_BloodQueenBites1 = "/bloodqueenbites"
  SLASH_BloodQueenBites2 = "/bqb"
end

function ADDON.PLAYER_LOGIN()
  if not ADDON.initialized then
    ADDON.initialized = true

    ADDON:RegisterEvent("ENCOUNTER_START")
    ADDON:RegisterEvent("ENCOUNTER_END")
    ADDON:RegisterEvent("UNIT_AURA")

    BloodQueenBitesDB = BloodQueenBitesDB or {}
    BloodQueenBitesDB.melee_prio = BloodQueenBitesDB.melee_prio or {}
    BloodQueenBitesDB.ranged_prio = BloodQueenBitesDB.ranged_prio or {}
    BloodQueenBitesDB.tank_prio = BloodQueenBitesDB.tank_prio or {}
    BloodQueenBitesDB.healer_prio = BloodQueenBitesDB.healer_prio or {}

    SetupSlashHandler()

    ADDON.lastUpdateMarkTime = GetTime()
  end
end

function ADDON.ENCOUNTER_START(self, event, ecounterID, encounterName, difficultyID, groupSize)
  -- Hodir is encounter ID 853
  if encounterID == 853 then
    ADDON:RegisterEvent("UNIT_AURA")
    print("registered")
  end
end

function ADDON.ENCOUNTER_END(self, event, ecounterID, encounterName, difficultyID, groupSize)
  -- Blood queen is encounter ID 853
  if encounterID == 853 then
    ADDON:UnregisterEvent("UNIT_AURA")
    print("unregistered")
  end
end

-------------------------------------------------------------------------------
-- Target marking logic
-------------------------------------------------------------------------------
local function GetPlayersToMark()

  local playersToMark = {}

  -- TODO

  return playersToMark
end

local function GetMarkedPlayers()
  local marks = { [1] = "", [2] = "", [3] = "", [4] = "", [5] = "", [6] = "", [7] = "", [8] = "" }

  for i = 1, GetMaxRaidMembers() do
    local unit = "raid" .. i
    local index = GetRaidTargetIndex(unit)
    if index ~= nil then
      marks[index] = UnitName(unit)
    end
  end

  return marks
end

local function UpdateMarks()
  local markedPlayers = GetMarkedPlayers()

  local playersToMark = GetPlayersToMark()

  local availableMarks = {}

  -- Go through all marked players and find any which should no longer be marked
  for markIndex, playerName in pairs(markedPlayers) do
    if playersToMark[playerName] ~= nil then
      -- This is a person who has a mark, and should keep it
      playersToMark[playerName] = markIndex
    else
      -- This player no longer needs their mark
      tinsert(availableMarks, { markIndex, playerName })
    end
  end

  -- Get marks for any players who need them
  for playerName, markIndex in pairs(playersToMark) do
    -- Only mark players who don't have a mark
    if markIndex == 0 then
      local data = tremove(availableMarks)

      SetRaidTarget(playerName, data[1])
    end
  end

  -- These marks are no longer needed and should be cleared
  for _, data in pairs(availableMarks) do
    if data[2] ~= "" then
      SetRaidTarget(data[2], 0)
    end
  end

end

function ADDON.UNIT_AURA(self, event, unitTarget)

  -- Only look for auras applied to raid units
  if string.find(unitTarget, "raid") ~= nil then
    -- throttle to 1Hz
    local now = GetTime()
    if (now - 1) < ADDON.lastUpdateMarkTime then
      return
    end
    ADDON.lastUpdateMarkTime = now

    UpdateMarks()
  end
end
