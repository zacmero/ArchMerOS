-- Position only the DP-1 bar's dedicated OpenRouter HUD.
local M = {}
local class = "archmeros-aichat-beacon"
local special_name = "archmeros-ai-hub"
local special_workspace = "special:" .. special_name
local bar_width = 190
local bar_margin = 8
local popup_gap = 18
local popup_width = 820
local popup_height = 1040
-- Keep bar_width aligned with config/waybar/beacon.jsonc.

local function selector(window)
    return "address:" .. window.address
end

local function target_monitor()
    local focused
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name == "DP-1" then
            return monitor
        end
        if monitor.focused then
            focused = monitor
        end
    end
    return focused
end

local function place(window, monitor)
    local scale = monitor.scale > 0 and monitor.scale or 1
    local width = monitor.width / scale
    local height = monitor.height / scale
    local reserved = monitor.reserved
    local target_width = math.max(1, math.min(popup_width, width - bar_width - bar_margin - popup_gap - 24))
    local target_height = math.max(1, math.min(popup_height, height - reserved.top - reserved.bottom - 32))
    local x = monitor.x + width - bar_width - bar_margin - popup_gap - target_width
    local y = monitor.y + reserved.top + math.max(16, (height - reserved.top - reserved.bottom - target_height) / 2)

    hl.dispatch(hl.dsp.window.float({ action = "enable", window = selector(window) }))
    hl.dispatch(hl.dsp.window.resize({ x = target_width, y = target_height, relative = false, window = selector(window) }))
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false, window = selector(window) }))
end

local function show(window, monitor)
    hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
    if not window.workspace or window.workspace.name ~= special_workspace or not window.monitor or window.monitor.name ~= monitor.name then
        hl.dispatch(hl.dsp.window.move({
            window = selector(window),
            workspace = special_workspace,
            follow = false,
        }))
    end
    if not monitor.active_special_workspace or monitor.active_special_workspace.name ~= special_workspace then
        hl.dispatch(hl.dsp.workspace.toggle_special(special_name))
    end
    place(window, monitor)
    hl.dispatch(hl.dsp.focus({ window = selector(window) }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

function M.on_window_open(window)
    if not window.mapped or window.class ~= class then
        return
    end
    local monitor = target_monitor()
    if monitor then
        show(window, monitor)
    end
end

hl.on("window.open", M.on_window_open)

return M
