
LatestGameState = LatestGameState or nil
Game = Game or nil
Range = 1 


Logs = Logs or {}

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

function addLog(msg, text) 
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

function adjustPosition(point1,point2)
  if math.abs(point1 - point2) > 20 then
    if point1 < 20 and point2 >= 20 then
      point2 = point2 - 40
    end
    
    if point1 >= 20 and point2 < 20 then
      point1 = point1 - 40
    end
  end

  return point1, point2
end


function  getDirection(sourceX,sourceY,targetX,targetY)
  sourceX,targetX = adjustPosition( sourceX,targetX)
  sourceY,targetY = adjustPosition(sourceY,targetY)
  local dx, dy = targetX - sourceX, targetY - sourceY
  local directionX,directionY = "", ""

  if dx > 0 then
    directionX = "Right"
  else
    directionX = "Left"
  end

  if dy > 0 then
    directionY = "Down"
  else
    directionY = "Up"
  end

  return directionX .. directionY
end

function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end


function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local markedhealthPoints =100
  local markedPlayer =nil

  for target, state in pairs(LatestGameState.Players) do

      if target == ao.id then
         goto continue
      end
      
      if inRange(player.x, player.y, state.x, state.y, 2) and state.health <= player.energy then
          
          if state.health  < markedhealthPoints then
            markedhealthPoints=state.health
            markedPlayer= target
          end       
      end

      if inRange(player.x, player.y, state.x, state.y, Range) and markedPlayer then
       
        targetInRange = true
      end 
      ::continue::
  end

  if targetInRange then
    print(colors.red .. "Player in range. Attacking... Other Player Health Points:" ..markedhealthPoints .. colors.reset)
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy)})
  else
    local moveDirection = nil
    if markedPlayer then
      moveDirection = getDirection(player.x,player.y,markedPlayer.x,markedPlayer.y)
       print(colors.red .. "Move towards the direction of the marked player." .. colors.reset)
    else
      print(colors.red .. "No player in range or insufficient energy. Moving randomly." .. colors.reset)
      local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
      local randomIndex = math.random(#directionMap)
      moveDirection=directionMap[randomIndex]   
    end
    print(colors.red .. "The direction in which the player will move:".. moveDirection .. colors.reset)
    ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDirection})  
  end
end


Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print("Current player information. health:".. player.health.. " energy:".. player.energy .." position x:".. player.x .. "y:" .. player.y)
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)


Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
      print("Previous action still in progress. Skipping.")
  end
)



Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    local player = LatestGameState.Players[ao.id]
    print("Current player information. health:".. player.health.. " energy:".. player.energy .." position x:".. player.x .. "y:" .. player.y)
  end
)


Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print(colors.red .. "Unable to read energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print(colors.red .. "Player has insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      ao.send({Target = ao.id, Action = "Tick"})
    
  end
)
Prompt = function() return Name .. "> " end
