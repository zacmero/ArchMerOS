-- A single native special workspace is the slot; closing or releasing its
-- window frees it automatically, including across config reloads.
local M = {}
local name = "archmeros-scratchpad"
local workspace = "special:" .. name

local function focused_monitor()
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.focused then return monitor end
    end
end

local function belongs(window)
    return window and window.workspace and window.workspace.name == workspace
end

local function selector(window)
    return "address:" .. window.address
end

-- New applications inherit an open special workspace by default. Adoption is
-- explicit here, so keep newly mapped windows on the regular workspace below.
hl.on("window.open", function(window)
    if belongs(window) and window.monitor and window.monitor.active_workspace then
        hl.dispatch(hl.dsp.window.move({
            window = selector(window), workspace = tostring(window.monitor.active_workspace.id), follow = false,
        }))
    end
end)

local function place(window, size, monitor)
    local reserved = monitor.reserved
    local gaps = hl.get_config("general.gaps_out")
    local border = hl.get_config("general.border_size")
    local width = monitor.width / monitor.scale
    local height = monitor.height / monitor.scale
    if monitor.transform % 2 == 1 then
        width, height = height, width
    end
    local max_width = width - reserved.left - reserved.right - gaps.left - gaps.right - 2 * border
    local max_height = height - reserved.top - reserved.bottom - gaps.top - gaps.bottom - 2 * border
    hl.dispatch(hl.dsp.window.resize({
        window = selector(window), relative = false,
        x = math.max(1, math.floor(math.min(size.x, max_width))),
        y = math.max(1, math.floor(math.min(size.y, max_height))),
    }))
    hl.dispatch(hl.dsp.window.center({ window = selector(window) }))
end

function M.toggle()
    local monitor = focused_monitor()
    if not monitor then return end
    local slot
    for _, window in ipairs(hl.get_windows()) do
        if window.mapped and belongs(window) then slot = window; break end
    end

    if not slot then
        local window = hl.get_active_window()
        if not window or not window.mapped or not window.workspace or window.workspace.special then return end
        local size = window.size
        if window.pinned then hl.dispatch(hl.dsp.window.pin({ window = selector(window) })) end
        if window.fullscreen ~= 0 or window.fullscreen_client ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen_state({ window = selector(window), internal = 0, client = 0 }))
        end
        hl.dispatch(hl.dsp.window.float({ window = selector(window), action = "enable" }))
        place(window, size, monitor)
        hl.dispatch(hl.dsp.window.move({ window = selector(window), workspace = workspace, follow = false }))
        return
    end

    local showing_here = monitor.active_special_workspace
        and monitor.active_special_workspace.name == workspace
    local size = slot.size
    -- A native toggle closes an overlay already visible on another monitor.
    -- Close there first, then summon here within the same compositor turn.
    if not showing_here and slot.workspace.visible then
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
        hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
    end
    hl.dispatch(hl.dsp.workspace.toggle_special(name))
    if not showing_here then
        place(slot, size, monitor)
        hl.dispatch(hl.dsp.focus({ window = selector(slot) }))
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end

function M.release()
    local window = hl.get_active_window()
    local monitor = focused_monitor()
    if not belongs(window) or not monitor or not monitor.active_workspace then return end
    local size = window.size
    hl.dispatch(hl.dsp.window.move({
        window = selector(window), workspace = tostring(monitor.active_workspace.id), follow = false,
    }))
    -- Empty special workspaces normally close themselves; also cover configs
    -- where close_special_on_empty has been disabled.
    if monitor.active_special_workspace and monitor.active_special_workspace.name == workspace then
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end
    hl.dispatch(hl.dsp.focus({ window = selector(window) }))
    place(window, size, monitor)
    hl.dispatch(hl.dsp.window.bring_to_top())
end

return M
