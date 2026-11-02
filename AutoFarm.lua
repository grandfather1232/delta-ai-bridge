local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local RS=game:GetService("ReplicatedStorage")
local Core=game:GetService("CoreGui")
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
local target
local secondTool
local switching=false
local follow
local retryBusy=false
local startedCount=0

local interacting=false
local keyDone=false
local doorDone=false
local interactionToken=0

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

local function getRoot()
 local c=me.Character
 return c and c:FindFirstChild("HumanoidRootPart")
end

local function nearest(r)
 local best,d
 for _,n in ipairs(workspace:GetDescendants()) do
  if n:IsA("Model") and n~=me.Character
  and not P:GetPlayerFromCharacter(n) then
   local h=n:FindFirstChildOfClass("Humanoid")
   local t=n:FindFirstChild("HumanoidRootPart")
   if h and t and h.Health>0 then
    local x=(r.Position-t.Position).Magnitude
    if not d or x<d then best,d=n,x end
   end
  end
 end
 return best
end

local function attack()
 local t=target and target:FindFirstChild("HumanoidRootPart")
 if t then
  local cam=workspace.CurrentCamera
  if cam then
   cam.CFrame=CFrame.lookAt(cam.CFrame.Position,t.Position)
  end
 end

 V:SendMouseButtonEvent(0,0,0,true,game,0)
 task.wait(.1)
 V:SendMouseButtonEvent(0,0,0,false,game,0)
 press(Enum.KeyCode.F)
 press(Enum.KeyCode.C)
 press(Enum.KeyCode.V)
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
 interactionToken=interactionToken+1
 target=nil
end)

local function startDungeon()
 status.Text="STARTING DUNGEON"
 local ok=pcall(function()
  return startRemote:InvokeServer()
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
    return voteRemote:InvokeServer("Retry")
   end)

   if ok then
    status.Text="WAITING..."
    local elapsed=0
    while on and elapsed<10 do
     if startedCount>before then break end
     task.wait(.5)
     elapsed=


elapsed+.5
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

-- Поиск ключей: используем второй найденный объект,
-- как в проверенном тесте пользователя.
local function findWorkingKey()
 local keys={}

 for _,obj in ipairs(workspace:GetDescendants()) do
  if obj.Name:lower()=="key" then
   local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
   local part=obj:IsA("BasePart") and obj
    or obj:FindFirstChild("Handle",true)
    or obj:FindFirstChildWhichIsA("BasePart",true)

   if prompt and part and part:IsA("BasePart")
   and prompt.Enabled then
    table.insert(keys,{
     object=obj,
     prompt=prompt,
     part=part
    })
   end
  end
 end

 return keys[2]
end

-- Поиск замочной скважины
local function findKeyholes()
 local doors={}

 for _,obj in ipairs(workspace:GetDescendants()) do
  if obj.Name:lower()=="keyhole" then
   local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
   local part=obj:IsA("BasePart") and obj
    or obj:FindFirstChildWhichIsA("BasePart",true)

   if prompt and part and part:IsA("BasePart")
   and prompt.Enabled then
    table.insert(doors,{
     prompt=prompt,
     part=part
    })
   end
  end
 end

 return doors
end

local function collectKey()
 local key=findWorkingKey()
 if not key then return false end

 local root=getRoot()
 if not root then return false end

 interacting=true
 status.Text="GOING TO KEY"

 root.CFrame=key.part.CFrame*CFrame.new(0,2,0)
 task.wait(1)

 if not on then
  interacting=false
  return false
 end

 status.Text="PICKING KEY"
 press(Enum.KeyCode.E)
 task.wait(2)

 interacting=false
 return true
end

local function unlockDoors()
 local doors=findKeyholes()
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

 interacting=false
 return true
end

-- Автоматический подбор ключа и открытие двери
local function interactionLoop()
 local myToken=interactionToken

 while on and myToken==interactionToken do
  if not keyDone then
   local key=findWorkingKey()

   if key then
    local success=collectKey()
    if success and on then
     keyDone=true
    end
   end
  elseif not doorDone then
   local doors=findKeyholes()

   if #doors>0 then
    local success=unlockDoors()
    if success and on then
     doorDone=true
     status.Text="DOOR INTERACTED"
     task.wait(2)
     status.Text="AUTO FARM ON"
    end
   end
  end

  task.wait(1)
 end
end

local function startFarm()
 if on then return end
 on=true
 status.Text="AUTO FARM ON"

 task.spawn(function()
  press(Enum.KeyCode.Two)
  task.wait(.3)
  local c=me.Character
  secondTool=c and c:FindFirstChildOfClass("Tool")
 end)

 task.spawn(startDungeon)

 follow=R.Heartbeat:Connect(function()
  if interacting then return end

  local c=me.Character
  local r=c and c:FindFirstChild("HumanoidRootPart")
  if not r then return end

  local h=target and target:FindFirstChildOfClass("Humanoid")
  local t=target and target:FindFirstChild("HumanoidRootPart")
  if not h or not t or h.Health<=0 then
   target=nearest(r)
   t=target and target:FindFirstChild("HumanoidRootPart")
  end

  if t then
   r.CFrame=CFrame
Orville's Ideas and Interests
obj.Name


.lookAt(
    t.Position-Vector3.new(0,8,0),t.Position
   )
   r.AssemblyLinearVelocity=Vector3.zero
  end
 end)

 task.spawn(function()
  while on do
   local c=me.Character
   local equipped=c and c:FindFirstChildOfClass("Tool")
   if secondTool and equipped~=secondTool and not switching then
    switching=true
    press(Enum.KeyCode.Two)
    task.wait(.4)
    switching=false
   end
   task.wait(.5)
  end
 end)

 task.spawn(function()
  while on do
   if not interacting and target and target.Parent then
    attack()
   end
   task.wait(1)
  end
 end)

 task.spawn(retryLoop)
 task.spawn(interactionLoop)
end

stop.MouseButton1Click:Connect(function()
 on=false
 interacting=false
 target=nil
 secondTool=nil
 retryBusy=false
 keyDone=false
 doorDone=false
 interactionToken=interactionToken+1
 status.Text="AUTO FARM OFF"

 if follow then
  follow:Disconnect()
  follow=nil
 end
end)

startFarm()



