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
local lastTeleport=0
local lastRemoteCall=0

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
    task.wait(.3) -- увеличено для защиты от кика
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
        task.wait(.5) -- увеличено
        elapsed=elapsed+.8
    end
end

local function getRoot()
    local c=me.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- Плавная телепортация с защитой от кика
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
        
        task.wait(0.1) -- увеличено с 0.02 до 0.1
    end
    
    root.CFrame = CFrame.new(targetPos)
    root.AssemblyLinearVelocity = Vector3.zero
end

-- Остальные функции без изменений...
-- (attackSkills, dungeonComplete, retryLoop, findKey, findDoors, collectKey, unlockDoors, keyDoorLoop)

local function startFarm()
    if on then return end
    on=true
    
    -- Увеличиваем characterVersion при старте
    characterVersion = characterVersion + 1
    
    task.spawn(function()
        selectSecondSlot(characterVersion)
    end)
    
    task.spawn(startDungeon)
    
    follow=R.Heartbeat:Connect(function()
        if not on or interacting then return end
        if os.clock() - lastTeleport < 0.15 then return end -- защита от кика
        lastTeleport = os.clock()
        
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
        
        if not inFolder or dead or not h or not t then
            target=nearest(root)
            t=target and target:FindFirstChild("HumanoidRootPart")
            lostAt=0
        end
        
        if t then
            smoothTeleportToTarget(root, t)
        end
    end)
    
    -- ЛКМ: отдельный цикл с задержкой
    task.spawn(function()
        while on do
            local folder=workspace:FindFirstChild("Mobs")
            
            if not interacting and target and folder
            and target:IsDescendantOf(folder) then
                
                local x,y=aimXY()  
                V:SendMouseButtonEvent(x,y,0,true,game,0)  
                task.wait(0.5) -- увеличено
                x,y=aimXY()  
                V:SendMouseButtonEvent(x,y,0,false,game,0)
                task.wait(0.5) -- увеличено
            end
            
            task.wait(0.3) -- увеличено
        end
        
        local x,y=aimXY()
        V:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    
    -- Способности: с увеличенной задержкой
    task.spawn(function()
        while on do
            local folder=workspace:FindFirstChild("Mobs")
            
            if not interacting and target and folder
            and target:IsDescendantOf(folder) then
                attackSkills()
            end
            
            task.wait(2) -- увеличено с 1.5 до 2
        end
    end)
    
    task.spawn(retryLoop)
    task.spawn(keyDoorLoop)
end

-- Остальной код без изменений...
