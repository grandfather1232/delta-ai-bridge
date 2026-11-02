local SCRIPT = [==[
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

-- Защита от дублей
local env=(getgenv and getgenv()) or _G

pcall(function()
if env.AutoFarmStop then env.AutoFarmStop() end
end)

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
local characterVersion=0
local lostAt=0

-- ====== GUI ======
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

-- ====== ФУНКЦИИ ======
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

-- Плавная телепортация к позиции
local function smoothTeleport(root, targetPos, speed)
if not root or not targetPos then return end

local startPos = root.Position
local distance = (targetPos - startPos).Magnitude
local steps = math.max(1, math.floor(distance / 5))

for i = 1, steps do
if not on then break end

local alpha = i / steps
local newPos = startPos:Lerp(targetPos, alpha)

root.CFrame = CFrame.new(newPos)
root.AssemblyLinearVelocity = Vector3.zero

task.wait(0.02)
end

root.CFrame = CFrame.new(targetPos)
root.AssemblyLinearVelocity = Vector3.zero
end

-- Плавная телепортация к цели с поворотом
local function smoothTeleportToTarget(root, targetPart)
if not root or not targetPart then return end

local targetPos = targetPart.Position - Vector3.new(0, 8, 0)
local lookPos = targetPart.Position

smoothTeleport(root, targetPos, 50)

if on then
root.CFrame = CFrame.lookAt(root.Position, lookPos)
root.AssemblyLinearVelocity = Vector3.zero
end
end

local function aimXY()
local cam=workspace.CurrentCamera
local t=target and target:FindFirstChild("HumanoidRootPart")

if cam and t then
local p=cam:WorldToScreenPoint(t.Position)
return p.X,p.Y
end

local s=cam and cam.ViewportSize
if s then return s.X/2,s.Y/2 end
return 0,0
end

local function selectSecondSlot(version)
if slotBusy or not on then return end
slotBusy=true
task.wait(1.5)

if on and version==characterVersion then
status.Text="SELECTING SLOT 2"
press(Enum.KeyCode.Two)
task.wait(.5)
end

slotBusy=false
if on then status.Text="AUTO FARM ON" end
end

local function nearest(r)
local folder=workspace:FindFirstChild("Mobs")
if not folder then return nil end

local best=nil
local distance=math.huge

for _,n in ipairs(folder:GetChildren()) do
if n:IsA("Model") and n~=me.Character then
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

local function attackSkills()
-- Стартовая задержка, чтобы не совпало с ЛКМ
task.wait(0.5)

-- F (первая)
press(Enum.KeyCode.F)
task.wait(0.6)

-- F (вторая)
press(Enum.KeyCode.F)
task.wait(0.6)

-- C
press(Enum.KeyCode.C)
task.wait(0.6)

-- V
press(Enum.KeyCode.V)
task.wait(0.8)
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

local connStarted=startedEvent.OnClientEvent:Connect(function()
startedCount=startedCount+1
keyDone=false
doorDone=false
target=nil
lostAt=0
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

smoothTeleport(root, key.part.Position + Vector3.new(0, 2, 0), 50)
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

smoothTeleport(root, door.part.Position + Vector3.new(0, 0, -1), 50)
root.AssemblyLinearVelocity=Vector3.zero

task.wait(3)

if on then
status.Text="UNLOCKING DOOR "..i

for attempt=1,3 do
if not on then break end
holdE(1.5)
task.wait(1)
end
end

task.wait(2)
end

if on then
doorDone=true
status.Text="SELECTING SLOT 2"

press(Enum.KeyCode.Two)
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

local function startFarm()
if on then return end
on=true

task.spawn(function()
selectSecondSlot(characterVersion)
end)

task.spawn(startDungeon)

follow=R.Heartbeat:Connect(function()
if not on or interacting then return end

local c=me.Character
local root=c and c:FindFirstChild("HumanoidRootPart")
if not root then return end

local folder=workspace:FindFirstChild("Mobs")
local h=target and target:FindFirstChildOfClass("Humanoid")
local t=target and target:FindFirstChild("HumanoidRootPart")

local inFolder=folder and target
and target:IsA("Model")
and target:IsDescendantOf(folder)
local dead=h and h.Health<=0

if inFolder and not dead and (not h or not t) then
if lostAt==0 then lostAt=os.clock() end
if os.clock()-lostAt<0.5 then return end
else
lostAt=0
end

if not inFolder or dead or not h or not t then
target=nearest(root)
t=target and target:FindFirstChild("HumanoidRootPart")
lostAt=0
end

if t then
smoothTeleportToTarget(root, t)
end
end)

-- ЛКМ: отдельный цикл
task.spawn(function()
while on do
local folder=workspace:FindFirstChild("Mobs")

if not interacting and target and folder
and target:IsDescendantOf(folder) then

local x,y=aimXY()  
V:SendMouseButtonEvent(x,y,0,true,game,0)  
task.wait(0.4)          -- удержание ЛКМ
x,y=aimXY()  
V:SendMouseButtonEvent(x,y,0,false,game,0)
task.wait(0.4)          -- пауза после отпускания

end

task.wait(0.2)          -- доп. пауза
end

local x,y=aimXY()
V:SendMouseButtonEvent(x,y,0,false,game,0)
end)

-- Камера
pcall(function() R:UnbindFromRenderStep("AutoFarmAim") end)
R:BindToRenderStep("AutoFarmAim",Enum.RenderPriority.Camera.Value+1,function()
if not on or interacting then return end

local cam=workspace.CurrentCamera
local t=target and target:FindFirstChild("HumanoidRootPart")

if cam and t then
cam.CFrame=CFrame.lookAt(cam.CFrame.Position,t.Position)
end
end)

-- Курсор
task.spawn(function()
while on do
if not interacting and target then
local x,y=aimXY()
V:SendMouseMoveEvent(x,y,game)
end

task.wait(.05)
end
end)

-- Способности: отдельный цикл со сдвигом
task.spawn(function()
while on do
local folder=workspace:FindFirstChild("Mobs")

if not interacting and target and folder
and target:IsDescendantOf(folder) then
attackSkills()
end

task.wait(1.5)          -- пауза между циклами способностей
end
end)

task.spawn(retryLoop)
task.spawn(keyDoorLoop)
end

local connChar=me.CharacterAdded:Connect(function()
characterVersion=characterVersion+1
target=nil
lostAt=0

if on then
task.spawn(function()
selectSecondSlot(characterVersion)
end)
end
end)

local function stopFarm()
on=false
interacting=false
target=nil
retryBusy=false
keyDone=false
doorDone=false
lostAt=0

if follow then
follow:Disconnect()
follow=nil
end

if connStarted then
connStarted:Disconnect()
connStarted=nil
end

if connChar then
connChar:Disconnect()
connChar=nil
end

pcall(function() R:UnbindFromRenderStep("AutoFarmAim") end)

pcall(function()
local sx,sy=aimXY()
V:SendMouseButtonEvent(sx,sy,0,false,game,0)
V:SendKeyEvent(false,Enum.KeyCode.Two,false,game)
V:SendKeyEvent(false,Enum.KeyCode.E,false,game)
end)

status.Text="AUTO FARM OFF"
end

stop.MouseButton1Click:Connect(stopFarm)

env.AutoFarmStop=stopFarm

startFarm()
]==]

local BOOT_TEMPLATE = [====[
local SCRIPT=%s
local BOOT_TEMPLATE=%s

local queueFn=queue_on_teleport or (syn and syn.queue_on_teleport)
local env=(getgenv and getgenv()) or _G

if queueFn and env.AutoFarmQueuedJob~=game.JobId then
env.AutoFarmQueuedJob=game.JobId

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
