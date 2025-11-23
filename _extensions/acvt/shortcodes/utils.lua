local M = {}

function M.unwrap(obj)
  if obj == nil then return nil end
  local t = pandoc.utils.type(obj)
  if t == 'MetaList' or t == 'List' then
    local res = {}
    for i, v in ipairs(obj) do res[i] = M.unwrap(v) end
    return res
  elseif t == 'MetaMap' or t == 'Map' or t == 'table' then
    local res = {}
    for k, v in pairs(obj) do res[k] = M.unwrap(v) end
    return res
  end
  return pandoc.utils.stringify(obj)
end

function M.safe_string(obj)
  if obj == nil then return "" end
  local status, res = pcall(pandoc.utils.stringify, obj)
  if status then return res end
  return tostring(obj)
end

function M.trim(s)
  if not s then return nil end
  return s:match("^%s*(.-)%s*$")
end

-- Replaces smart quotes with standard quotes (for code/markup)
function M.fix_smart_quotes(s)
  if not s then return nil end
  s = tostring(s)
  s = s:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  return s
end

-- Escapes special characters for Typst string content
function M.escape_typst(val)
  local s = M.fix_smart_quotes(val) -- First fix smart quotes
  if not s then return "" end
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return s
end

-- Returns a fully quoted Typst string literal
function M.quote_typst(val)
  return '"' .. M.escape_typst(val) .. '"'
end

function M.is_na(val)
  if not val then return true end
  local s = tostring(val)
  return (s == "" or s == "NA" or s == ".na.character")
end

function M.get_arg(kwargs, key, default)
  local val = kwargs[key]
  if not val then return default end
  local s = pandoc.utils.stringify(val)
  if s == "" then return default end
  return s
end

function M.parse_list_string(val)
  local res = {}
  local s = pandoc.utils.stringify(val)
  if s and s ~= "" then
    for item in string.gmatch(s, "([^,]+)") do
      table.insert(res, item:match("^%s*(.-)%s*$"))
    end
  end
  return res
end

function M.file_exists(path)
  local f = io.open(path, "r")
  if f then io.close(f); return true else return false end
end

function M.parse_key_val(str)
  local res = {}
  local s = M.safe_string(str)
  for pair in string.gmatch(s, "([^,]+)") do
    local k, v = pair:match("^%s*([^=]+)=([^=]+)%s*$")
    if k and v then res[M.trim(k)] = M.trim(v) end
  end
  return res
end

return M
