local SCRIPT = [==[
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
local TP_COOLDOWN=.5      -- минимум секунд между телепортами
local REPOSITION_DIST=6   -- телепорт снова, только если ушли дальше от точки (studs)
local TARGET_TIMEOUT=25   -- если моб не умирает столько секунд, берём другого (0 = выключено)

local tpTarget=nil
local lastTP=0
local lostAt=0
local targetSince=0

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
g.Parent=Core

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(165,125)
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

local stop=Instance.new("TextButton",f)
stop.Size=UDim2.new(1,-10,0,35)
stop.Position=UDim2.fromOffset(5,65)
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

-- Способности по очереди: пауза 0.4 перед каждой клавишей
local function attackSkills()
 local keys={
  Enum.KeyCode.F,
  Enum.KeyCode.F,
  Enum.KeyCode.C,
  Enum.KeyCode.V
 }

 for _,k in ipairs(keys) do
  if not on then return end
  task.wait(.4)
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

local function retryLoop()
 while on do
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

local function keyDoorLoop()
 while on do
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

local tpCount=0

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
  -- цель мертва или исчезла: следующую берём сразу
  lostAt=0
  target=nearest(root)
  t=mobRoot(target)
 end

 if target~=prev then
  targetSince=os.clock()
 end

 if not t then
  dbg.Text="NO TARGET"
  return
 end

 -- телепорт под моба (8 studs ниже, лицом к нему) только когда нужно:
 -- новая цель или моб ушёл дальше REPOSITION_DIST от нашей точки
 local desired=t.Position-Vector3.new(0,8,0)
 local dist=(root.Position-desired).Magnitude
 local needs=(target~=tpTarget) or dist>REPOSITION_DIST

 if needs and os.clock()-lastTP>=TP_COOLDOWN then
  root.CFrame=CFrame.lookAt(desired,t.Position)
  root.AssemblyLinearVelocity=Vector3.zero
  tpTarget=target
  lastTP=os.clock()
  tpCount=tpCount+1
 end

 pcall(ensureHold,root)

 dbg.Text=target.Name.." d="..math.floor(dist).." tp="..tpCount
end

local function startFarm()
 if on then return end
 on=true

 -- Следит, чтобы второй слот был в руках всегда (в том числе после смерти)
 task.spawn(function()
  while on do
   if not interacting then
    ensureSlot2()
   end

   task.wait(1)
  end
 end)

 task.spawn(startDungeon)

 follow=R.Heartbeat:Connect(function()
  if not on or interacting then return end

  -- проверка раз в 0.2 сек, а не каждый кадр
  if os.clock()-lastPick<.2 then return end
  lastPick=os.clock()

  local ok,err=pcall(farmStep)
  if not ok then
   dbg.Text="ERR: "..tostring(err)
  end
 end)

 -- Быстрые клики левой кнопкой в отдельном цикле
 task.spawn(function()
  while on do
   local folder=workspace:FindFirstChild("Mobs")

   if not interacting and target and folder
   and target:IsDescendantOf(folder) then

    local x,y=mouseXY()
    V:SendMouseButtonEvent(x,y,0,true,game,0)
    task.wait(.1)
    x,y=mouseXY()
    V:SendMouseButtonEvent(x,y,0,false,game,0)
   end

   task.wait(.1)
  end

  local x,y=mouseXY()
  V:SendMouseButtonEvent(x,y,0,false,game,0)
 end)

 -- Способности отдельно от кликов мыши
 task.spawn(function()
  while on do
   local folder=workspace:FindFirstChild("Mobs")

   if not interacting and target and folder
   and target:IsDescendantOf(folder) then
    attackSkills()
   end

   task.wait(1)
  end
 end)

 task.spawn(retryLoop)
 task.spawn(keyDoorLoop)
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
 releaseHold()

 if follow then
  follow:Disconnect()
  follow=nil
 end
end)

startFarm()
]==]

local BOOT_TEMPLATE = [====[
local SCRIPT=%s
local BOOT_TEMPLATE=%s

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

local run=loadstring(SCRIPT)
if run then
 run()
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
