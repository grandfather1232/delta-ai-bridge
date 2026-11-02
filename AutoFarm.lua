local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local Core=game:GetService("CoreGui")

local me=P.LocalPlayer

pcall(function()
 local old=Core:FindFirstChild("AutoFarm")
 if old then old:Destroy() end
end)

local on=true
local target=nil
local interacting=false
local keyDone=false
local doorDone=false
local lastAttack=0

local g=Instance.new("ScreenGui")
g.Name="AutoFarm"
g.ResetOnSpawn=false
g.Parent=Core

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(190,90)
f.Position=UDim2.new(.5,-95,.5,0)
f.BackgroundColor3=Color3.fromRGB(35,35,45)
f.Active=true
f.Draggable=true

local label=Instance.new("TextLabel",f)
label.Size=UDim2.new(1,0,0,30)
label.BackgroundTransparency=1
label.Text="AUTO FARM: ON"
label.TextColor3=Color3.new(1,1,1)

local stop=Instance.new("TextButton",f)
stop.Size=UDim2.new(1,-10,0,40)
stop.Position=UDim2.fromOffset(5,40)
stop.Text="STOP"
stop.BackgroundColor3=Color3.fromRGB(160,40,40)
stop.TextColor3=Color3.new(1,1,1)

local function getRoot()
 local c=me.Character
 return c and c:FindFirstChild("HumanoidRootPart")
end

local function press(k)
 V:SendKeyEvent(true,k,false,game)
 task.wait(.12)
 V:SendKeyEvent(false,k,false,game)
end

-- ПОИСК МОБОВ ТОЛЬКО В WORKSPACE.MOBS

local function validMob(mob)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder or not mob or not mob:IsA("Model") then
  return false
 end

 if not mob:IsDescendantOf(folder) then
  return false
 end

 local h=mob:FindFirstChildOfClass("Humanoid")
 local t=mob:FindFirstChild("HumanoidRootPart")

 return h~=nil and t~=nil and h.Health>0
end

local function findNearest(root)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder then return nil end

 local best=nil
 local shortest=math.huge

 for _,mob in ipairs(folder:GetDescendants()) do
  if validMob(mob) then
   local t=mob:FindFirstChild("HumanoidRootPart")
   local d=(root.Position-t.Position).Magnitude

   if d<shortest then
    shortest=d
    best=mob
   end
  end
 end

 return best
end

-- АТАКА

local function attack()
 V:SendMouseButtonEvent(0,0,0,true,game,0)
 task.wait(.1)
 V:SendMouseButtonEvent(0,0,0,false,game,0)

 press(Enum.KeyCode.F)
 press(Enum.KeyCode.C)
 press(Enum.KeyCode.V)
end

-- ПОИСК КЛЮЧА

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

-- ПОИСК ДВЕРЕЙ

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

-- ПОДБОР КЛЮЧА

local function collectKey()
 local key=findKey()
 if not key then return false end

 local root=getRoot()
 if not root then return false end

 interacting=true
 label.Text="GOING TO KEY"

 root.CFrame=key.part.CFrame*CFrame.new(0,2,0)
 task.wait(1)

 if on then
  label.Text="PICKING KEY"
  press(Enum.KeyCode.E)
  task.wait(2)
 end

 interacting=false
 return on
end

-- ОТКРЫТИЕ ДВЕРЕЙ

local function unlockDoors()
 local doors=findDoors()
 if #doors==0 then return false end

 interacting=true

 for i,door in ipairs(doors) do
  if not on then break end

  local root=getRoot()
  if not root then break end

  label.Text="GOING TO DOOR "..i

  root.CFrame=door.part.CFrame*CFrame.new(0,0,-1)
  root.AssemblyLinearVelocity=Vect


or3.zero

  task.wait(3)

  if on then
   label.Text="UNLOCKING DOOR "..i

   for attempt=1,3 do
    if not on then break end

    V:SendKeyEvent(true,Enum.KeyCode.E,false,game)
    task.wait(1.5)
    V:SendKeyEvent(false,Enum.KeyCode.E,false,game)

    task.wait(1)
   end
  end

  task.wait(2)
 end

 if on then
  doorDone=true
 end

 interacting=false
 return on
end

-- ЦИКЛ КЛЮЧА И ДВЕРЕЙ

task.spawn(function()
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
end)

-- ТЕЛЕПОРТАЦИЯ К МОБАМ

local connection=R.Heartbeat:Connect(function()
 if not on or interacting then return end

 local root=getRoot()
 if not root then return end

 if not validMob(target) then
  target=findNearest(root)
 end

 if not validMob(target) then
  label.Text="NO MOBS FOUND"
  return
 end

 local enemyRoot=target:FindFirstChild("HumanoidRootPart")
 if not enemyRoot then return end

 label.Text="TARGET: "..target.Name

 root.CFrame=CFrame.lookAt(
  enemyRoot.Position-Vector3.new(0,8,0),
  enemyRoot.Position
 )

 root.AssemblyLinearVelocity=Vector3.zero
end)

-- АТАКА ПО ТАЙМЕРУ

task.spawn(function()
 while on do
  if not interacting and validMob(target) then
   if os.clock()-lastAttack>=1 then
    lastAttack=os.clock()
    attack()
   end
  end

  task.wait(.1)
 end
end)

-- STOP

stop.MouseButton1Click:Connect(function()
 on=false
 interacting=false
 target=nil

 if connection then
  connection:Disconnect()
 end

 V:SendMouseButtonEvent(0,0,0,false,game,0)
 V:SendKeyEvent(false,Enum.KeyCode.E,false,game)
 V:SendKeyEvent(false,Enum.KeyCode.F,false,game)
 V:SendKeyEvent(false,Enum.KeyCode.C,false,game)
 V:SendKeyEvent(false,Enum.KeyCode.V,false,game)

 label.Text="AUTO FARM: OFF"
 stop.Text="STOPPED"
end)
