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

local function startFarm()
 if on then return end
 on=true
 status.Text="AUTO FARM ON"

 task.spawn(function()
  press(Enum.KeyCode.Two)
  task.wait(.3)
  local c=me.


Character
  secondTool=c and c:FindFirstChildOfClass("Tool")
 end)

 task.spawn(startDungeon)

 follow=R.Heartbeat:Connect(function()
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
   r.CFrame=CFrame.lookAt(
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
   if target and target.Parent then
    attack()
   end
   task.wait(1)
  end
 end)

 task.spawn(retryLoop)
end

stop.MouseButton1Click:Connect(function()
 on=false
 target=nil
 secondTool=nil
 retryBusy=false
 status.Text="AUTO FARM OFF"
 if follow then
  follow:Disconnect()
  follow=nil
 end
end)

-- Автоматический запуск при выполнении скрипта
startFarm()



1 сообщение

