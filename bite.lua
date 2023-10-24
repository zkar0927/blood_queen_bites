local _, ADDON_NS = ...

-- Making these local for performance
local GetMaxRaidMembers = ADDON_NS.GetMaxRaidMembers
local UnitIsDeadOrGhost, UnitExists, UnitName, FindAuraByName = UnitIsDeadOrGhost, UnitExists, UnitName, AuraUtil.FindAuraByName

local function GetBittenPlayers()
  local bitten_units = {}

  for i = 1, GetMaxRaidMembers() do
    local cur_unit = "raid" .. i

    if UnitExists(cur_unit) then
      local debuff_name = "Essence of the Blood Queen"
      local need_to_bite_name = "Frenzied Bloodthirst"

      local is_bitten = FindAuraByName(debuff_name, cur_unit, "HARMFUL")
      local is_trying_to_bite = FindAuraByName(need_to_bite_name, cur_unit, "HARMFUL")

      if is_bitten ~= nil or is_trying_to_bite ~= nil then
        bitten_units[UnitName(cur_unit)] = true
      end
    end
  end

  return bitten_units
end

-- Takes the existing bite assignments and updates them
-- Verifies no one has died or been bitten incorrectly
local function UpdateExistingBiteAssignments(bite_assignments, bitten_players)
  local new_assignments = {}

  for biter, target in pairs(bite_assignments) do
    -- Verify the biter still has the debuff, both targets are alive, and the target hasn't been bitten already
    if bitten_players[biter] and not (UnitIsDeadOrGhost(biter) or UnitIsDeadOrGhost(target) or bitten_players[target]) then
      -- Keep the previous assignment to allow consistency
      new_assignments[biter] = target
    end
  end

  return new_assignments
end

local function GetAllKeysValues(input)
  local all_vals = {}
  for k, v in pairs(input) do
    all_vals[k] = true
    all_vals[v] = true
  end
  return all_vals
end

local function HashTableCount(input)
  local i = 0
  for _, _ in pairs(input) do
    i = i + 1
  end
  return i
end

-- Gets the list of bite targets in priority order
-- Will try to keep melee biting melee, ranged biting ranged
-- The only exception is the first bite, where it will try to spread one bite into each ranged and melee
local function GetBitePriorityList(name, only_one_bite)
  local assigned_role = BloodQueenBitesDB.role_lookup[name]
  if assigned_role == "MELEE" or assigned_role == "TANK" then
    if only_one_bite then
      -- If only one person total is bitten try to get a bite in ranged next
      return { BloodQueenBitesDB.ranged_prio, BloodQueenBitesDB.melee_prio, BloodQueenBitesDB.tank_prio,
        BloodQueenBitesDB.healer_prio }
    else
      -- Otherwise melee bites melee when possible
      return { BloodQueenBitesDB.melee_prio, BloodQueenBitesDB.ranged_prio, BloodQueenBitesDB.tank_prio,
        BloodQueenBitesDB.healer_prio }
    end
  else
    if only_one_bite then
      -- If only one person total is bitten try to get a bite in melee next
      return { BloodQueenBitesDB.melee_prio, BloodQueenBitesDB.ranged_prio, BloodQueenBitesDB.tank_prio,
        BloodQueenBitesDB.healer_prio }
    else
      -- Otherwise ranged bites ranged when possible
      return { BloodQueenBitesDB.ranged_prio, BloodQueenBitesDB.melee_prio, BloodQueenBitesDB.tank_prio,
        BloodQueenBitesDB.healer_prio }
    end
  end
end

local function GetNextBiteTarget(name, bite_assignments, bitten_players)
  -- These players are either bitten or assigned to be bitten soon
  local accounted_for = GetAllKeysValues(bite_assignments)

  local priority = GetBitePriorityList(name, HashTableCount(bitten_players) == 1)

  -- Loop through in priority order and find the first name that isn't accounted for
  for _, prio_table in pairs(priority) do
    for _, name in pairs(prio_table) do
      if not accounted_for[name] and not bitten_players[name] and UnitExists(name) and not UnitIsDeadOrGhost(name) then
        return name
      end
    end
  end

end

-- Key: Player name
-- Val: Bite target player name
local bite_assignments = {}

function ADDON_NS.GetBiteAssignments()
  local new_assignments = {}
  local bitten_players = GetBittenPlayers()
  bite_assignments = UpdateExistingBiteAssignments(bite_assignments, bitten_players)

  for unit_name, v in pairs(bitten_players) do

    if bite_assignments[unit_name] then
      -- already assigned someone
      print("Already assigned: " .. unit_name .. " -> " .. bite_assignments[unit_name])
    else
      -- not assigned anyone yet
      local next_target = GetNextBiteTarget(unit_name, bite_assignments, bitten_players)
      if next_target == nil then
        print("Out of targets to bite")
      else
        bite_assignments[unit_name] = next_target
        new_assignments[unit_name] = next_target
        print("New Assignment: " .. unit_name .. " -> " .. next_target)
      end
    end
  end

  return bite_assignments, new_assignments
end
