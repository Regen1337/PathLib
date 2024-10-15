local PathLib = require("PathLib")

local gameState = {}

local players = {"player1", "player2"}
for _, player in ipairs(players) do
    PathLib.setPath(gameState, {}, "players." .. player)
end

PathLib.setPath(gameState, {}, "players.*.inventory.items")
PathLib.setPath(gameState, {}, "players.*.equipment")
PathLib.setPath(gameState, 1000, "players.*.stats.gold")

local function addItem(playerId, item, quantity)
    local path = "players." .. playerId .. ".inventory.items." .. item.id
    local currentQuantity = PathLib.path(gameState, path .. ".quantity") or 0
    PathLib.setPath(gameState, currentQuantity + quantity, path .. ".quantity")
    PathLib.setPath(gameState, item.name, path .. ".name")
    PathLib.setPath(gameState, item.type, path .. ".type")
    PathLib.setPath(gameState, item.subtype, path .. ".subtype")
    PathLib.setPath(gameState, item.rarity, path .. ".rarity")
end

local items = {
    {id = "sword1", name = "Iron Sword", type = "weapon", subtype = "sword", rarity = "common"},
    {id = "potion1", name = "Health Potion", type = "consumable", subtype = "health", rarity = "common"},
    {id = "armor1", name = "Leather Armor", type = "armor", subtype = "light", rarity = "common"},
    {id = "staff1", name = "Fire Staff", type = "weapon", subtype = "staff", rarity = "rare"},
    {id = "ring1", name = "Ring of Power", type = "accessory", subtype = "ring", rarity = "epic"}
}

for _, player in ipairs(players) do
    for _, item in ipairs(items) do
        addItem(player, item, math.random(1, 5))
    end
end

local function equipItem(playerId, itemId)
    local inventoryPath = "players." .. playerId .. ".inventory.items." .. itemId
    local equipmentPath = "players." .. playerId .. ".equipment"
    
    if PathLib.path(gameState, inventoryPath) then
        local itemType = PathLib.path(gameState, inventoryPath .. ".type")
        PathLib.setPath(gameState, PathLib.path(gameState, inventoryPath), equipmentPath .. "." .. itemType)
        PathLib.deletePath(gameState, inventoryPath)
        print(playerId .. " equipped " .. PathLib.path(gameState, equipmentPath .. "." .. itemType .. ".name"))
    else
        print("Item not found in inventory!")
    end
end

local function listItemsByRarity(rarity)
    local items = PathLib.find(gameState, function(v, path)
        return PathLib.path(gameState, path .. ".rarity") == rarity
    end)
    
    for _, itemPath in ipairs(items) do
        local playerName = itemPath:match("^players%.(.-)%.")
        local name = PathLib.path(gameState, itemPath .. ".name")
        local quantity = PathLib.path(gameState, itemPath .. ".quantity")
        print(playerName .. ": " .. name .. " x" .. quantity)
    end
end

local function calculateTotalValueBySubtype(subtype)
    local totalValue = 0
    local items = PathLib.get(gameState, "players.*.inventory.items.*")
    
    for _, item in ipairs(items) do
        if item.subtype == subtype then
            local baseValue = item.rarity == "common" and 50 or item.rarity == "rare" and 100 or 200
            totalValue = totalValue + (baseValue * item.quantity)
        end
    end
    
    return totalValue
end

local function applyEffectToItemType(itemType, effect)
    local items = PathLib.get(gameState, "players.*.inventory.items.*")
    
    for itemPath, item in pairs(items) do
        if type(item) == "table" and item.type == itemType and item.name then
            local currentName = item.name
            if not currentName:find(effect) then
                local newName = currentName .. " of " .. effect
                PathLib.setPath(gameState, newName, itemPath .. ".name")
                print("Applied effect to " .. currentName .. ". New name: " .. newName)
            end
        end
    end
end

local function transferGold(fromPlayer, toPlayer, amount)
    local fromPath = "players." .. fromPlayer .. ".stats.gold"
    local toPath = "players." .. toPlayer .. ".stats.gold"
    
    local fromGold = PathLib.path(gameState, fromPath)
    local toGold = PathLib.path(gameState, toPath)
    
    if not fromGold then
        print("Player " .. fromPlayer .. " not found!")
        return
    end

    if not toGold then
        print("Player " .. toPlayer .. " not found!")
        return
    end
    
    if fromGold >= amount then
        PathLib.setPath(gameState, fromGold - amount, fromPath)
        PathLib.setPath(gameState, toGold + amount, toPath)
        print("Transferred " .. amount .. " gold from " .. fromPlayer .. " to " .. toPlayer)
    else
        print("Insufficient gold!")
    end
end

print("Initial rare items for all players:")
listItemsByRarity("rare")

print("\nEquipping items:")
equipItem("player1", "sword1")
equipItem("player2", "staff1")

print("\nCalculating total value of swords:")
print("Total value of swords: " .. calculateTotalValueBySubtype("sword") .. " gold")

print("\nApplying 'Frost' effect to all weapons:")
applyEffectToItemType("weapon", "Frost")

print("\nUpdated weapons for all players:")
local weapons = PathLib.get(gameState, "players.*.inventory.items.*")
for _, weapon in ipairs(weapons) do
    if weapon.type == "weapon" then
        print(weapon.name)
    end
end

print("\nTransferring gold:")
transferGold("player1", "player2", 500)

print("\nFinal gold amounts:")
for _, player in ipairs(players) do
    local goldAmount = PathLib.path(gameState, "players." .. player .. ".stats.gold")
    if goldAmount then
        print(player .. ": " .. goldAmount .. " gold")
    else
        print(player .. ": No gold data found")
    end
end

local analysis = PathLib.analyzePath(gameState, "players.player1.equipment.weapon.name")
print("\nPath analysis for player1's equipped weapon name:")
for k, v in pairs(analysis) do
    if type(v) ~= "table" then
        print(k .. ": " .. tostring(v))
    else
        print(k .. ": " .. table.concat(v, ", "))
    end
end

local flatState = PathLib.flatten(PathLib.path(gameState, "players.player1"))
print("\nFlattened state for player1:")
for k, v in pairs(flatState) do
    print(k .. ": " .. tostring(v))
end
