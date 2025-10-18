---@class CATALOG_LENS_CONSTANTS
local M = {
	NAME = "catalog-lens",
	PNPM_WORKSPACE = "pnpm-workspace.yaml",
	YARN_WORKSPACE = ".yarnrc.yml",
	CATALOG_PREFIX = "catalog:",
	PACKAGE_JSON = "package.json",
}

-- Global variable for display option
if vim.g.catalog_display == nil then
	vim.g.catalog_display = "diagnostics" -- options: "diagnostics" or "overlay"
end

return M
