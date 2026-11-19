local SCRIPT = [==[
local VERSION=11
local env=(getgenv and getgenv()) or _G

-- Останавливаем предыдущий экземпляр
if type(env.AutoFarmStop)=="function" then
 pcall(env.AutoFarmStop)
end

env.AutoFarmVersion=VERSION
env.AutoFarmJob=game.JobId

-- Настройки
local HttpService=game:GetService("HttpService")
local SETTINGS_FILE="AutoFarmSettings.json"

local settings={
 speed=50,
 noclip=false,
 aim=false,
 antiStuck=false,
 height=-8,
 dist=0,
 slot=2,
 tp=false,
 remote=true,
 buff=true,
 buffPick=4,
 buffGui="",
 slotTools={},
 keyDelay=.2,
 cycleDelay=.3,
 clickDelay=.1,
 -- НОВЫЕ НАСТРОЙКИ ДЛЯ ОБХОДА АНТИЧИТА
 teleportMode="smooth", -- "smooth" = плавное перемещение, "instant" = мгновенное
 antiCheatDelay=0.5,    -- задержка перед использованием способностей после телепорта
 useHumanoidMove=true,  -- использовать Humanoid:MoveTo вместо CFrame
 randomizePath=true     -- случайные небольшие отклонения от прямой линии
}

-- Функции загрузки/сохранения настроек (как в оригинале)
local function loadSettings()
 local data=nil
 pcall(function()
  if readfile and isfile and isfile(SETTINGS_FILE) then
   data=HttpService:JSONDecode(readfile(SETTINGS_FILE))
  end
 end)
 if type(data)~="table" and type(env.AutoFarmSettings)=="table" then
  data=env.AutoFarmSettings
 end
 if type(data)=="table" then
  for key,default in pairs(settings) do
   local value=data[key]
   if value~=nil and type(value)==type(default) then
    settings[key]=value
   end
  end
 end
 -- Клэмпы
 settings.speed=math.clamp(settings.speed,5,1000)
 settings.height=math.clamp(settings.height,-50,50)
 settings.dist=math.clamp(settings.dist,-50,50)
 settings.slot=math.floor(math.clamp(settings.slot,1,9))
 settings.buffPick=math.floor(math.clamp(settings.buffPick,1,4))
 settings.keyDelay=math.clamp(settings.keyDelay,0,2)
 settings.cycleDelay=math.clamp(settings.cycleDelay,0,3)
 settings.clickDelay=math.clamp(settings.clickDelay,.02,1)
 settings.antiCheatDelay=math.clamp(settings.antiCheatDelay,0.1,2)
end

local function saveSettings()
 env.AutoFarmSettings=settings
 pcall(function()
  if writefile then
   writefile(SETTINGS_FILE,HttpService:JSONEncode(settings))
  end
 end)
end

loadSettings()

-- Ждём загрузки игры
if not game:IsLoaded() then
 game.Loaded:Wait()
end

-- Сервисы
local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local RS=game:GetService("ReplicatedStorage")
local Core=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local me=P.LocalPlayer
local pg=me:WaitForChild("PlayerGui")

-- Очистка старого GUI
pcall(function()
 local old=Core:FindFirstChild("AutoFarm")
 if old then old:Destroy() end
end)

-- Переменные состояния
local on=false
local target=nil
local follow=nil
local retryBusy=false
local startedCount=0
local interacting=false
local keyDone=false
local doorDone=false
local slotBusy=false
local slotIndex=settings.slot
local slotName=settings.slotTools[tostring(slotIndex)]
local lastEquipAt=0
local missingSince=0
local startedAt=os.clock()

-- НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ОБХОДА АНТИЧИТА
local lastTeleportAt=0
local canUseSkills=true
local skillCooldown=settings.antiCheatDelay
local lastPosition=Vector3.new()
local teleportCount=0
local pathPoints={}

-- Клавиши слотов
local SLOT_KEYS={
 Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
 Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
 Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine
}
local characterVersion=0
local lastPick=0

-- Настройки из файла
local noclipEnabled=settings.noclip
local aimEnabled=settings.aim
local antiStuckEnabled=settings.antiStuck
local teleportMode=settings.tp
local remotePick=settings.remote
local buffEnabled=settings.buff
local buffPick=settings.buffPick
local knownBuffGui=settings.buffGui
local remoteFails=0
local keyDelay=settings.keyDelay
local cycleDelay=settings.cycleDelay
local clickDelay=settings.clickDelay
local runId=0
local OFFSET_Y=settings.height
local OFFSET_DIST=settings.dist
local MOVE_SPEED=settings.speed
local ARRIVE_DIST=1.5
local CHECK_WINDOW=.4
local MIN_PROGRESS=.5
local NOCLIP_TIME=2
local REPOSITION_DIST=6
local TARGET_TIMEOUT=25

local tpTarget=nil
local lastTP=0
local lostAt=0
local targetSince=0
local gliding=false
local autoNoclip=false
local lastGlide=0
local winStart=0
local winPos=nil
local winDist=0
local autoUntil=0

-- НОВАЯ ФУНКЦИЯ: Проверка, можно ли использовать способности
local function canUseSkillsNow()
 if not on then return false end
 if interacting then return false end
 if not target then return false end
 
 -- Задержка после телепорта
 local timeSinceTP = os.clock() - lastTeleportAt
 if timeSinceTP < skillCooldown then
  return false
 end
 
 -- Проверка, что мы не двигаемся слишком быстро
 local root = getRoot()
 if root then
  local velocity = root.AssemblyLinearVelocity
  if velocity and velocity.Magnitude > 50 then
   return false
  end
 end
 
 return true
end

-- НОВАЯ ФУНКЦИЯ: Плавное перемещение с обходом античита
local function smoothMoveTo(targetPos)
 local root = getRoot()
 if not root then return end
 
 local humanoid = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
 if not humanoid then return end
 
 -- Используем Humanoid:MoveTo для более естественного движения
 if settings.useHumanoidMove then
  humanoid:MoveTo(targetPos)
  humanoid:MoveToFinished:Wait(0.1)
 else
  -- Или плавное CFrame перемещение
  local current = root.Position
  local direction = (targetPos - current)
  local distance = direction.Magnitude
  local step = math.min(distance, MOVE_SPEED * 0.1)
  local newPos = current + direction.Unit * step
  root.CFrame = CFrame.lookAt(newPos, targetPos)
 end
end

-- НОВАЯ ФУНКЦИЯ: Телепорт с обходом античита
local function safeTeleport(pos)
 local root = getRoot()
 if not root then return end
 
 -- Запоминаем время последнего телепорта
 lastTeleportAt = os.clock()
 teleportCount = teleportCount + 1
 
 -- Случайное отклонение от прямой
 local offset = Vector3.new(
  (math.random() - 0.5) * 0.5,
  0,
  (math.random() - 0.5) * 0.5
 )
 
 -- Разбиваем телепорт на несколько маленьких шагов
 local current = root.Position
 local target = pos + offset
 local steps = math.max(2, math.ceil((target - current).Magnitude / 10))
 
 for i = 1, steps do
  if not on then return end
  local t = i / steps
  local newPos = current:Lerp(target, t)
  root.CFrame = CFrame.new(newPos)
  task.wait(0.01) -- Маленькая задержка между шагами
 end
 
 -- Сброс скорости после телепорта
 root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

-- Остальные функции из оригинального скрипта (сокращены для краткости)
-- ... (все функции: mobRoot, ensureHold, releaseHold, press, holdE, и т.д.)

-- НОВАЯ ФУНКЦИЯ: Атака с проверкой античита
local function attackSkills()
 if not canUseSkillsNow() then return end
 
 local keys = {
  Enum.KeyCode.F,
  Enum.KeyCode.F,
  Enum.KeyCode.C,
  Enum.KeyCode.V
 }
 
 -- Слот 1 дополнительно
 if slotIndex==1 and equippedTool() then
  table.insert(keys,Enum.KeyCode.R)
 end
 
 -- Случайная задержка между нажатиями
 for i,k in ipairs(keys) do
  if not on then return end
  if i>1 then
   local delay = keyDelay * (0.8 + math.random() * 0.4) -- Случайная вариация
   task.wait(delay)
  end
  press(k)
 end
end

-- НОВАЯ ФУНКЦИЯ: Обновлённый farmStep с обходом античита
local function farmStep()
 local root=getRoot()
 if not root then
  dbg.Text="NO ROOT"
  return
 end
 
 if not workspace:FindFirstChild("Mobs") then
  dbg.Text="NO workspace.Mobs"
  return
 end
 
 local prev=target
 local t=mobRoot(target)
 
 -- Обработка цели (как в оригинале)
 if not t and target then
  local folder=workspace:FindFirstChild("Mobs")
  local h=target:FindFirstChildOfClass("Humanoid")
  if folder and target:IsDescendantOf(folder) and (not h or h.Health>0) then
   if lostAt==0 then lostAt=os.clock() end
   if os.clock()-lostAt<.5 then
    dbg.Text="WAIT..."
    return
   end
  end
 end
 
 if t then
  lostAt=0
  if TARGET_TIMEOUT>0 and os.clock()-targetSince>TARGET_TIMEOUT then
   local other=nearest(root,target)
   if other then
    target=other
    t=mobRoot(target)
   end
  end
 else
  lostAt=0
  gliding=false
  endAuto()
  target=nearest(root)
  t=mobRoot(target)
 end
 
 if target~=prev then
  targetSince=os.clock()
 end
 
 if not t then
  gliding=false
  endAuto()
  dbg.Text="NO TARGET"
  return
 end
 
 -- Движение к цели
 local desired=goalFor(t)
 local dist=(root.Position-desired).Magnitude
 
 if target~=tpTarget or (not gliding and dist>REPOSITION_DIST) then
  gliding=true
  tpTarget=target
  winPos=nil
 end
 
 pcall(ensureHold,root)
 dbg.Text=target.Name.." d="..math.floor(dist)..(gliding and " GO" or " AT")..(autoNoclip and " NC" or "")
end

-- НОВАЯ ФУНКЦИЯ: Обновлённый glideStep с обходом античита
local function glideStep(dt)
 if not gliding then return end
 
 local root=getRoot()
 local t=mobRoot(target)
 if not root or not t then return end
 
 local desired=goalFor(t)
 local offset=desired-root.Position
 local dist=offset.Magnitude
 
 if dist<=ARRIVE_DIST or teleportMode then
  -- Пришли
  gliding=false
  endAuto()
  root.CFrame=CFrame.lookAt(desired,t.Position)
  root.AssemblyLinearVelocity=Vector3.new(0,0,0)
  lastTeleportAt=os.clock() -- Обновляем время последнего "телепорта"
  return
 end
 
 antiStuck(root,dist)
 
 -- Используем плавное перемещение вместо прямого CFrame
 if settings.useHumanoidMove then
  local humanoid = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
  if humanoid then
   humanoid:MoveTo(desired)
  end
 else
  local step=math.min(dist,MOVE_SPEED*dt)
  local newPos=root.Position+offset.Unit*step
  root.CFrame=CFrame.lookAt(newPos,t.Position)
  root.AssemblyLinearVelocity=Vector3.new(0,0,0)
 end
end

-- НОВАЯ ФУНКЦИЯ: Проверка подозрительного поведения
local function checkForSuspiciousActivity()
 local root = getRoot()
 if not root then return false end
 
 -- Проверка скорости (не слишком ли быстро двигаемся)
 local velocity = root.AssemblyLinearVelocity
 if velocity and velocity.Magnitude > 100 then
  return true
 end
 
 -- Проверка телепортов (слишком частые)
 if os.clock() - lastTeleportAt < 0.1 then
  return true
 end
 
 -- Проверка позиции (не находимся ли в стене)
 if root.Position.Y < -100 or root.Position.Y > 1000 then
  return true
 end
 
 return false
end

-- НОВАЯ ФУНКЦИЯ: Сброс подозрительной активности
local function resetSuspiciousActivity()
 lastTeleportAt = os.clock()
 local root = getRoot()
 if root then
  root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
 end
end

-- Основной цикл с проверкой античита
local function mainLoop(myRun)
 while on and myRun==runId do
  -- Проверяем подозрительную активность
  if checkForSuspiciousActivity() then
   resetSuspiciousActivity()
   task.wait(0.5) -- Пауза для сброса
  end
 
  -- Обработка цели
  if os.clock()-lastPick>=.1 then
   lastPick=os.clock()
   local ok,err=pcall(farmStep)
   if not ok then
    dbg.Text="ERR: "..tostring(err)
   end
  end
 
  -- Плавное движение
  local ok2,err2=pcall(glideStep,math.min(dt,.1))
  if not ok2 then
   dbg.Text="ERR: "..tostring(err2)
  end
 
  task.wait(0.05)
 end
end

-- Остальной код GUI и управления (как в оригинале, но с новыми настройками)
-- ... (все кнопки и функции интерфейса)

-- НОВЫЕ КНОПКИ ДЛЯ НАСТРОЕК ОБХОДА АНТИЧИТА
local antiCheatBtn=makeToggle(450)
antiCheatBtn.Text="АНТИЧИТ: ПЛАВНО"
antiCheatBtn.BackgroundColor3=Color3.fromRGB(40,130,60)

antiCheatBtn.MouseButton1Click:Connect(function()
 settings.useHumanoidMove = not settings.useHumanoidMove
 saveSettings()
 if settings.useHumanoidMove then
  antiCheatBtn.Text="АНТИЧИТ: ПЛАВНО"
  antiCheatBtn.BackgroundColor3=Color3.fromRGB(40,130,60)
 else
  antiCheatBtn.Text="АНТИЧИТ: БЫСТРО"
  antiCheatBtn.BackgroundColor3=Color3.fromRGB(190,110,30)
 end
end)

-- Запуск
startFarm()
]==]

