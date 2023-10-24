local _, ADDON_NS = ...

local GetInstanceInfo, GetNumGroupMembers = GetInstanceInfo, GetNumGroupMembers
local ADDON = CreateFrame("Frame", "BloodQueenBites", UIParent)
ADDON_NS.ADDON = ADDON

ADDON:SetScript("OnEvent", function(self, event, ...)
  return self[event](self, event, ...)
end)

ADDON:RegisterEvent("PLAYER_LOGIN")

-- Gets the number of people that can fit in this raid or the max raid size, whichever is smaller
-- Ex: 28 people are in raid for a 25man raid. Returns=25
-- Ex: 23 people are in raid for a 25man raid. Returns=23
function ADDON_NS.GetMaxRaidMembers()
  local _, _, _, _, maxPlayers = GetInstanceInfo()
  local numPlayers = GetNumGroupMembers()

  local max = numPlayers

  if maxPlayers ~= 0 then
    max = (numPlayers > maxPlayers) and maxPlayers or numPlayers
  end

  return max
end

local function SetupSlashHandler()
  -- Configure slash handler
  SlashCmdList.BloodQueenBites = function()
    ADDON_NS.CreateUI()
  end
  SLASH_BloodQueenBites1 = "/bloodqueenbites"
  SLASH_BloodQueenBites2 = "/bqb"
end

function ADDON.PLAYER_LOGIN()
  if not ADDON.initialized then
    ADDON.initialized = true

    ADDON:RegisterEvent("UNIT_AURA")

    BloodQueenBitesDB = BloodQueenBitesDB or {}
    BloodQueenBitesDB.melee_prio = BloodQueenBitesDB.melee_prio or {}
    BloodQueenBitesDB.ranged_prio = BloodQueenBitesDB.ranged_prio or {}
    BloodQueenBitesDB.tank_prio = BloodQueenBitesDB.tank_prio or {}
    BloodQueenBitesDB.healer_prio = BloodQueenBitesDB.healer_prio or {}
    SetupSlashHandler()

    C_ChatInfo.RegisterAddonMessagePrefix("BLOODQUEENBITES")
    ADDON.lastUpdateMarkTime = GetTime()
  end
end

-- Sends a whisper to the biter to give their new assignment
local function SendNewAssignmentMessages(new_assignments, players_marked)
  for biter, target in pairs(new_assignments) do
    local target_index = players_marked[target]
    SendChatMessage(">>> Next bite target: {rt" .. target_index .. "} " .. target .. " {rt" .. target_index .. "}",
      "WHISPER", nil, biter)
  end
end

-- Sends an addon message in the format: "BiterA,TargetA,8^BiterB,TargetB,7"
-- Each bite assignment is: "{Biter},{Target},{target mark index}"
-- and each assignment is separated by a caret "^"
local function SendAddonMessages(bite_assignments, players_marked)
  local message = ""
  for biter, target in pairs(bite_assignments) do
    if message == "" then
      message = biter .. "," .. target .. "," .. players_marked[target]
    else
      message = message .. "^" .. biter .. "," .. target .. "," .. players_marked[target]
    end
  end

  if message == "" then message = "^^^" end
  C_ChatInfo.SendAddonMessage("BLOODQUEENBITES", message, "RAID")
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

    local bite_assignments, new_assignments = ADDON_NS.GetBiteAssignments()
    local players_marked = ADDON_NS.UpdateMarks(bite_assignments)
    SendNewAssignmentMessages(new_assignments, players_marked)
    SendAddonMessages(bite_assignments, players_marked)
  end
end
