local _, ADDON_NS = ...

local AceGUI = LibStub("AceGUI-3.0")

-- Making these local for performance
local GetMaxRaidMembers = ADDON_NS.GetMaxRaidMembers
local BloodQueenBitesDB = BloodQueenBitesDB
local strsplittable = strsplittable

local function GetAllRaidMembersByRole()

  local melee, ranged, tanks, healers = "", "", "", ""

  for i = 1, GetMaxRaidMembers() do

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

local function ClickSave()
  BloodQueenBitesDB.melee_prio = strsplittable("\n", ADDON.config_frame.melee_box:GetText())
  BloodQueenBitesDB.ranged_prio = strsplittable("\n", ADDON.config_frame.ranged_box:GetText())

  local _, _, tanks, heals = GetAllRaidMembersByRole()
  BloodQueenBitesDB.tank_prio = strsplittable("\n", tanks)
  BloodQueenBitesDB.healer_prio = strsplittable("\n", heals)

  BloodQueenBitesDB.role_lookup = {}
  for k, v in ipairs(BloodQueenBitesDB.melee_prio) do
    BloodQueenBitesDB.role_lookup[v] = "MELEE"
  end
  for k, v in ipairs(BloodQueenBitesDB.ranged_prio) do
    BloodQueenBitesDB.role_lookup[v] = "RANGED"
  end
  for k, v in ipairs(BloodQueenBitesDB.tank_prio) do
    BloodQueenBitesDB.role_lookup[v] = "TANK"
  end
  for k, v in ipairs(BloodQueenBitesDB.healer_prio) do
    BloodQueenBitesDB.role_lookup[v] = "HEALER"
  end
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
  local result
  for i, v in ipairs(t) do
    if i == 1 then
      result = v
    else
      result = result .. "\n" .. v
    end
  end
  return result
end

local function ADDON_NS.CreateUI()
  local frame = AceGUI:Create("Frame")
  ADDON.config_frame = frame

  -- General frame setup
  frame:SetTitle("Blood Queen Bites")
  frame:SetStatusText("Remember to click Save!")
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
