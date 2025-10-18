local api = vim.api

---@class CATALOG_LENS_CONSTANTS
local constants = require("catalog_lens.constants")

---@class CATALOG_LENS_INIT
local M = require("catalog_lens")

local bufnr = api.nvim_get_current_buf()
local filename = api.nvim_buf_get_name(bufnr)

if filename:sub(-#constants.PACKAGE_JSON) ~= constants.PACKAGE_JSON then
	return
end

api.nvim_buf_create_user_command(
	bufnr,
	"CatalogLensEnable",
	M.enable,
	{ nargs = 0, desc = "Enable the catalog lens" }
)

api.nvim_buf_create_user_command(
	bufnr,
	"CatalogLensDisable",
	M.disable,
	{ nargs = 0, desc = "Disable the catalog lens" }
)

M.enable()
