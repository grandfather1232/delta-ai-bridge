local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local me=P.LocalPlayer
local on=false
local target

local g=Instance.new("ScreenGui",game:GetService("CoreGui"))
g.Name="AutoFarm"
local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(145,90)
f.Position=UDim2.new(.5,-72,.5,0)
f.BackgroundColor3=Color3.fromRGB(35,35,45)
f.Active=true
f.Draggable=true

local function btn(txt,y,color)
 local b=Instance.new("TextButton",f)
 b.Size=UDim2.new(1,-10,0,32)
 b.Position=UDim2.fromOffset(5,y)
 b.Text=txt
 b.TextColor3=Color3.new(1,1,1)
 b.BackgroundColor3=color
 return b
end

local start=btn("START",5,Color3.fromRGB(20,140,60))
local stop=btn("STOP",48,Color3.fromRGB(160,40,40))

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

local function key(k)
 V:SendKeyEvent(true,k,false,game)
 task.wait(.1)
 V:SendKeyEvent(false,k,false,game)
end

local function attack()
 local cam=workspace.CurrentCamera
 local p=cam.ViewportSize/2
 V:SendMouseButtonEvent(p.X,p.Y,0,true,game,0)
 task.wait(.1)
 V:SendMouseButtonEvent(p.X,p.Y,0,false,game,0)
 task.wait(.2)
 key(Enum.KeyCode.F)
 key(Enum.KeyCode.C)
 key(Enum.KeyCode.V)
end

local follow
start.MouseButton1Click:Connect(function()
 if on then return end
 on=true

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
   if target and target.Parent then attack() end
   task.wait(.3)
  end
 end)
end)

stop.MouseButton1Click:Connect(function()
 on=false
 target=nil
 if follow then follow:Disconnect() follow=nil end
end)



1 сообщение

