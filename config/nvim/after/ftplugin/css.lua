-- Waybar styles use GTK CSS colors (@text, @mantle), not web CSS variables.
local path = vim.api.nvim_buf_get_name(0)
local real_path = vim.uv.fs_realpath(path) or path
if real_path:match("/config/waybar/[^/]+%.css$") or path:match("/%.config/waybar/[^/]+%.css$") then
  vim.diagnostic.enable(false, { bufnr = 0 })
end
