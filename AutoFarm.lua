local SCRIPT = [==[
local VERSION=5
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
 dist=0,          -- расстояние от моба (плюс = впереди, минус = сзади)
 slot=2,          -- какой слот держать в руках (1-9)
 tp=false,        -- false = ходьба к мобу, true = мгновенный телепорт
 remote=true,     -- ключи и двери берём без телепорта (запасной способ: с телепортом)
 buff=true,       -- авто-выбор баффов после зачистки
 buffPick=4,      -- какой вариант брать: 1, 2, 3 или 4 = случайный
 buffGui=""       -- имя окна баффов (запоминается после первого успешного выбора)
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

 settings.speed=math.clamp(settings.speed,5,1000)
 settings.height=math.clamp(settings.height,-50,50)
 settings.dist=math.clamp(settings.dist,-50,50)
 settings.slot=math.floor(math.clamp(settings.slot,1,9))
 settings.buffPick=math.floor(math.clamp(settings.buffPick,1,4))
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

-- После перехода на другой сервер скрипт запускается очень рано:
-- ждём, пока игра полностью загрузится (иначе окна и объекты ещё не созданы)
if not game:IsLoaded() then
 game.Loaded:Wait()
end

local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local RS=game:GetService("ReplicatedStorage")
local Core=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local me=P.LocalPlayer
local pg=me:WaitForChild("PlayerGui")

-- PlayerGui могли пересоздать после загрузки: берём актуальный
local function refreshPg()
 local current=me:FindFirstChildOfClass("PlayerGui")

 if current then
  pg=current
 end
end

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
local slotName=nil
local slotIndex=settings.slot

local SLOT_KEYS={
 Enum.KeyCode.One,
 Enum.KeyCode.Two,
 Enum.KeyCode.Three,
 Enum.KeyCode.Four,
 Enum.KeyCode.Five,
 Enum.KeyCode.Six,
 Enum.KeyCode.Seven,
 Enum.KeyCode.Eight,
 Enum.KeyCode.Nine
}
local characterVersion=0
local lastPick=0

-- Настройки телепорта к мобу
local noclipEnabled=settings.noclip -- ручной noclip, кнопка в меню
local aimEnabled=settings.aim       -- авто-наведение, кнопка в меню
local antiStuckEnabled=settings.antiStuck -- антизастревание, кнопка в меню
local teleportMode=settings.tp    -- false = ходьба, true = телепорт, кнопка в меню
local remotePick=settings.remote  -- подбор ключей и дверей без телепорта, кнопка в меню
local buffEnabled=settings.buff   -- авто-выбор баффов, кнопка в меню
local buffPick=settings.buffPick  -- 1, 2, 3 или 4 (случайный)
local knownBuffGui=settings.buffGui -- имя окна баффов, запомненное раньше
local remoteFails=0               -- сколько раз подряд не сработал подбор на расстоянии
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
f.Size=UDim2.fromOffset(165,320)
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
stop.Position=UDim2.fromOffset(85,280)
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

-- Прокручиваемая область с настройками (меню не вылезает за экран)
local body=Instance.new("ScrollingFrame",f)
body.Position=UDim2.fromOffset(0,65)
body.Size=UDim2.new(1,0,0,210)
body.BackgroundTransparency=1
body.BorderSizePixel=0
body.ScrollBarThickness=4
body.CanvasSize=UDim2.new(0,0,0,362)

-- Строка "минус / значение / плюс"
local function makeRow(y)
 local minus=Instance.new("TextButton",body)
 minus.Size=UDim2.fromOffset(35,26)
 minus.Position=UDim2.fromOffset(5,y)
 minus.Text="-"
 minus.TextColor3=Color3.new(1,1,1)
 minus.BackgroundColor3=Color3.fromRGB(60,60,80)

 local label=Instance.new("TextLabel",body)
 label.Size=UDim2.fromOffset(75,26)
 label.Position=UDim2.fromOffset(45,y)
 label.TextColor3=Color3.new(1,1,1)
 label.BackgroundTransparency=1
 label.TextSize=12

 local plus=Instance.new("TextButton",body)
 plus.Size=UDim2.fromOffset(35,26)
 plus.Position=UDim2.fromOffset(125,y)
 plus.Text="+"
 plus.TextColor3=Color3.new(1,1,1)
 plus.BackgroundColor3=Color3.fromRGB(60,60,80)

 return minus,label,plus
end

-- Кнопка-переключатель на всю ширину
local function makeToggle(y)
 local button=Instance.new("TextButton",body)
 button.Size=UDim2.new(1,-10,0,26)
 button.Position=UDim2.fromOffset(5,y)
 button.TextSize=11
 button.TextColor3=Color3.new(1,1,1)
 return button
end

local speedMinus,speedLabel,speedPlus=makeRow(0)
local heightMinus,heightLabel,heightPlus=makeRow(30)
local distMinus,distLabel,distPlus=makeRow(60)
local noclipBtn=makeToggle(90)
local aimBtn=makeToggle(120)
local stuckBtn=makeToggle(150)
local slotMinus,slotLabel,slotPlus=makeRow(180)
local modeBtn=makeToggle(210)
local pickBtn=makeToggle(240)
local buffBtn=makeToggle(270)
local buffMinus,buffLabel,buffPlus=makeRow(300)
local scanBtn=makeToggle(330)

local startBtn=Instance.new("TextButton",f)
startBtn.Size=UDim2.fromOffset(75,32)
startBtn.Position=UDim2.fromOffset(5,280)
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

-- Подсказка исчезла/выключилась: ключ взят или дверь открыта
local function promptGone(entry)
 return not entry.prompt.Parent
  or not entry.prompt.Enabled
  or not entry.part.Parent
end

-- Нажимаем E, пока не пройдёт duration или пока подсказка не исчезнет
local function repeatE(duration,entry)
 local elapsed=0

 while on and elapsed<duration do
  press(Enum.KeyCode.E)
  task.wait(.3)
  elapsed=elapsed+.42

  if entry and promptGone(entry) then break end
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

local function ensureSlot()
 if slotBusy or not on then return end

 local c=me.Character
 local hum=c and c:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end

 -- нужный слот уже в руках: ничего не нажимаем (клавиша слота переключает)
 local tool=equippedTool()
 if slotName and tool and tool.Name==slotName then return end

 slotBusy=true
 local index=slotIndex
 status.Text="SELECTING SLOT "..index

 -- если в руках что-то другое/неизвестное, сначала убираем, чтобы клавиша не сняла слот
 if tool then
  hum:UnequipTools()
  task.wait(.4)
 end

 if on then
  press(SLOT_KEYS[index])
  local equipped=waitTool(1.5)

  -- имя предмета запоминаем, только если слот не меняли по ходу
  if equipped and not slotName and index==slotIndex then
   slotName=equipped.Name
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

 -- слот 1 в руках: дополнительная атака на R
 if slotIndex==1 and equippedTool() then
  table.insert(keys,Enum.KeyCode.R)
 end

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
  refreshPg()

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

-- Использовать ProximityPrompt прямо на расстоянии, без телепорта и без нажатия E.
-- Возвращает true, если после нажатия подсказка исчезла/выключилась (ключ взят,
-- дверь открыта). Если не вышло, вызывающий код использует старый способ с телепортом.
local function remoteUse(entry,interval)
 if not remotePick or not fireproximityprompt then return false end

 -- два раза подряд не вышло: на расстоянии не работает, не тратим время
 if remoteFails>=2 then return false end

 local prompt=entry.prompt
 interval=interval or .5

 for attempt=1,2 do
  if not on then return false end

  pcall(function()
   prompt.HoldDuration=0
   fireproximityprompt(prompt)
  end)

  task.wait(interval)

  if promptGone(entry) then
   remoteFails=0
   return true
  end
 end

 remoteFails=remoteFails+1
 return false
end

local function collectKey()
 local key=findKey()
 if not key then return false end

 -- без телепорта: берём ключ прямо на расстоянии
 if remotePick then
  status.Text="PICKING KEY"

  if remoteUse(key,.4) then
   if on then status.Text="AUTO FARM ON" end
   return on
  end
 end

 -- запасной способ: телепорт к ключу и нажатия E
 local root=getRoot()
 if not root then return false end

 interacting=true
 status.Text="GOING TO KEY"

 root.CFrame=key.part.CFrame*CFrame.new(0,2,0)
 task.wait(.3)

 if on then
  status.Text="PICKING KEY"
  repeatE(5,key)
 end

 interacting=false
 return on
end

local function unlockDoors()
 local doors=findDoors()
 if #doors==0 then return false end

 for i,door in ipairs(doors) do
  if not on then break end

  -- без телепорта: открываем дверь прямо на расстоянии
  local opened=false

  if remotePick then
   status.Text="UNLOCKING DOOR "..i
   opened=remoteUse(door,.35)
  end

  -- запасной способ: телепорт к двери и удержание E
  if not opened then
   local root=getRoot()
   if not root then break end

   interacting=true

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

   task.wait(.5)

   if on then
    status.Text="UNLOCKING DOOR "..i

    for attempt=1,3 do
     if not on then break end
     holdE(1.5)
     task.wait(.2)

     if promptGone(door) then break end
    end
   end

   velocity:Destroy()
   attachment:Destroy()
   task.wait(.3)

   interacting=false
  end
 end

 if on then
  doorDone=true
  ensureSlot()
  task.wait(.2)
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
  end

  -- ключ взят: сразу открываем двери, не ждём следующего круга
  if keyDone and not doorDone then
   if #findDoors()>0 then
    unlockDoors()
   end
  end

  task.wait(.3)
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

 if dist<=ARRIVE_DIST or teleportMode then
  -- пришли, либо включён режим телепорта: сразу ставим на точку
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

-- Авто-выбор баффов/дебаффов после зачистки подземелья.
-- Окно ищем по признакам: видимое ScreenGui в PlayerGui, где есть слово-подсказка
-- (buff, choose, perk...) и не меньше 3 видимых кнопок. Выбор делаем клавишей 1-3,
-- а если окно не закрылось, нажимаем саму кнопку.
local BUFF_WORDS={
 "buff","debuff","boon","blessing","curse","perk","augment","modifier",
 "choose","select","upgrade",
 "баф","дебаф","улучш","выбер","благослов","проклят",
 "Баф","Дебаф","Улучш","Выбер","Благослов","Проклят"
}

local BUFF_IGNORE={
 Chat=true,
 BubbleChat=true,
 PlayerList=true,
 Backpack=true,
 TouchGui=true,
 ControlGui=true
}

-- Объект виден: все родители до PlayerGui включены
local function guiVisible(obj)
 local o=obj

 while o and o~=pg do
  if o:IsA("GuiObject") and not o.Visible then return false end
  if o:IsA("ScreenGui") and not o.Enabled then return false end
  o=o.Parent
 end

 return true
end

local function hasBuffWord(text)
 local lower=text:lower()

 for _,word in ipairs(BUFF_WORDS) do
  if lower:find(word,1,true) or text:find(word,1,true) then
   return true
  end
 end

 return false
end

-- Возвращает окно выбора и список его кнопок слева направо (или nil)
local function findBuffMenu()
 for _,gui in ipairs(pg:GetChildren()) do
  if gui:IsA("ScreenGui") and gui.Enabled and not BUFF_IGNORE[gui.Name] then
   local buttons={}
   local hit=false

   for _,obj in ipairs(gui:GetDescendants()) do
    if obj:IsA("GuiObject") and guiVisible(obj) then
     if obj:IsA("GuiButton") then
      table.insert(buttons,obj)
     end

     if not hit and (obj:IsA("TextLabel") or obj:IsA("TextButton"))
     and obj.Text~="" then
      hit=hasBuffWord(obj.Text)
     end
    end
   end

   if (hit or gui.Name==knownBuffGui) and #buttons>=3 then
    -- если есть ровно 3 кнопки с общим родителем, берём их
    local groups={}

    for _,button in ipairs(buttons) do
     groups[button.Parent]=groups[button.Parent] or {}
     table.insert(groups[button.Parent],button)
    end

    local chosen=nil

    for _,list in pairs(groups) do
     if #list==3 then
      chosen=list
      break
     end
    end

    chosen=chosen or buttons

    table.sort(chosen,function(a,b)
     if math.abs(a.AbsolutePosition.X-b.AbsolutePosition.X)>2 then
      return a.AbsolutePosition.X<b.AbsolutePosition.X
     end

     return a.AbsolutePosition.Y<b.AbsolutePosition.Y
    end)

    return gui,chosen
   end
  end
 end

 return nil
end

local function clickButton(button)
 if firesignal then
  pcall(function() firesignal(button.MouseButton1Click) end)
  pcall(function() firesignal(button.Activated) end)
  return
 end

 local screen=button:FindFirstAncestorOfClass("ScreenGui")
 local inset=Vector2.zero

 if screen and not screen.IgnoreGuiInset then
  inset=GuiService:GetGuiInset()
 end

 local pos=button.AbsolutePosition+button.AbsoluteSize/2+inset

 V:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
 task.wait(.08)
 V:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
end

-- "Подпись" окна: имя + тексты первых трёх вариантов. Новое меню с другими
-- вариантами получает другую подпись, даже если окно то же самое.
local function buffSignature(gui,buttons)
 local parts={gui.Name,tostring(#buttons)}

 for i=1,math.min(#buttons,3) do
  local button=buttons[i]
  local text=""

  if button:IsA("TextButton") then
   text=button.Text
  end

  for _,obj in ipairs(button:GetDescendants()) do
   if obj:IsA("TextLabel") and obj.Text~="" then
    text=text..obj.Text
   end
  end

  table.insert(parts,string.sub(text,1,40))
 end

 return table.concat(parts,"|")
end

local lastBuffSig=nil
local lastBuffAt=0

local function handleBuff(gui,buttons)
 local choice=buffPick

 if choice>3 then
  choice=math.random(1,3)
 end

 -- на время выбора не даём ensureSlot() менять слот
 slotBusy=true
 status.Text="BUFF: "..choice

 local closed=false

 for attempt=1,3 do
  if not on then break end

  press(SLOT_KEYS[choice])
  task.wait(.8)

  local ok2,gui2=pcall(findBuffMenu)

  if not (ok2 and gui2) then
   closed=true
   break
  end

  if buttons and buttons[choice] then
   clickButton(buttons[choice])
   task.wait(.8)

   local ok3,gui3=pcall(findBuffMenu)

   if not (ok3 and gui3) then
    closed=true
    break
   end
  end
 end

 slotBusy=false
 if on then status.Text="AUTO FARM ON" end

 -- окно закрылось: запоминаем его имя, чтобы потом находить без слов-подсказок
 if closed and knownBuffGui~=gui.Name then
  knownBuffGui=gui.Name
  settings.buffGui=knownBuffGui
  saveSettings()
 end
end

local function buffLoop(myRun)
 while on and myRun==runId do
  refreshPg()

  if buffEnabled then
   local ok,gui,buttons=pcall(findBuffMenu)

   if not ok or not gui then
    lastBuffSig=nil
   else
    local okSig,sig=pcall(buffSignature,gui,buttons)

    if okSig and (sig~=lastBuffSig or os.clock()-lastBuffAt>8) then
     lastBuffSig=sig
     lastBuffAt=os.clock()

     -- ошибка внутри не должна убивать цикл и оставлять слот заблокированным
     local okH,err=pcall(handleBuff,gui,buttons)

     if not okH then
      slotBusy=false
      dbg.Text="BUFF ERR: "..tostring(err)
     end
    end
   end
  end

  task.wait(.5)
 end
end

-- Отладка: список окон PlayerGui (имя, кнопки, тексты), чтобы подогнать поиск
local function scanGuis()
 local lines={}

 for _,gui in ipairs(pg:GetChildren()) do
  if gui:IsA("ScreenGui") then
   local count=0
   local texts={}

   for _,obj in ipairs(gui:GetDescendants()) do
    if obj:IsA("GuiObject") and guiVisible(obj) then
     if obj:IsA("GuiButton") then
      count=count+1
     end

     if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
     and obj.Text~="" and #texts<6 then
      table.insert(texts,string.sub(obj.Text,1,24))
     end
    end
   end

   table.insert(lines,
    gui.Name.." | on="..tostring(gui.Enabled)
    .." | buttons="..count
    .." | "..table.concat(texts," / "))
  end
 end

 return table.concat(lines,"\n")
end

local function showReport(text)
 pcall(function()
  local old=Core:FindFirstChild("AutoFarmScan")
  if old then old:Destroy() end
 end)

 warn(text)

 local gui=Instance.new("ScreenGui")
 gui.Name="AutoFarmScan"
 gui.ResetOnSpawn=false
 gui.Parent=Core

 local frame=Instance.new("Frame",gui)
 frame.Size=UDim2.fromOffset(340,240)
 frame.Position=UDim2.new(.5,-170,.5,-120)
 frame.BackgroundColor3=Color3.fromRGB(35,35,45)

 local box=Instance.new("TextBox",frame)
 box.Size=UDim2.new(1,-10,1,-45)
 box.Position=UDim2.fromOffset(5,5)
 box.MultiLine=true
 box.TextWrapped=true
 box.ClearTextOnFocus=false
 box.TextXAlignment=Enum.TextXAlignment.Left
 box.TextYAlignment=Enum.TextYAlignment.Top
 box.TextSize=11
 box.TextColor3=Color3.new(1,1,1)
 box.BackgroundColor3=Color3.fromRGB(20,20,28)
 box.Text=text

 local close=Instance.new("TextButton",frame)
 close.Size=UDim2.new(1,-10,0,30)
 close.Position=UDim2.new(0,5,1,-35)
 close.Text="ЗАКРЫТЬ"
 close.TextColor3=Color3.new(1,1,1)
 close.BackgroundColor3=Color3.fromRGB(160,40,40)

 close.MouseButton1Click:Connect(function()
  gui:Destroy()
 end)
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
    ensureSlot()
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
 task.spawn(buffLoop,myRun)
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
    ensureSlot()
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
 V:SendKeyEvent(false,SLOT_KEYS[slotIndex],false,game)
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

-- Шаг скорости растёт вместе со значением: 5 до 100, 25 до 300, дальше 50
local function nextSpeed(value,dir)
 local step=5

 if (dir>0 and value>=100) or (dir<0 and value>100) then
  step=25
 end

 if (dir>0 and value>=300) or (dir<0 and value>300) then
  step=50
 end

 return math.clamp(value+dir*step,5,1000)
end

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
 MOVE_SPEED=nextSpeed(MOVE_SPEED,-1)
 settings.speed=MOVE_SPEED
 saveSettings()
 refreshSpeed()
end)

speedPlus.MouseButton1Click:Connect(function()
 MOVE_SPEED=nextSpeed(MOVE_SPEED,1)
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

local function refreshSlot()
 slotLabel.Text="SLOT: "..slotIndex
end

local function changeSlot(value)
 slotIndex=math.clamp(value,1,9)
 settings.slot=slotIndex
 saveSettings()
 refreshSlot()

 -- новый слот: имя предмета узнаём заново, тут же берём его в руки
 slotName=nil
end

slotMinus.MouseButton1Click:Connect(function()
 changeSlot(slotIndex-1)
end)

slotPlus.MouseButton1Click:Connect(function()
 changeSlot(slotIndex+1)
end)

local function refreshMode()
 if teleportMode then
  modeBtn.Text="РЕЖИМ: ТЕЛЕПОРТ"
  modeBtn.BackgroundColor3=Color3.fromRGB(190,110,30)
 else
  modeBtn.Text="РЕЖИМ: ХОДЬБА"
  modeBtn.BackgroundColor3=Color3.fromRGB(60,60,80)
 end
end

modeBtn.MouseButton1Click:Connect(function()
 teleportMode=not teleportMode
 settings.tp=teleportMode
 saveSettings()
 refreshMode()
end)

local function refreshPick()
 if remotePick then
  pickBtn.Text="ПОДБОР: БЕЗ ТЕЛЕПОРТА"
  pickBtn.BackgroundColor3=ON_COLOR
 else
  pickBtn.Text="ПОДБОР: С ТЕЛЕПОРТОМ"
  pickBtn.BackgroundColor3=OFF_COLOR
 end
end

pickBtn.MouseButton1Click:Connect(function()
 remotePick=not remotePick
 remoteFails=0
 settings.remote=remotePick
 saveSettings()
 refreshPick()
end)

local function refreshBuff()
 if buffEnabled then
  buffBtn.Text="АВТО-БАФФ: ВКЛ"
  buffBtn.BackgroundColor3=ON_COLOR
 else
  buffBtn.Text="АВТО-БАФФ: ВЫКЛ"
  buffBtn.BackgroundColor3=OFF_COLOR
 end
end

buffBtn.MouseButton1Click:Connect(function()
 buffEnabled=not buffEnabled
 settings.buff=buffEnabled
 saveSettings()
 refreshBuff()
end)

local function refreshBuffPick()
 buffLabel.Text="БАФФ: "..(buffPick>3 and "RND" or buffPick)
end

local function changeBuffPick(value)
 buffPick=math.clamp(value,1,4)
 settings.buffPick=buffPick
 saveSettings()
 refreshBuffPick()
end

buffMinus.MouseButton1Click:Connect(function()
 changeBuffPick(buffPick-1)
end)

buffPlus.MouseButton1Click:Connect(function()
 changeBuffPick(buffPick+1)
end)

scanBtn.Text="СКАН ОКОН (отладка)"
scanBtn.BackgroundColor3=Color3.fromRGB(60,60,80)

scanBtn.MouseButton1Click:Connect(function()
 local ok,report=pcall(scanGuis)
 showReport(ok and report or ("ERR: "..tostring(report)))
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
refreshSlot()
refreshMode()
refreshPick()
refreshBuff()
refreshBuffPick()

startFarm()
]==]

local BOOT_TEMPLATE = [====[
local SCRIPT=%s
local BOOT_TEMPLATE=%s

local env=(getgenv and getgenv()) or _G

if env.AutoFarmVersion then
 if env.AutoFarmVersion>5 then return end
 if env.AutoFarmVersion==5 and env.AutoFarmJob==game.JobId then return end
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
