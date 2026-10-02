---@diagnostic disable: redefined-local

---@alias CatalogDependency {line: number, col: number, named: string|nil}
---@alias Catalog table<string, string>
---@alias Catalogs table<string, Catalog>

local api = vim.api
local uv = vim.uv
local fs = vim.fs
local ts = vim.treesitter

---@class CATALOG_LENS_CONSTANTS
local constants = require("catalog_lens.constants")

---@class CATALOG_LENS_API
local M = {}

-- read file
---@param path string
local readFile = function(path)
	local fd = assert(uv.fs_open(path, "r", 438))
	local stat = assert(uv.fs_fstat(fd))
	local data = assert(uv.fs_read(fd, stat.size, 0))
	assert(uv.fs_close(fd))
	return data
end

M.find_workspace = function()
	local cwd = vim.fn.getcwd()
	local root_dir = fs.root(
		cwd,
		vim.iter({ ".git", constants.PNPM_WORKSPACE, constants.YARN_WORKSPACE }):flatten(math.huge):totable()
	)

	if root_dir ~= nil then
		local pnpm_workspace_path = fs.joinpath(root_dir or "", constants.PNPM_WORKSPACE)
		if uv.fs_stat(pnpm_workspace_path) ~= nil then
			return pnpm_workspace_path
		end

		local yarn_workspace_path = fs.joinpath(root_dir or "", constants.YARN_WORKSPACE)
		if uv.fs_stat(yarn_workspace_path) ~= nil then
			return yarn_workspace_path
		end
	end

	return nil
end

-- find the first child node of the given type
---@param node TSNode|nil
---@param type string
---@return TSNode|nil
local findChild = function(node, type)
	if node == nil then
		return nil
	end

	for child in node:iter_children() do
		if child:type() == type then
			return child
		end
	end

	return nil
end

-- get the text of a key or a scalar value without quotes
-- (ex. ["@scope/name"] -> @scope/name, yarn reads a bracketed key as its only element)
---@param node TSNode
---@param source string
---@return string
local scalarText = function(node, source)
	local text = ts.get_node_text(node, source)
	text = text:gsub("^%[%s*(.-)%s*%]$", "%1")
	return (text:gsub("^(['\"])(.*)%1$", "%2"))
end

-- convert a yaml mapping of scalars and nested mappings to a table
---@param mapping TSNode|nil
---@param source string
---@return table
local function mappingToTable(mapping, source)
	local result = {}
	if mapping == nil then
		return result
	end

	for pair in mapping:iter_children() do
		if pair:type() == "block_mapping_pair" then
			local key = scalarText(pair:field("key")[1], source)
			local value = pair:field("value")[1]

			if value ~= nil and value:type() == "flow_node" then
				result[key] = scalarText(value, source)
			else
				result[key] = mappingToTable(findChild(value, "block_mapping"), source)
			end
		end
	end

	return result
end

-- parse config file and return catalogs
---@return {catalogs: Catalogs|nil, catalog: Catalog|nil} | nil
M.get_catalog_and_catalogs_from_workspace_yaml = function()
	local workspace_path = M.find_workspace()
	if workspace_path == nil then
		return nil
	end

	local data = readFile(workspace_path)

	if data == nil or #data == 0 then
		return nil
	end

	local ok, available = pcall(ts.language.add, "yaml")
	local yaml_data

	if ok and available then
		local root = ts.get_string_parser(data, "yaml"):parse()[1]:root()
		local document = findChild(root, "document")
		yaml_data = mappingToTable(findChild(findChild(document, "block_node"), "block_mapping"), data)
	else
		data = data:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n+", "\n")
		yaml_data = require("catalog_lens.yaml").eval(data)
	end

	return {
		catalog = yaml_data.catalog,
		catalogs = yaml_data.catalogs,
	}
end

-- parse the currrent buffer and return the keys/line/col which value is `:catalog`
---@param bufnr number buffer number
---@return table<string, CatalogDependency> | nil
M.extract_catalog_dependencies_from_package_json = function(bufnr)
	local result = {}
	for i, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		if line:find(constants.CATALOG_PREFIX) then
			-- chekc if the line includes constant.CATALOG_PREFIX
			local catalog_col = line:find(constants.CATALOG_PREFIX)
			if catalog_col ~= nil then
				-- get catalog key (ex. "zod": "catalog:" -> "zod")
				---@type string | nil
				local catalog_pkg = line:match('"(.-)"')

				--get named catalog (ex. "react": "catalog:react18" -> "react18")
				---@type string | nil
				local named = line:match("catalog:([%w%-_%./%+]+)")

				if catalog_pkg ~= nil then
					result[catalog_pkg] = { line = i - 1, col = catalog_col, named = named }
				end
			end
		end
	end
	return result
end

return M
