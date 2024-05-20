-- 初始化全局变量来存储最新的游戏状态和游戏主机进程。
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

function addLog(msg, text) -- 函数定义注释用于性能，可用于调试
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

-- 检查两个点是否在给定范围内。
-- @param x1, y1: 第一个点的坐标
-- @param x2, y2: 第二个点的坐标
-- @param range: 点之间允许的最大距离
-- @return: Boolean 指示点是否在指定范围内
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- 根据玩家的距离和能量决定下一步行动。
-- 如果有玩家在范围内，则发起攻击； 否则，随机移动。
function decideNextAction()
  -- 玩家状态
  local player = LatestGameState.Players[ao.id]
  -- 在范围内触发攻击
  local targetInRange = false
  -- 标记的玩家血量
  local markedhealthPoints =100
  -- 标记血量低于攻击能量的玩家
  local markedPlayer =nil

  for target, state in pairs(LatestGameState.Players) do

      if target == ao.id then
         goto continue
      end
      --  筛选指定范围内健康值小于能量的玩家
      if inRange(player.x, player.y, state.x, state.y, 2) and state.health <= player.energy then
          -- 标记血量低于标记玩家血量的玩家
          if state.health  < markedhealthPoints then
            markedhealthPoints=state.health
            markedPlayer= target
          end       
      end

      if inRange(player.x, player.y, state.x, state.y, Range) and markedPlayer then
        -- 进入攻击范围
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

-- 打印游戏公告并触发游戏状态更新的handler。
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print("Current player information. health:".. player.health.. " energy:".. player.energy .." position x:".. player.x .. "y:" .. player.y)
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

-- 触发游戏状态更新的handler。
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
      print("Previous action still in progress. Skipping.")
  end
)


-- 接收游戏状态信息后更新游戏状态的handler。
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

-- 决策下一个最佳操作的handler。
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- 被其他玩家击中时自动攻击的handler。
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