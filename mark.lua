local _, ADDON_NS = ...

-- Making these local for performance
local GetMaxRaidMembers = ADDON_NS.GetMaxRaidMembers
local GetRaidTargetIndex, UnitName, tremove, SetRaidTarget = GetRaidTargetIndex, UnitName, tremove, SetRaidTarget

local function GetPlayersToMark(assignments)

  local players_to_mark = {}

  for biter, target in pairs(assignments) do
    players_to_mark[target] = 0
  end

  return players_to_mark
end

local function GetMarkedPlayers()
  -- local marks = { [1] = "", [2] = "", [3] = "", [4] = "", [5] = "", [6] = "", [7] = "", [8] = "" }
  local marks = { "", "", "", "", "", "", "", "" }

  for i = 1, GetMaxRaidMembers() do
    local unit = "raid" .. i
    local index = GetRaidTargetIndex(unit)
    if index ~= nil then
      marks[index] = UnitName(unit)
    end
  end

  return marks
end

-- Accepts a table, and tries to mark the values in the table
-- Keeps any existing marks when possible, and assigns new marks where needed
-- Also clears anyone marked who is not in this table
local function ADDON_NS.UpdateMarks(assignments)

  local playersToMark = GetPlayersToMark(assignments)

  local availableMarks = {}

  -- Go through all marked players and find any which should no longer be marked
  local markedPlayers = GetMarkedPlayers()
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

      playersToMark[playerName] = data[1]
      SetRaidTarget(playerName, data[1])
    end
  end

  -- These marks are no longer needed and should be cleared
  for _, data in pairs(availableMarks) do
    if data[2] ~= "" then
      SetRaidTarget(data[2], 0)
    end
  end

  return playersToMark
end

