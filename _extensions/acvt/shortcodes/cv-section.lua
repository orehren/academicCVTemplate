-- =============================================================================
-- 1. CORE UTILITIES
-- =============================================================================

local function unwrap(obj)
  if obj == nil then return nil end
  local t = pandoc.utils.type(obj)
  if t == 'MetaList' or t == 'List' then
    local res = {}
    for i, v in ipairs(obj) do res[i] = unwrap(v) end
    return res
  elseif t == 'MetaMap' or t == 'Map' or t == 'table' then
    local res = {}
    for k, v in pairs(obj) do res[k] = unwrap(v) end
    return res
  end
  return pandoc.utils.stringify(obj)
end

local function is_na(val)
  if not val then return true end
  local s = tostring(val)
  return (s == "" or s == "NA" or s == ".na.character")
end

local function clean_string(val)
  local s = tostring(val)
  s = s:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. s .. '"'
end

local function get_arg(kwargs, key, default)
  local val = kwargs[key]
  if not val then return default end
  local s = pandoc.utils.stringify(val)
  return (s == "") and default or s
end

local function read_cv_data_json()
  local f = io.open(".cv_data.json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return (content and content ~= "") and quarto.json.decode(content) or nil
end

-- Lookup table for NA handling strategies
local NA_ACTIONS = {
  string = "NA",
  keep   = nil, -- Returns nil to signal 'none' to the caller
  omit   = ""
}

-- Resolves NA values based on configuration without nested ifs
local function resolve_na(action_key)
  local res = NA_ACTIONS[action_key]
  if res == nil and action_key ~= "keep" then return "" end
  return res
end


-- =============================================================================
-- 2. COLUMN SELECTION STRATEGIES
-- =============================================================================

local function get_col_index(cols, name)
  for i, v in ipairs(cols) do
    if v == name then return i end
  end
  return nil
end

local function select_range(part, all_columns, result_list, seen_set)
  local start_col, end_col = part:match("^([%w_]+):([%w_]+)$")
  if not (start_col and end_col) then return false end

  local idx_start = get_col_index(all_columns, start_col)
  local idx_end = get_col_index(all_columns, end_col)

  if not (idx_start and idx_end) then return false end

  local step = (idx_start <= idx_end) and 1 or -1
  for i = idx_start, idx_end, step do
    local col = all_columns[i]
    if not seen_set[col] then
      table.insert(result_list, col)
      seen_set[col] = true
    end
  end
  return true
end

local PREDICATES = {
  starts_with = function(col, arg) return col:find("^" .. arg) end,
  ends_with   = function(col, arg) return col:find(arg .. "$") end,
  contains    = function(col, arg) return col:find(arg, 1, true) end,
  matches     = function(col, arg) return col:find(arg) end
}

local function select_predicate(part, all_columns, result_list, seen_set)
  local func_name, arg = part:match("^([%w_]+)%(['\"](.+)['\"]%)$")
  if not func_name then return false end

  local matcher = PREDICATES[func_name]
  if not matcher then return false end

  for _, col in ipairs(all_columns) do
    if matcher(col, arg) and not seen_set[col] then
      table.insert(result_list, col)
      seen_set[col] = true
    end
  end
  return true
end

local function select_literal(part, all_columns, result_list, seen_set)
  if not get_col_index(all_columns, part) then return false end

  if not seen_set[part] then
    table.insert(result_list, part)
    seen_set[part] = true
  end
  return true
end

local function resolve_tidy_select(selector_str, all_columns)
  if not selector_str or selector_str == "" then return {} end

  local selected = {}
  local seen = {}

  for part in string.gmatch(selector_str, "([^,]+)") do
    part = part:match("^%s*(.-)%s*$") -- trim
    local handled = select_range(part, all_columns, selected, seen)
    if not handled then handled = select_predicate(part, all_columns, selected, seen) end
    if not handled then select_literal(part, all_columns, selected, seen) end
  end

  return selected
end


-- =============================================================================
-- 3. INTERPOLATION ENGINE
-- =============================================================================

local function parse_interpolation_syntax(inner)
  local s, sep = inner:match("^(.-)%s*|%s*(.*)$")
  if s then return s:match("^%s*(.-)%s*$"), sep end
  return inner:match("^%s*(.-)%s*$"), " "
end

-- Helper to reduce nesting in extract_consumed_cols
local function mark_interpolation_cols(tmpl, all_columns, consumed_map)
  for inner in tmpl:gmatch("{(.-)}") do
    local selector, _ = parse_interpolation_syntax(inner)
    local resolved = resolve_tidy_select(selector, all_columns)
    for _, c in ipairs(resolved) do consumed_map[c] = true end
  end
end

local function extract_consumed_cols(templates, all_columns)
  local consumed = {}
  for _, tmpl in pairs(templates) do
    if tmpl:find("{") then
      mark_interpolation_cols(tmpl, all_columns, consumed)
    elseif get_col_index(all_columns, tmpl) then
      consumed[tmpl] = true
    end
  end
  return consumed
end

local function interpolate_str(template, row_map, all_columns)
  return template:gsub("{(.-)}", function(inner)
    local selector, separator = parse_interpolation_syntax(inner)
    local cols = resolve_tidy_select(selector, all_columns)

    local values = {}
    for _, col_name in ipairs(cols) do
      local val = row_map[col_name]
      if not is_na(val) then
        table.insert(values, tostring(val))
      end
    end

    return table.concat(values, separator)
  end)
end


-- =============================================================================
-- 4. CONFIGURATION PARSER
-- =============================================================================

local function parse_config(kwargs, all_columns)
  local config = {
    templates = {},
    max_pos = -1,
    exclude_set = {},
    na_action = get_arg(kwargs, "na_action", "omit")
  }

  for k, v in pairs(kwargs) do
    local idx = tonumber(k:match("^pos%-(%d+)$"))
    if idx then
      config.templates[idx] = pandoc.utils.stringify(v)
      if idx > config.max_pos then config.max_pos = idx end
    end
  end

  local exclude_list = resolve_tidy_select(get_arg(kwargs, "exclude-cols", ""), all_columns)
  for _, c in ipairs(exclude_list) do config.exclude_set[c] = true end

  return config
end


-- =============================================================================
-- 5. ROW PROCESSING (Flat Logic)
-- =============================================================================

local function get_explicit_value(tmpl, context)
  if tmpl:find("{") then
    return interpolate_str(tmpl, context.row_map, context.all_columns)
  end

  -- Direct column reference
  if context.row_map[tmpl] then
    local val = context.row_map[tmpl]
    if is_na(val) then return resolve_na(context.config.na_action) end
    return val
  end

  return tmpl -- Static text
end

-- Separates the search logic from the value extraction logic
local function find_next_unused_key(context)
  while context.auto_ptr <= #context.ordered_keys do
    local key = context.ordered_keys[context.auto_ptr]
    context.auto_ptr = context.auto_ptr + 1

    if not context.consumed[key] then return key end
  end
  return nil
end

local function get_autofill_value(context)
  local key = find_next_unused_key(context)
  if not key then return nil end

  local val = context.row_map[key]
  if is_na(val) then return resolve_na(context.config.na_action) end

  return val
end

local function process_row(row_list, config, global_consumed, all_columns)
  local context = {
    row_map = {},
    ordered_keys = {},
    consumed = {},
    auto_ptr = 1,
    config = config,
    all_columns = all_columns
  }

  for _, item in ipairs(row_list) do
    context.row_map[item.key] = item.value
    table.insert(context.ordered_keys, item.key)
  end

  for k in pairs(global_consumed) do context.consumed[k] = true end
  for k in pairs(config.exclude_set) do context.consumed[k] = true end

  local final_args = {}
  local current_slot = 0
  local safety_limit = config.max_pos + #context.ordered_keys + 5

  while current_slot < safety_limit do
    if current_slot > config.max_pos and context.auto_ptr > #context.ordered_keys then
      break
    end

    local val = nil
    local tmpl = config.templates[current_slot]

    if tmpl then
      val = get_explicit_value(tmpl, context)
    else
      val = get_autofill_value(context)
    end

    if val == nil then
      if current_slot <= config.max_pos then
        table.insert(final_args, '""')
      elseif config.na_action == "keep" then
        table.insert(final_args, "none")
      end
    else
      table.insert(final_args, clean_string(val))
    end

    current_slot = current_slot + 1
  end

  return final_args
end


-- =============================================================================
-- 6. MAIN ENTRY POINT
-- =============================================================================

local function generate_cv_section(args, kwargs, meta)
  local sheet_name = get_arg(kwargs, "sheet", "")
  local func_name  = get_arg(kwargs, "func", "")

  if sheet_name == "" or func_name == "" then
    return pandoc.Strong(pandoc.Str("Missing sheet/func"))
  end

  local raw_data = nil
  if meta.cv_data and meta.cv_data[sheet_name] then
    raw_data = meta.cv_data[sheet_name]
  else
    local json = read_cv_data_json()
    if json and json.cv_data then raw_data = json.cv_data[sheet_name] end
  end

  if not raw_data then
    return pandoc.Strong(pandoc.Str("Sheet not found: " .. sheet_name))
  end

  local rows_unwrapped = unwrap(raw_data)
  local rows = (pandoc.utils.type(rows_unwrapped) == "MetaList" or (type(rows_unwrapped)=="table" and rows_unwrapped[1]))
               and rows_unwrapped or {rows_unwrapped}

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  local all_columns = {}
  for _, field in ipairs(rows[1]) do
    if field.key then table.insert(all_columns, field.key) end
  end

  local config = parse_config(kwargs, all_columns)
  local global_consumed = extract_consumed_cols(config.templates, all_columns)

  local blocks = {}
  for _, row in ipairs(rows) do
    local args_list = process_row(row, config, global_consumed, all_columns)
    if #args_list > 0 then
      table.insert(blocks, "#" .. func_name .. "(" .. table.concat(args_list, ", ") .. ")")
    end
  end

  if #blocks == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", table.concat(blocks, "\n"))
end

return { ["cv-section"] = generate_cv_section }

