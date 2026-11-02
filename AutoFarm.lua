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
local voteRemote=partyService and partyService:FindFirstChild("VoteOn",true)
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

local function nearest(r)
 local folder=workspace:FindFirstChild("Mobs")
 if not folder or not r then return nil end

 local best=nil
 local shortest=math.huge

 for _,mob in ipairs(folder:GetDescendants()) do
  if validMob(mob) then
   local t=mob:FindFirstChild("HumanoidRootPart")
   local d=(r.Position-t.Position).Magnitude

   if d<shortest then
    shortest=d
    best=mob
   end
  end
 end

 return best
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
   else
    if on then
  if not validMob(target) then
   target=nearest(root)
  end

  if not validMob(target) then
   status.Text="NO MOBS FOUND"
   return
  end

  local t=target:FindFirstChild("HumanoidRootPart")

  if t then
   status.Text="TARGET: "..target.Name

   root.CFrame=CFrame.lookAt(
    t.Position-Vector3.new(0,8,0),
    t.Position
   )

   root.AssemblyLinearVelocity=Vector3.zero
  end
 end)

 task.spawn(function()
  while on do
   if not interacting and validMob(target) then
 V:SendMouseButtonEvent(0,0,0,false,game,0)

 if follow then
  follow:Disconnect()
  follow=nil
 end

 status.Text="AUTO FARM OFF"
end)

startFarm()
