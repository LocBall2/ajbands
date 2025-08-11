-- Mobile 1–10M AutoJoiner (reads JSON files from your GitHub repo)
-- Players will run:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/LocBall2/ajbands/main/mobile_1to10.lua"))()

-- ========== CONFIG ==========
-- Raw base of your repo:
local BASE_URL   = "https://raw.githubusercontent.com/LocBall2/ajbands/main"
local POLL_SEC   = 4
local SHOW_STATUS = true
-- ============================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

-- Cross-executor HTTP
local REQ = rawget(getgenv(),"http_request") or rawget(getgenv(),"request") or (syn and syn.request)
local function http_get(url)
    if REQ then
        local ok, res = pcall(REQ, {Url=url, Method="GET", Headers={["Accept"]="application/json"}})
        if ok and res and (res.StatusCode or 200) < 400 then
            return true, res.Body
        end
        return false, res and (res.StatusMessage or res.StatusCode) or "request_failed"
    else
        local ok, body = pcall(game.HttpGet, game, url)
        if ok then return true, body end
        return false, body
    end
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name="MobileJoiner1to10"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
gui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(16,16)
panel.Size = UDim2.fromOffset(220, 250)
panel.BackgroundColor3 = Color3.fromRGB(12,12,12)
panel.BorderSizePixel = 0
panel.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.fromOffset(200, 22)
title.Position = UDim2.fromOffset(10, 8)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Text = "Joiner | 1–10M"
title.Parent = panel

local function mkBtn(text, y, cb)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 18
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(70,120,255)
    b.Size = UDim2.fromOffset(200, 34)
    b.Position = UDim2.fromOffset(10, y)
    b.Parent = panel
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

local statusLbl = Instance.new("TextLabel")
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.fromOffset(200, 22)
statusLbl.Position = UDim2.fromOffset(10, 212)
statusLbl.Font = Enum.Font.SourceSans
statusLbl.TextSize = 18
statusLbl.TextColor3 = Color3.fromRGB(220,220,220)
statusLbl.Text = "Idle"
statusLbl.Parent = panel

local function setStatus(t) if SHOW_STATUS then statusLbl.Text = t end end

-- Bands map to file names 13/36/69/910.json
local BAND = "13"  -- default 1–3M
local function band_url(b)
    return ("%s/%s.json?t=%d"):format(BASE_URL, b, os.time())
end

mkBtn("Start auto join", 36, function()
    getgenv().__AJ_RUN = not getgenv().__AJ_RUN
    setStatus(getgenv().__AJ_RUN and "Running…" or "Stopped")
end)

mkBtn("1–3M", 76,  function() BAND="13";  setStatus("Band 1–3M") end)
mkBtn("3–6M", 116, function() BAND="36";  setStatus("Band 3–6M") end)
mkBtn("6–9M", 156, function() BAND="69";  setStatus("Band 6–9M") end)
mkBtn("9–10M",196,function() BAND="910"; setStatus("Band 9–10M") end)

local function parse_payload(body)
    local ok, obj = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(obj)~="table" then return end
    if obj.placeId and obj.jobId and obj.placeId ~= HttpService:JSONDecode("null") then
        return {placeId=tonumber(obj.placeId), jobId=tostring(obj.jobId)}
    end
end

local teleporting = false
TeleportService.TeleportInitFailed:Connect(function(_plr, result, msg)
    teleporting = false
    warn("[AutoJoiner] Teleport failed:", result, msg or "")
    setStatus("Teleport failed; retrying")
end)

task.spawn(function()
    while true do
        if getgenv().__AJ_RUN and not teleporting then
            local url = band_url(BAND)
            local ok, body = http_get(url)
            if ok and body then
                local cmd = parse_payload(body)
                if cmd and cmd.placeId and cmd.jobId and tostring(cmd.jobId) ~= "" then
                    teleporting = true
                    setStatus(("Teleporting %d…"):format(cmd.placeId))
                    local s, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(cmd.placeId, cmd.jobId, LP)
                    end)
                    if not s then
                        teleporting = false
                        warn("[AutoJoiner] Teleport error:", err)
                        setStatus("Teleport error; retrying")
                    end
                end
            end
        end
        task.wait(POLL_SEC)
    end
end)

setStatus("Idle")
