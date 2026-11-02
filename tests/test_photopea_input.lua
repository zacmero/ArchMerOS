local policy = dofile("config/hypr/photopea_input.lua")
assert(policy.protected({class="chrome-www.photopea.com__-Default", fullscreen=2}))
assert(policy.protected({class="archmeros-photopea", fullscreen_client=2}))
assert(not policy.protected({class="archmeros-photopea", fullscreen=0}))
assert(not policy.protected({class="firefox", fullscreen=2}))
assert(not policy.protected(nil))

local active = {class="archmeros-photopea", fullscreen=2}
local events, enabled = {}, nil
hl = {
    get_active_window = function() return active end,
    on = function(name, callback) events[name] = callback end,
}
policy.attach({{set_enabled=function(_, value) enabled=value end}})
assert(enabled == false)
active = {class="archmeros-photopea", fullscreen=0}
events["window.fullscreen"]()
assert(enabled == true)
active = {class="archmeros-photopea", fullscreen=2}
events["window.fullscreen"]()
assert(enabled == false)
active = {class="wezterm", fullscreen=2}
events["window.active"]()
assert(enabled == true)
print("Photopea input policy: all checks passed")