-- Бутстрап для обхода античита при телепортации
local BOOT_TEMPLATE = [====[
local SCRIPT=%s
local BOOT_TEMPLATE=%s

local env=(getgenv and getgenv()) or _G

if env.AutoFarmVersion then
 if env.AutoFarmVersion>11 then return end
 if env.AutoFarmVersion==11 and env.AutoFarmJob==game.JobId then return end
end

local queueFn=queue_on_teleport or (syn and syn.queue_on_teleport)

if queueFn then
 local queuedCode=string.format(
  BOOT_TEMPLATE,
  string.format("%%q",SCRIPT),
  string.format("%%q",BOOT_TEMPLATE)
 )
 pcall(function()
  queueFn(queuedCode)
 end)
end

local function showErr(msg)
 warn(msg)
 pcall(function()
  local gui=Instance.new("ScreenGui")
  gui.Name="AutoFarmError"
  gui.Parent=game:GetService("CoreGui")
  local label=Instance.new("TextLabel",gui)
  label.Size=UDim2.new(1,0,0,60)
  label.BackgroundColor3=Color3.fromRGB(120,20,20)
  label.TextColor3=Color3.new(1,1,1)
  label.TextWrapped=true
  label.TextSize=14
  label.Text=msg
 end)
end

local run,err=loadstring(SCRIPT)
if run then
 local ok,e=pcall(run)
 if not ok then
  showErr("AutoFarm error: "..tostring(e))
 end
else
 showErr("AutoFarm syntax error: "..tostring(err))
end
]====]

local BOOT=string.format(
 BOOT_TEMPLATE,
 string.format("%q",SCRIPT),
 string.format("%q",BOOT_TEMPLATE)
)

local run=loadstring(BOOT)
if run then
 run()
end
