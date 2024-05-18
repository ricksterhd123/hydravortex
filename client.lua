--[[
]]

local hydra

-- Config
local maxTurbulenceTime = 2500  -- how long wake turbulence should last the moment it minAngleOfAttackRate exceeded
local minAngleOfAttackRate = 0.25  -- minimum AngleOfAttack rate, when exceeded causes wake turbulence and vortices

-- State
local turbulenceEnabled = false
local lastTurbulenceEnabledTick = 0
local lastAngleOfAttack = 0

--[[
    The vortex class
]]
local Vortex = {}
Vortex.__index = Vortex

function Vortex:new(maxVortices, maxTick)
    local self = setmetatable({}, Vortex)

    self.maxVortices = maxVortices
    self.maxTick = maxTick
    self.vortices = {}

    return self
end

function Vortex:update()
    if #self.vortices < 1 then
        return
    end

    local now = getTickCount()
    local _, _, _, _, tick = unpack(self.vortices[1])

    if #self.vortices > self.maxVortices or now - tick > self.maxTick then
        table.remove(self.vortices, 1)
    end
end

function Vortex:add(x, y, z, opacity)
    local tick = getTickCount()
    table.insert(self.vortices, #self.vortices + 1, { x, y, z, opacity, tick })
end

function Vortex:draw()
    if #self.vortices <= 1 then
        return
    end

    local startTick = self.vortices[1][5]
    local endTick = self.vortices[#self.vortices][5]
    local offset = endTick - startTick

    for i = #self.vortices - 1, 1, -1  do
        local ax, ay, az, opacityA, tick = unpack(self.vortices[i+1])
        local bx, by, bz, opacityB, tick = unpack(self.vortices[i])

        local ratio = math.min(1, (tick - startTick) / self.maxTick)

        local opacityRatio = ratio
        local densityRatio = 1 - ratio

        -- don't conjoin two points between large distances
        -- it looks buggy
        if getDistanceBetweenPoints3D(ax, ay, az, bx, by, bz) < 4 then
            dxDrawLine3D(ax, ay, az, bx, by, bz, tocolor(255, 255, 255, 255 * opacityRatio), 10 * densityRatio)
        end
    end
end

function Vortex:clear()
    self.vortices = {}
end

--[[
    Utility functions
]]
local function getPositionFromElementOffset(element,offX,offY,offZ)
    local m = getElementMatrix ( element )  -- Get the matrix
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]  -- Apply transform
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return x, y, z                               -- Return the transformed point
end

local function angleBetween(v1, v2)
    local dot = v1:dot(v2)

    local v1Length = v1:getLength()
    local v2Length = v2:getLength()

    if v1Length > 0 and v2Length > 0 then
        return dot / (v1Length * v2Length)
    end

    return 0
end

local function getAngleOfAttack(hydra, minimumVelocity)
    minimumVelocity = minimumVelocity or 1
    local velocity = Vector3(getElementVelocity(hydra))
    local matrix = getElementMatrix(hydra)
    local left = Vector3(unpack(matrix[1]))
    return velocity:getLength() < minimumVelocity and 0 or angleBetween(left, velocity)
end

--[[
    Main script
]]
local leftWingTipVortex = Vortex:new(250, maxTurbulenceTime)
local rightWingTipVortex = Vortex:new(250, maxTurbulenceTime)

local function stop()
    hydra = nil
    leftWingTipVortex:clear()
    rightWingTipVortex:clear()
end

local function start(vehicle)
    if isElement(vehicle) and getElementModel(vehicle) == 520 then
        hydra = vehicle
        addEventHandler("onClientVehicleExplode", hydra, stop)

        local stopOnce = function ()
            removeEventHandler("onClientElementModelChange", hydra, stopOnce)
            removeEventHandler("onClientVehicleExit", hydra, stopOnce)
            stop()
        end
        addEventHandler("onClientElementModelChange", hydra, stopOnce)
        addEventHandler("onClientVehicleExit", hydra, stopOnce)
    end
end
addEventHandler("onClientPlayerVehicleEnter", localPlayer, start)

local function update()
    if not hydra then
        return
    end

    local now = getTickCount()
    local angleOfAttackDegrees = math.deg(getAngleOfAttack(hydra))
    local angleOfAttackRate = angleOfAttackDegrees - lastAngleOfAttack

    lastAngleOfAttack = angleOfAttackDegrees

    local turbulenceElapsed = now - lastTurbulenceEnabledTick

    if turbulenceEnabled and turbulenceElapsed > maxTurbulenceTime then
        turbulenceEnabled = false
    end

    if not turbulenceEnabled and math.abs(angleOfAttackRate) > minAngleOfAttackRate then
        turbulenceEnabled = true
        lastTurbulenceEnabledTick = now
    end

    if turbulenceEnabled then
        local lx, ly, lz = getPositionFromElementOffset(hydra, -4.8, -0.5, -0.4)
        local rx, ry, rz = getPositionFromElementOffset(hydra, 4.8, -0.5, -0.4)

        leftWingTipVortex:add(lx, ly, lz, 255)
        rightWingTipVortex:add(rx, ry, rz, 255)
    end

    leftWingTipVortex:update()
    rightWingTipVortex:update()
end
addEventHandler("onClientPreRender", root, update)

local function draw()
    if not hydra then
        return
    end

    leftWingTipVortex:draw()
    rightWingTipVortex:draw()
end
addEventHandler("onClientRender", root, draw)

addEventHandler("onClientResourceStart", resourceRoot, function ()
    start(getPedOccupiedVehicle(localPlayer))
end)
