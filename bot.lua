-- Initializing global variables
local CurrentGameState = CurrentGameState or {}
local ActionInProgress = ActionInProgress or false
local Logs = Logs or {}
local Me = nil

-- Define colors for console output
local colors = {
    red = "\27[31m", green = "\27[32m", blue = "\27[34m",
    yellow = "\27[33m", purple = "\27[35m", reset = "\27[0m"
}

-- Add log function
function addLog(msg, text)
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

-- Check if two points are within a range
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Find the opponent with the lowest health
function findWeakestOpponent()
    local weakestOpponent, lowestHealth = nil, math.huge
    for target, state in pairs(CurrentGameState.Players) do
        if target ~= ao.id and state.health < lowestHealth then
            weakestOpponent, lowestHealth = state, state.health
        end
    end
    return weakestOpponent
end

-- Attack the weakest opponent
function attackWeakestOpponent()
    local weakestOpponent = findWeakestOpponent()
    if weakestOpponent then
        local attackEnergy = Me.energy * 0.5
        print(colors.red .. "Attacking weakest opponent with energy: " .. attackEnergy .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackEnergy) })
        ActionInProgress = false
        return true
    end
    return false
end

-- Heal if health is low
function heal()
    if Me.health < 0.5 then
        print(colors.green .. "Health is low, healing..." .. colors.reset)
        ao.send({ Target = Game, Action = "Heal", Player = ao.id })
    end
end

-- Move to a random direction
function moveRandomly()
    local directions = {"North", "South", "East", "West"}
    local direction = directions[math.random(#directions)]
    print(colors.blue .. "Moving randomly in direction: " .. direction .. colors.reset)
    ao.send({ Target = Game, Action = "Move", Direction = direction })
end

-- Use shield if energy is high
function useShield()
    if Me.energy > 0.7 then
        print(colors.yellow .. "Energy is high, using shield..." .. colors.reset)
        ao.send({ Target = Game, Action = "UseShield", Player = ao.id })
    end
end

-- Evade if surrounded by opponents
function evade()
    local surroundingOpponents = 0
    for target, state in pairs(CurrentGameState.Players) do
        if target ~= ao.id and inRange(Me.x, Me.y, state.x, state.y, 2) then
            surroundingOpponents = surroundingOpponents + 1
        end
    end
    if surroundingOpponents > 2 then
        moveRandomly()
    end
end

-- Gather energy if health is high and energy is low
function gatherEnergy()
    if Me.health > 0.7 and Me.energy < 0.4 then
        print(colors.purple .. "Health is high but energy is low, gathering energy..." .. colors.reset)
        ao.send({ Target = Game, Action = "GatherEnergy", Player = ao.id })
    end
end

-- Decide next action based on state
function decideNextAction()
    if not attackWeakestOpponent() then
        evade()
    end
end

-- Handle game announcements and trigger updates
Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        ao.send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not ActionInProgress then
        ActionInProgress = true
        ao.send({ Target = Game, Action = "GetGameState" })
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end)

-- Trigger game state updates
Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not ActionInProgress then
        ActionInProgress = true
        print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    end
end)

-- Update game state on receiving information
Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    CurrentGameState = json.decode(msg.Data)
    Me = CurrentGameState.Players[ao.id]
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("Game state updated. Print 'CurrentGameState' for detailed view.")
end)

-- Decide next action
Handlers.add("DecideNextAction", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if CurrentGameState.GameMode ~= "Playing" then
        ActionInProgress = false
        return
    end
    heal()
    useShield()
    gatherEnergy()
    decideNextAction()
    ao.send({ Target = ao.id, Action = "Tick" })
end)

-- Automatically attack when hit
Handlers.add("ReturnAttack", Handlers.utils.hasMatchingTag("Action", "Hit"), function(msg)
    if not ActionInProgress then
        ActionInProgress = true
        local playerEnergy = Me.energy
        if playerEnergy and playerEnergy > 0 then
            print(colors.red .. "Returning attack." .. colors.reset)
            ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
        end
        ActionInProgress = false
        ao.send({ Target = ao.id, Action = "Tick" })
    end
end)
