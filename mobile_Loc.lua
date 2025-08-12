-- “Loc-style” Mobile 1–10M AutoJoiner (safest + simplest: reads JSON from your GitHub repo)
-- Players run this one-liner:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/LocBall2/ajbands/main/mobile_Loc.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/LocBall2/ajbands/main"
local POLL_SEC = 4

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local REQ = rawget(getgenv(),"http_request") or rawget(getgenv(),"request") or (syn and syn.request)
local function http_get(url)
    if REQ then
        local ok, res = pcall(REQ, {Url=url, Method="GET", Headers={["Accept"]="application/json"}})
        if ok and res and (res.StatusCode or 200) < 400 then return true, res.Body end
        return false, res and (res.StatusMessage or res.StatusCode) or "request_failed"
    else
        local ok, body = pcall(game.HttpGet, game, url)
        if ok then return true, body end
        return false, body
    end
end

-- UI (small draggable panel similar to what you showed)
local gui = Instance.new("ScreenGui"); gui.Name="JoinerLocUI"; gui.ResetOnSpawn=false; gui.Parent = LP:WaitForChild("PlayerGui")
local frame = Instance.new("Frame"); frame.Size = UDim2.new(0,160,0,230); frame.Position = UDim2.new(0,20,0.5,-115)
frame.BackgroundColor3 = Color3.fromRGB(0,0,0); frame.BorderSizePixel=0; frame.Active=true; frame.Draggable=true; frame.Parent=gui
local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0,12)

local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,25); title.BackgroundTransparency=1
title.Text="Joiner | Loc"; title.TextColor3=Color3.fromRGB(255,255,255); title.TextSize=18; title.Font=Enum.Font.SourceSansBold; title.Parent=frame

local statusLbl = Instance.new("TextLabel"); statusLbl.Size = UDim2.new(1,0,0,20); statusLbl.Position = UDim2.new(0,0,0,28)
statusLbl.BackgroundTransparency=1; statusLbl.Text="Idle"; statusLbl.TextColor3=Color3.fromRGB(200,200,200); statusLbl.TextSize=16; statusLbl.Font=Enum.Font.SourceSans; statusLbl.Parent=frame

local function mkBtn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,30); b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = Color3.fromRGB(70,140,255); b.Text = text; b.TextColor3 = Color3.fromRGB(240,240,240)
    b.TextSize=18; b.Font=Enum.Font.SourceSansBold; b.AutoButtonColor=false; b.Parent=frame
    local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0,10); return b
end

local running=false; local teleporting=false; local BAND="13" -- default 1–3M
local function band_url(b) return (string.format("%s/%s.json?t=%d", BASE_URL, b, os.time())) end

local function parse_payload(body)
    local ok, obj = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(obj)~="table" then return end
    if obj.placeId and obj.jobId and obj.jobId ~= "" then return {placeId=tonumber(obj.placeId), jobId=tostring(obj.jobId)} end
end

TeleportService.TeleportInitFailed:Connect(function(_plr, result, msg)
    teleporting=false; warn("[Joiner] Teleport failed:", result, msg or ""); statusLbl.Text="Teleport failed; retrying"
end)

local startBtn = mkBtn("Start auto join", 58)
startBtn.MouseButton1Click:Connect(function()
    running = not running
    startBtn.BackgroundColor3 = running and Color3.fromRGB(0,200,100) or Color3.fromRGB(255,60,60)
    startBtn.Text = running and "Running..." or "Stopped"
    if not running then
        task.delay(2,function() if not running then startBtn.BackgroundColor3=Color3.fromRGB(70,140,255); startBtn.Text="Start auto join"; statusLbl.Text="Idle" end end)
    else
        statusLbl.Text="Polling band…"
    end
end)

local b13 = mkBtn("1-3M", 98);  local b36 = mkBtn("3-6M", 138); local b69 = mkBtn("6-9M", 178); local b910= mkBtn("9-10M", 218)
local function setBand(band, label)
    BAND=band; statusLbl.Text="Band "..label
    b13.BackgroundColor3=Color3.fromRGB(70,140,255); b36.BackgroundColor3=Color3.fromRGB(70,140,255); b69.BackgroundColor3=Color3.fromRGB(70,140,255); b910.BackgroundColor3=Color3.fromRGB(70,140,255)
    if band=="13" then b13.BackgroundColor3=Color3.fromRGB(0,120,255)
    elseif band=="36" then b36.BackgroundColor3=Color3.fromRGB(0,120,255)
    elseif band=="69" then b69.BackgroundColor3=Color3.fromRGB(0,120,255)
    else b910.BackgroundColor3=Color3.fromRGB(0,120,255) end
end
b13.MouseButton1Click:Connect(function() setBand("13","1-3M") end)
b36.MouseButton1Click:Connect(function() setBand("36","3-6M") end)
b69.MouseButton1Click:Connect(function() setBand("69","6-9M") end)
b910.MouseButton1Click:Connect(function() setBand("910","9-10M") end)

task.spawn(function()
    while true do
        if running and not teleporting then
            local ok, body = http_get(band_url(BAND))
            if ok and body then
                local cmd = parse_payload(body)
                if cmd then
                    teleporting=true; statusLbl.Text=(string.format("Teleporting %d…", cmd.placeId))
                    local s, err = pcall(function() TeleportService:TeleportToPlaceInstance(cmd.placeId, cmd.jobId, LP) end)
                    if not s then teleporting=false; warn("[Joiner] Teleport error:", err); statusLbl.Text="Teleport error; retrying" end
                end
            end
        end
        task.wait(POLL_SEC)
    end
end)
