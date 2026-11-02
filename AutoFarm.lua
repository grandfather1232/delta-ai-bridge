local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local RS=game:GetService("ReplicatedStorage")
local Core=game:GetService("CoreGui")
local me=P.LocalPlayer
local pg=me:WaitForChild("PlayerGui")

local services=RS.ReplicatedStorage.Packages.Knit.Services
local startRemote=services.DungeonService.RF.StartDungeon

local partyService=services:FindFirstChild("PartyService")
local partyRF=partyService and partyService:FindFirstChild("RF")
local voteRemote=partyRF and partyRF:FindFirstChild("VoteOn")
-- ИЗМЕНЁН ТОЛЬКО ПОИСК ЦЕЛИ:
-- Ищет живых мобов исключительно в Workspace.Mobs

local function nearest(r)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder or not r then return nil end

 local best=nil
 local distance=math.huge

 for _,n in ipairs(folder:GetDescendants()) do
  if n:IsA("Model") and n~=me.Character then
   local h=n:FindFirstChildOfClass("Humanoid")
   local t=n:FindFirstChild("HumanoidRootPart")

   if h and t and h.Health>0 then
    local d=(r.Position-t.Position).Magnitude

    if d<distance then
   local ok=false

   if voteRemote and voteRemote:IsA("RemoteFunction") then
    ok=pcall(function()
     voteRemote:InvokeServer("Retry")
    end)
   end

   if ok then
    local elapsed=0

    while on and elapsed<10 do
     if startedCount>before then break end
     task.wait(.5)
     elapsed=elapsed+.5
    end

    if on and startedCount==before then
     startDungeon()
    end
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
  press(Enum.KeyCode.E)
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
  status.Text="HOLDING 2"

  V:SendKeyEvent(true,Enum.KeyCode.Two,false,game)
  task.wait(3)
  V:SendKeyEvent(false,Enum.KeyCode.Two,false,game)
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

  local h=target and target:FindFirstChildOfClass("Humanoid")
  local t=target and target:FindFirstChild("HumanoidRootPart")

  if not h or not t or h.Health<=0
  or not target:IsDescendantOf(workspace:FindFirstChild("Mobs") or workspace) then
   target=nearest(root)
   t=target and target:FindFirstChild("HumanoidRootPart")
  end

  if t then
   root.CFrame=CFrame.lookAt(
    t.Position-Vector3.new(0,8,0),t.Position
   )
   root.AssemblyLinearVelocity=Vector3.zero
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
 task.spawn(keyDoorLoop)
end

me.CharacterAdded:Connect(function()
 characterVersion=characterVersion+1
 target=nil

 if on then
  task.spawn(function()
   selectSecondSlot(characterVersion)
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

 V:SendKeyEvent(false,Enum.KeyCode.Two,false,game)
 V:SendKeyEvent(false,Enum.KeyCode.E,false,game)

 status.Text="AUTO FARM OFF"

 if follow then
  follow:Disconnect()
  follow=nil
 end
end)

startFarm()
