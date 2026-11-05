local SCRIPT = [==[
local VERSION=2
local env=(getgenv and getgenv()) or _G

-- Останавливаем предыдущий экземпляр и помечаем, какая версия работает
if type(env.AutoFarmStop)=="function" then
 pcall(env.AutoFarmStop)
end

env.AutoFarmVersion=VERSION
env.AutoFarmJob=game.JobId

-- Сохранение настроек: файл переживает смену сервера и перезаход в игру.
-- Если writefile недоступен, настройки хранятся хотя бы в getgenv до выхода.
local HttpService=game:GetService("HttpService")
local SETTINGS_FILE="AutoFarmSettings.json"

local settings={
 speed=50,        -- скорость движения к мобу
 noclip=false,    -- ручной noclip
 aim=false,       -- авто-наведение
 antiStuck=false, -- антизастревание
 height=-8,       -- высота относительно моба (минус = ниже)
 dist=0           -- расстояние от моба (плюс = впереди, минус = сзади)
}

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

 settings.speed=math.clamp(settings.speed,5,300)
 settings.height=math.clamp(settings.height,-50,50)
 settings.dist=math.clamp(settings.dist,-50,50)
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

local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local RS=game:GetService("ReplicatedStorage")
local Core=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local me=P.LocalPlayer
local pg=me:WaitForChild("PlayerGui")

local services=RS.ReplicatedStorage.Packages.Knit.Services
local startRemote=services.DungeonService.RF.StartDungeon
local voteRemote=services.PartyService.RF.VoteOn
local startedEvent=services.DungeonService.RE.DungeonStarted

pcall(function()
 local old=Core:FindFirstChild("AutoFarm")
 if old then old:Destroy() end
end)

local on=false
local target=nil
local follow=nil
local retryBusy=false
local startedCount=0
local interacting=false
local keyDone=false
local doorDone=false
local slotBusy=false
local slot2Name=nil
local characterVersion=0
local lastPick=0

-- Настройки телепорта к мобу
local noclipEnabled=settings.noclip -- ручной noclip, кнопка в меню
local aimEnabled=settings.aim       -- авто-наведение, кнопка в меню
local antiStuckEnabled=settings.antiStuck -- антизастревание, кнопка в меню
local runId=0            -- номер запуска (чтобы старые циклы не жили после STOP/START)
local OFFSET_Y=settings.height   -- высота точки остановки относительно моба (минус = ниже)
local OFFSET_DIST=settings.dist   -- расстояние от моба по горизонтали (плюс = впереди, минус = сзади)
local MOVE_SPEED=settings.speed   -- скорость "бега" к мобу, studs/сек (меньше = плавнее)
local ARRIVE_DIST=1.5     -- считаем, что дошли, когда ближе этого расстояния
local CHECK_WINDOW=.4     -- как часто сверяем пройденный путь с ожидаемым (сек)
local MIN_PROGRESS=.5     -- прошли меньше этой доли ожидаемого пути = застряли
local NOCLIP_TIME=2       -- сколько секунд авто-noclip держится после включения
local REPOSITION_DIST=6   -- телепорт снова, только если ушли дальше от точки (studs)
local TARGET_TIMEOUT=25   -- если моб не умирает столько секунд, берём другого (0 = выключено)

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

-- Возвращает HumanoidRootPart моба, если он жив и лежит в workspace.Mobs
local function mobRoot(m)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder or not m or not m:IsA("Model") then return nil end
 if not m:IsDescendantOf(folder) then return nil end

 local h=m:FindFirstChildOfClass("Humanoid")
 local t=m:FindFirstChild("HumanoidRootPart")

 if h and t and h.Health>0 then return t end
 return nil
end

-- Удержание на месте (нулевая скорость), чтобы не падать между телепортами
local holdAtt=nil
local holdVel=nil

local function ensureHold(root)
 if holdVel and holdVel.Parent==root then return end

 if holdVel then holdVel:Destroy() end
 if holdAtt then holdAtt:Destroy() end

 holdAtt=Instance.new("Attachment")
 holdAtt.Parent=root

 holdVel=Instance.new("LinearVelocity")
 holdVel.Attachment0=holdAtt
 holdVel.MaxForce=math.huge
 holdVel.VectorVelocity=Vector3.zero
 holdVel.Parent=root
end

local function releaseHold()
 if holdVel then holdVel:Destroy() holdVel=nil end
 if holdAtt then holdAtt:Destroy() holdAtt=nil end
end

local g=Instance.new("ScreenGui")
g.Name="AutoFarm"
g.ResetOnSpawn=false
g.IgnoreGuiInset=true
g.Parent=Core

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(165,288)
f.Position=UDim2.new(.5,-82,.5,0)
f.BackgroundColor3=Color3.fromRGB(35,35,45)
f.Active=true
f.Draggable=true

local status=Instance.new("TextLabel",f)
status.Size=UDim2.new(1,0,0,25)
status.Text="AUTO FARM ON"
status.TextColor3=Color3.new(1,1,1)
status.BackgroundTransparency=1
status.TextSize=14

local ver=Instance.new("TextLabel",f)
ver.Size=UDim2.fromOffset(30,14)
ver.Position=UDim2.new(1,-32,0,2)
ver.Text="v"..VERSION
ver.TextSize=10
ver.TextColor3=Color3.fromRGB(160,160,160)
ver.BackgroundTransparency=1

local stop=Instance.new("TextButton",f)
stop.Size=UDim2.fromOffset(75,32)
stop.Position=UDim2.fromOffset(85,245)
stop.Text="STOP"
stop.TextColor3=Color3.new(1,1,1)
stop.BackgroundColor3=Color3.fromRGB(160,40,40)

local dbg=Instance.new("TextLabel",f)
dbg.Size=UDim2.new(1,-10,0,34)
dbg.Position=UDim2.fromOffset(5,28)
dbg.Text=""
dbg.TextColor3=Color3.fromRGB(200,200,200)
dbg.BackgroundTransparency=1
dbg.TextSize=11
dbg.TextWrapped=true

-- Строка "минус / значение / плюс"
local function makeRow(y)
 local minus=Instance.new("TextButton",f)
 minus.Size=UDim2.fromOffset(35,26)
 minus.Position=UDim2.fromOffset(5,y)
 minus.Text="-"
 minus.TextColor3=Color3.new(1,1,1)
 minus.BackgroundColor3=Color3.fromRGB(60,60,80)

 local label=Instance.new("TextLabel",f)
 label.Size=UDim2.fromOffset(75,26)
 label.Position=UDim2.fromOffset(45,y)
 label.TextColor3=Color3.new(1,1,1)
 label.BackgroundTransparency=1
 label.TextSize=12

 local plus=Instance.new("TextButton",f)
 plus.Size=UDim2.fromOffset(35,26)
 plus.Position=UDim2.fromOffset(125,y)
 plus.Text="+"
 plus.TextColor3=Color3.new(1,1,1)
 plus.BackgroundColor3=Color3.fromRGB(60,60,80)

 return minus,label,plus
end

-- Кнопка-переключатель на всю ширину
local function makeToggle(y)
 local button=Instance.new("TextButton",f)
 button.Size=UDim2.new(1,-10,0,26)
 button.Position=UDim2.fromOffset(5,y)
 button.TextSize=11
 button.TextColor3=Color3.new(1,1,1)
 return button
end

local speedMinus,speedLabel,speedPlus=makeRow(65)
local heightMinus,heightLabel,heightPlus=makeRow(95)
local distMinus,distLabel,distPlus=makeRow(125)
local noclipBtn=makeToggle(155)
local aimBtn=makeToggle(185)
local stuckBtn=makeToggle(215)

local startBtn=Instance.new("TextButton",f)
startBtn.Size=UDim2.fromOffset(75,32)
startBtn.Position=UDim2.fromOffset(5,245)
startBtn.Text="START"
startBtn.TextColor3=Color3.new(1,1,1)
startBtn.BackgroundColor3=Color3.fromRGB(40,130,60)

local function press(k)
 V:SendKeyEvent(true,k,false,game)
 task.wait(.12)
 V:SendKeyEvent(false,k,false,game)
end

local function holdE(duration)
 V:SendKeyEvent(true,Enum.KeyCode.E,false,game)
 task.wait(duration)
 V:SendKeyEvent(false,Enum.KeyCode.E,false,game)
end

local function repeatE(duration)
 local elapsed=0

 while on and elapsed<duration do
  press(Enum.KeyCode.E)
  task.wait(.3)
  elapsed=elapsed+.42
 end
end

local function getRoot()
 local c=me.Character
 return c and c:FindFirstChild("HumanoidRootPart")
end

-- Текущая позиция курсора: клики идут туда, где он уже стоит
local function mouseXY()
 local m=UIS:GetMouseLocation()
 return m.X,m.Y
end

-- Курсор над меню: автоклики на это время не шлём, иначе они мешают
-- нажимать кнопки (+, -, NOCLIP, STOP)
local function overGui()
 local m=UIS:GetMouseLocation()
 local p=f.AbsolutePosition
 local sz=f.AbsoluteSize

 return m.X>=p.X-10 and m.X<=p.X+sz.X+10
  and m.Y>=p.Y-10 and m.Y<=p.Y+sz.Y+10
end

-- Курсор свободен: над меню или зажат левый Ctrl (чтобы дотянуться до кнопок)
local function cursorFree()
 return overGui() or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
end

-- Экранная точка цели; без цели - текущая позиция курсора
local function aimXY()
 local cam=workspace.CurrentCamera
 local t=target and target:FindFirstChild("HumanoidRootPart")

 if cam and t then
  local p=cam:WorldToViewportPoint(t.Position)
  return p.X,p.Y
 end

 return mouseXY()
end

-- Куда кликать: на цель при включённом наведении, иначе туда, где курсор
local function clickXY()
 if aimEnabled and not cursorFree() then
  return aimXY()
 end

 return mouseXY()
end

-- Экипировка второго слота
local function equippedTool()
 local c=me.Character
 return c and c:FindFirstChildOfClass("Tool")
end

local function waitTool(timeout)
 local t0=os.clock()

 while on and os.clock()-t0<timeout do
  local tool=equippedTool()
  if tool then return tool end
  task.wait(.1)
 end

 return nil
end

local function ensureSlot2()
 if slotBusy or not on then return end

 local c=me.Character
 local hum=c and c:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end

 -- второй слот уже в руках: ничего не нажимаем (клавиша 2 переключает)
 local tool=equippedTool()
 if slot2Name and tool and tool.Name==slot2Name then return end

 slotBusy=true
 status.Text="SELECTING SLOT 2"

 -- если в руках что-то другое/неизвестное, сначала убираем, чтобы 2 не снял слот
 if tool then
  hum:UnequipTools()
  task.wait(.4)
 end

 if on then
  press(Enum.KeyCode.Two)
  local equipped=waitTool(1.5)

  if equipped and not slot2Name then
   slot2Name=equipped.Name
  end
 end

 slotBusy=false
 if on then status.Text="AUTO FARM ON" end
end

local function nearest(r,skip)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder then return nil end

 local best=nil
 local distance=math.huge

 for _,n in ipairs(folder:GetChildren()) do
  if n:IsA("Model") and n~=me.Character and n~=skip then
   local h=n:FindFirstChildOfClass("Humanoid")
   local t=n:FindFirstChild("HumanoidRootPart")

   if h and t and h.Health>0 then
    local d=(r.Position-t.Position).Magnitude
    if d<distance then
     best=n
     distance=d
    end
   end
  end
 end

 return best
end

-- Способности по очереди: первая сразу, дальше пауза 0.4 между клавишами
local function attackSkills()
 local keys={
  Enum.KeyCode.F,
  Enum.KeyCode.F,
  Enum.KeyCode.C,
  Enum.KeyCode.V
 }

 for i,k in ipairs(keys) do
  if not on then return end
  if i>1 then task.wait(.4) end
  press(k)
 end
end

local function dungeonComplete()
 local screen=pg:FindFirstChild("DungeonComplete")
 if not screen then return false end
 if screen:IsA("ScreenGui") and not screen.Enabled then
  return false
 end

 local button=screen:FindFirstChild("RetryBtn",true)
 if not button or not button:IsA("GuiObject") then
  return false
 end

 local obj=button
 while obj and obj~=pg do
  if obj:IsA("GuiObject") and not obj.Visible then
   return false
  end
  if obj:IsA("ScreenGui") and not obj.Enabled then
   return false
  end
  obj=obj.Parent
 end

 return true
end

startedEvent.OnClientEvent:Connect(function()
 startedCount=startedCount+1
 keyDone=false
 doorDone=false
 target=nil
end)

local function startDungeon()
 status.Text="STARTING DUNGEON"

 local ok=pcall(function()
  startRemote:InvokeServer()
 end)

 if ok then
  status.Text="AUTO FARM ON"
 else
  status.Text="START ERROR"
 end
end

local function retryLoop(myRun)
 while on and myRun==runId do
  if dungeonComplete() and not retryBusy then
   retryBusy=true
   status.Text="RETRYING..."

   local before=startedCount

   local ok=pcall(function()
    voteRemote:InvokeServer("Retry")
   end)

   if ok then
    status.Text="WAITING..."
    local elapsed=0

    while on and elapsed<10 do
     if startedCount>before then break end
     task.wait(.5)
     elapsed=elapsed+.5
    end

    if on and startedCount==before then
     startDungeon()
    end
   else
    status.Text="RETRY ERROR"
   end

   while on and dungeonComplete() do
    task.wait(.5)
   end

   task.wait(2)
   retryBusy=false
  end

  task.wait(.5)
 end
end

local function findKey()
 local keys={}

 for _,obj in ipairs(workspace:GetDescendants()) do
  if obj.Name:lower()=="key" then
   local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
   local part=obj:IsA("BasePart") and obj
    or obj:FindFirstChild("Handle",true)
    or obj:FindFirstChildWhichIsA("BasePart",true)

   if prompt and part and part:IsA("BasePart") and prompt.Enabled then
    table.insert(keys,{part=part,prompt=prompt})
   end
  end
 end

 return keys[2]
end

local function findDoors()
 local doors={}

 for _,obj in ipairs(workspace:GetDescendants()) do
  if obj.Name:lower()=="keyhole" then
   local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
   local part=obj:IsA("BasePart") and obj
    or obj:FindFirstChildWhichIsA("BasePart",true)

   if prompt and part and part:IsA("BasePart") and prompt.Enabled then
    table.insert(doors,{part=part,prompt=prompt})
   end
  end
 end

 return doors
end

local function collectKey()
 local key=findKey()
 if not key then return false end

 local root=getRoot()
 if not root then return false end

 interacting=true
 status.Text="GOING TO KEY"

 root.CFrame=key.part.CFrame*CFrame.new(0,2,0)
 task.wait(1)

 if on then
  status.Text="PICKING KEY"
  repeatE(5)
  task.wait(2)
 end

 interacting=false
 return on
end

local function unlockDoors()
 local doors=findDoors()
 if #doors==0 then return false end

 interacting=true

 for i,door in ipairs(doors) do
  if not on then break end

  local root=getRoot()
  if not root then break end

  status.Text="GOING TO DOOR "..i
  root.CFrame=door.part.CFrame*CFrame.new(0,0,-1)
  root.AssemblyLinearVelocity=Vector3.zero

  local attachment=Instance.new("Attachment")
  attachment.Parent=root

  local velocity=Instance.new("LinearVelocity")
  velocity.Attachment0=attachment
  velocity.MaxForce=math.huge
  velocity.VectorVelocity=Vector3.zero
  velocity.Parent=root

  task.wait(3)

  if on then
   status.Text="UNLOCKING DOOR "..i

   for attempt=1,3 do
    if not on then break end
    holdE(1.5)
    task.wait(1)
   end
  end

  velocity:Destroy()
  attachment:Destroy()
  task.wait(2)
 end

 if on then
  doorDone=true
  ensureSlot2()
  task.wait(1)
 end

 interacting=false
 if on then status.Text="AUTO FARM ON" end

 return on
end

local function keyDoorLoop(myRun)
 while on and myRun==runId do
  if not keyDone then
   if findKey() then
    if collectKey() and on then
     keyDone=true
    end
   end
  elseif not doorDone then
   if #findDoors()>0 then
    unlockDoors()
   end
  end

  task.wait(1)
 end
end

-- Без столкновений: не застреваем в стенах/полу, пока бежим к мобу.
-- Отключаем CanCollide и на Stepped, и на Heartbeat, чтобы игра не успела
-- вернуть его. Удержание на месте (ensureHold) включается там же,
-- чтобы без столкновений не провалиться вниз.
local noclipConns={}
local noclipParts={}

local function applyNoclip()
 local c=me.Character
 if not c then return end

 local root=c:FindFirstChild("HumanoidRootPart")
 if root then pcall(ensureHold,root) end

 for _,part in ipairs(c:GetDescendants()) do
  if part:IsA("BasePart") and part.CanCollide then
   noclipParts[part]=true
   part.CanCollide=false
  end
 end
end

local function setNoclip(state)
 if state then
  if #noclipConns>0 then return end

  noclipConns[1]=R.Stepped:Connect(applyNoclip)
  noclipConns[2]=R.Heartbeat:Connect(applyNoclip)
 else
  for _,conn in ipairs(noclipConns) do
   conn:Disconnect()
  end

  noclipConns={}

  for part in pairs(noclipParts) do
   if part.Parent then part.CanCollide=true end
  end

  noclipParts={}
 end
end

-- Временный noclip, включённый автоматически (когда застряли)
local function endAuto()
 if autoNoclip then
  autoNoclip=false

  if not noclipEnabled then
   setNoclip(false)
  end
 end
end

-- Точка, куда идём: относительно моба по высоте и расстоянию.
-- По умолчанию (height=-8, dist=0) это точка на 8 studs под мобом.
local function goalFor(t)
 local look=t.CFrame.LookVector
 local flat=Vector3.new(look.X,0,look.Z)

 if flat.Magnitude>.001 then
  flat=flat.Unit
 else
  flat=Vector3.zero
 end

 return t.Position+flat*OFFSET_DIST+Vector3.new(0,OFFSET_Y,0)
end

-- Антизастревание: каждые CHECK_WINDOW сек сравнивает, сколько персонаж
-- реально прошёл и сколько должен был при MOVE_SPEED. Если меньше доли
-- MIN_PROGRESS, на NOCLIP_TIME секунд включает noclip и затем выключает.
-- Работает, только если включено в меню и ручной noclip выключен.
local function antiStuck(root,dist)
 local now=os.clock()

 -- новое окно измерения: начало движения или пауза (ключи/двери, лаг)
 if not winPos or now-lastGlide>.5 then
  winStart=now
  winPos=root.Position
  winDist=dist
 end

 lastGlide=now

 if not antiStuckEnabled or noclipEnabled then
  endAuto()
  winStart=now
  winPos=root.Position
  winDist=dist
  return
 end

 if autoNoclip then
  if now>=autoUntil then
   endAuto()
   winStart=now
   winPos=root.Position
   winDist=dist
  end
 elseif now-winStart>=CHECK_WINDOW then
  local moved=(root.Position-winPos).Magnitude
  local expected=math.min(MOVE_SPEED*(now-winStart),winDist)

  if expected>2 and moved<expected*MIN_PROGRESS then
   autoNoclip=true
   autoUntil=now+NOCLIP_TIME
   setNoclip(true)
  end

  winStart=now
  winPos=root.Position
  winDist=dist
 end
end

-- Решение: какого моба бить и нужно ли к нему идти (раз в 0.2 сек)
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

 -- моб на месте и жив, но Humanoid/HRP на миг пропал: ждём до 0.5 сек
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

  -- моб слишком долго не умирает: переходим к другому
  if TARGET_TIMEOUT>0 and os.clock()-targetSince>TARGET_TIMEOUT then
   local other=nearest(root,target)

   if other then
    target=other
    t=mobRoot(target)
   end
  end
 else
  -- цель мертва или исчезла: короткая пауза, затем следующая
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

 -- идти к мобу: новая цель или моб ушёл дальше REPOSITION_DIST
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

-- Плавное перемещение каждый кадр: маленькие шаги со скоростью MOVE_SPEED
-- вместо одного далёкого телепорта. Когда дошли, ничего не пишем.
local function glideStep(dt)
 if not gliding then return end

 local root=getRoot()
 local t=mobRoot(target)
 if not root or not t then return end

 local desired=goalFor(t)
 local offset=desired-root.Position
 local dist=offset.Magnitude

 if dist<=ARRIVE_DIST then
  gliding=false
  endAuto()
  root.CFrame=CFrame.lookAt(desired,t.Position)
  root.AssemblyLinearVelocity=Vector3.zero
  return
 end

 antiStuck(root,dist)

 local step=math.min(dist,MOVE_SPEED*dt)
 local newPos=root.Position+offset.Unit*step

 root.CFrame=CFrame.lookAt(newPos,t.Position)
 root.AssemblyLinearVelocity=Vector3.zero
end

-- Бьём сразу, как только есть цель (не ждём, пока дойдём)
local function canAttack()
 return target~=nil
end

local function startFarm()
 if on then return end
 on=true
 runId=runId+1
 local myRun=runId
 if noclipEnabled then setNoclip(true) end

 -- Следит, чтобы второй слот был в руках всегда (в том числе после смерти)
 task.spawn(function()
  while on and myRun==runId do
   if not interacting then
    ensureSlot2()
   end

   task.wait(1)
  end
 end)

 task.spawn(startDungeon)

 follow=R.Heartbeat:Connect(function(dt)
  if not on or interacting then return end

  -- решение о цели раз в 0.2 сек
  if os.clock()-lastPick>=.2 then
   lastPick=os.clock()

   local ok,err=pcall(farmStep)
   if not ok then
    dbg.Text="ERR: "..tostring(err)
   end
  end

  -- плавный шаг к мобу каждый кадр, пока идём
  local ok2,err2=pcall(glideStep,math.min(dt,.1))
  if not ok2 then
   dbg.Text="ERR: "..tostring(err2)
  end
 end)

 -- Быстрые клики левой кнопкой в отдельном цикле
 task.spawn(function()
  while on and myRun==runId do
   local folder=workspace:FindFirstChild("Mobs")

   if not interacting and target and folder
   and target:IsDescendantOf(folder)
   and canAttack()
   and not overGui() then

    local x,y=clickXY()
    V:SendMouseButtonEvent(x,y,0,true,game,0)
    task.wait(.1)
    x,y=clickXY()
    V:SendMouseButtonEvent(x,y,0,false,game,0)
   end

   task.wait(.1)
  end

  local x,y=mouseXY()
  V:SendMouseButtonEvent(x,y,0,false,game,0)
 end)

 -- Авто-наведение: камера смотрит на цель, курсор стоит на цели
 pcall(function() R:UnbindFromRenderStep("AutoFarmAim") end)
 R:BindToRenderStep("AutoFarmAim",Enum.RenderPriority.Camera.Value+1,function()
  if not on or not aimEnabled or interacting then return end

  local cam=workspace.CurrentCamera
  local t=mobRoot(target)

  if cam and t then
   cam.CFrame=CFrame.lookAt(cam.CFrame.Position,t.Position)
  end
 end)

 task.spawn(function()
  while on and myRun==runId do
   if aimEnabled and target and not interacting and not cursorFree() then
    local x,y=aimXY()
    V:SendMouseMoveEvent(x,y,game)
   end

   task.wait(.05)
  end
 end)

 -- Способности отдельно от кликов мыши
 task.spawn(function()
  while on and myRun==runId do
   local folder=workspace:FindFirstChild("Mobs")

   if not interacting and target and folder
   and target:IsDescendantOf(folder)
   and canAttack() then
    attackSkills()
   end

   task.wait(1)
  end
 end)

 task.spawn(retryLoop,myRun)
 task.spawn(keyDoorLoop,myRun)
end

me.CharacterAdded:Connect(function()
 characterVersion=characterVersion+1
 local version=characterVersion
 target=nil

 if on then
  task.spawn(function()
   task.wait(1.5)

   if on and version==characterVersion then
    ensureSlot2()
   end
  end)
 end
end)

stop.MouseButton1Click:Connect(function()
 on=false
 interacting=false
 target=nil
 retryBusy=false
 keyDone=false
 doorDone=false

 local x,y=mouseXY()
 V:SendMouseButtonEvent(x,y,0,false,game,0)
 V:SendKeyEvent(false,Enum.KeyCode.Two,false,game)
 V:SendKeyEvent(false,Enum.KeyCode.E,false,game)

 status.Text="AUTO FARM OFF"
 tpTarget=nil
 gliding=false
 pcall(function() R:UnbindFromRenderStep("AutoFarmAim") end)
 autoNoclip=false
 setNoclip(false)
 releaseHold()

 if follow then
  follow:Disconnect()
  follow=nil
 end
end)

local function shutdown()
 on=false
 interacting=false
 target=nil
 gliding=false

 pcall(function() R:UnbindFromRenderStep("AutoFarmAim") end)
 autoNoclip=false
 pcall(function() setNoclip(false) end)
 pcall(releaseHold)

 if follow then
  pcall(function() follow:Disconnect() end)
  follow=nil
 end

 pcall(function() V:SendMouseButtonEvent(0,0,0,false,game,0) end)
 pcall(function() g:Destroy() end)
end

env.AutoFarmStop=shutdown

local ON_COLOR=Color3.fromRGB(40,130,60)
local OFF_COLOR=Color3.fromRGB(90,90,90)

local function refreshSpeed()
 speedLabel.Text="SPEED: "..MOVE_SPEED
end

local function refreshHeight()
 heightLabel.Text="HEIGHT: "..OFFSET_Y
end

local function refreshDist()
 distLabel.Text="DIST: "..OFFSET_DIST
end

speedMinus.MouseButton1Click:Connect(function()
 MOVE_SPEED=math.max(5,MOVE_SPEED-5)
 settings.speed=MOVE_SPEED
 saveSettings()
 refreshSpeed()
end)

speedPlus.MouseButton1Click:Connect(function()
 MOVE_SPEED=math.min(300,MOVE_SPEED+5)
 settings.speed=MOVE_SPEED
 saveSettings()
 refreshSpeed()
end)

heightMinus.MouseButton1Click:Connect(function()
 OFFSET_Y=math.max(-50,OFFSET_Y-1)
 settings.height=OFFSET_Y
 saveSettings()
 refreshHeight()
end)

heightPlus.MouseButton1Click:Connect(function()
 OFFSET_Y=math.min(50,OFFSET_Y+1)
 settings.height=OFFSET_Y
 saveSettings()
 refreshHeight()
end)

distMinus.MouseButton1Click:Connect(function()
 OFFSET_DIST=math.max(-50,OFFSET_DIST-1)
 settings.dist=OFFSET_DIST
 saveSettings()
 refreshDist()
end)

distPlus.MouseButton1Click:Connect(function()
 OFFSET_DIST=math.min(50,OFFSET_DIST+1)
 settings.dist=OFFSET_DIST
 saveSettings()
 refreshDist()
end)

local function refreshNoclip()
 if noclipEnabled then
  noclipBtn.Text="NOCLIP: ON"
  noclipBtn.BackgroundColor3=ON_COLOR
 else
  noclipBtn.Text="NOCLIP: OFF"
  noclipBtn.BackgroundColor3=OFF_COLOR
 end
end

noclipBtn.MouseButton1Click:Connect(function()
 noclipEnabled=not noclipEnabled
 settings.noclip=noclipEnabled
 saveSettings()
 refreshNoclip()

 if on then
  setNoclip(noclipEnabled or autoNoclip)
 end
end)

local function refreshAim()
 if aimEnabled then
  aimBtn.Text="AIM: ON (hold Ctrl)"
  aimBtn.BackgroundColor3=ON_COLOR
 else
  aimBtn.Text="AIM: OFF"
  aimBtn.BackgroundColor3=OFF_COLOR
 end
end

aimBtn.MouseButton1Click:Connect(function()
 aimEnabled=not aimEnabled
 settings.aim=aimEnabled
 saveSettings()
 refreshAim()
end)

local function refreshStuck()
 if antiStuckEnabled then
  stuckBtn.Text="Антизастревание: ВКЛ"
  stuckBtn.BackgroundColor3=ON_COLOR
 else
  stuckBtn.Text="Антизастревание: ВЫКЛ"
  stuckBtn.BackgroundColor3=OFF_COLOR
 end
end

stuckBtn.MouseButton1Click:Connect(function()
 antiStuckEnabled=not antiStuckEnabled
 settings.antiStuck=antiStuckEnabled
 saveSettings()
 refreshStuck()

 if not antiStuckEnabled then
  endAuto()
 end
end)

startBtn.MouseButton1Click:Connect(function()
 if on then return end
 startFarm()
end)

refreshSpeed()
refreshHeight()
refreshDist()
refreshNoclip()
refreshAim()
refreshStuck()

startFarm()
]==]

local BOOT_TEMPLATE = [====[
local SCRIPT=%s
local BOOT_TEMPLATE=%s

local env=(getgenv and getgenv()) or _G

if env.AutoFarmVersion then
 if env.AutoFarmVersion>2 then return end
 if env.AutoFarmVersion==2 and env.AutoFarmJob==game.JobId then return end
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
