-- Release mouse modifiers to Photopea while its editor is fullscreen.
local M = {}

function M.protected(window)
    if not window then return false end
    local class = (window.class or ""):lower()
    local editor = class == "archmeros-photopea" or class:find("photopea.com", 1, true) ~= nil
    return editor and ((window.fullscreen or 0) ~= 0 or (window.fullscreen_client or 0) ~= 0)
end

function M.attach(bindings)
    local function update()
        local enabled = not M.protected(hl.get_active_window())
        for _, binding in ipairs(bindings) do binding:set_enabled(enabled) end
    end
    hl.on("window.active", update)
    hl.on("window.fullscreen", update)
    update()
end

return M
