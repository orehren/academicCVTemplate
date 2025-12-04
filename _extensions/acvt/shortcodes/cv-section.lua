-- =============================================================================
-- 1. UTILS & TIDY SELECT
-- =============================================================================

-- Recursively unwrap Pandoc elements
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
  if s == "" then return default end
  return s
end

local function read_cv_data_json()
  local f = io.open(".cv_data.json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil end
  return quarto.json.decode(content)
end

-- --- TIDY SELECT LOGIC ---
-- Moved up so it can be used by interpolation logic

local function get_col_index(cols, name)
  for i, v in ipairs(cols) do
    if v == name then return i end
  end
  return nil
end

local function resolve_tidy_select(selector_str, all_columns)
  if not selector_str or selector_str == "" then return {} end

  local selected_cols = {}
  local seen = {}

  for part in string.gmatch(selector_str, "([^,]+)") do
    part = part:match("^%s*(.-)%s*$") -- trim

    -- 1. Range (start:end)
    local start_col, end_col = part:match("^([%w_]+):([%w_]+)$")
    if start_col and end_col then
      local idx_start = get_col_index(all_columns, start_col)
      local idx_end = get_col_index(all_columns, end_col)

      if idx_start and idx_end then
        local step = 1
        if idx_start > idx_end then step = -1 end
        for i = idx_start, idx_end, step do
          local col = all_columns[i]
          if not seen[col] then
            table.insert(selected_cols, col)
            seen[col] = true
          end
        end
      end

    -- 2. Functions (starts_with, etc.)
    else
      local func, arg = part:match("^([%w_]+)%(['\"](.+)['\"]%)$")

      if func then
        for _, col in ipairs(all_columns) do
          local match = false
          if func == "starts_with" then
            if col:find("^" .. arg) then match = true end
          elseif func == "ends_with" then
            if col:find(arg .. "$") then match = true end
          elseif func == "contains" then
            if col:find(arg, 1, true) then match = true end
          elseif func == "matches" then
            if col:find(arg) then match = true end
          end

          if match and not seen[col] then
            table.insert(selected_cols, col)
            seen[col] = true
          end
        end

      -- 3. Literal Name
      else
        if get_col_index(all_columns, part) then
           if not seen[part] then
             table.insert(selected_cols, part)
             seen[part] = true
           end
        end
      end
    end
  end

  return selected_cols
end


-- =============================================================================
-- 2. INTERPOLATION LOGIC (Enhanced)
-- =============================================================================

-- Helper: Extract all column names used in a template string
-- Now supports tidy select syntax inside {}
local function extract_used_cols(template, all_columns)
  local cols = {}
  for inner in template:gmatch("{(.-)}") do
    -- Check for separator syntax: { selector | separator }
    local selector = inner:match("^(.-)%s*|") or inner
    selector = selector:match("^%s*(.-)%s*$") -- trim

    local resolved = resolve_tidy_select(selector, all_columns)
    for _, c in ipairs(resolved) do
      table.insert(cols, c)
    end
  end
  return cols
end

-- String Interpolation Helper
-- Replaces {selector | sep} with joined values
local function interpolate_str(template, row_map, all_columns)
  local res = template:gsub("{(.-)}", function(inner)

    -- 1. Parse Syntax: { selector | separator }
    -- Default separator is space if not provided
    local selector = inner
    local separator = " "

    local s, sep = inner:match("^(.-)%s*|%s*(.*)$")
    if s then
      selector = s
      separator = sep
    end

    selector = selector:match("^%s*(.-)%s*$") -- trim

    -- 2. Resolve Columns
    local cols = resolve_tidy_select(selector, all_columns)

    -- 3. Collect Values (Skip NAs)
    local values = {}
    for _, col_name in ipairs(cols) do
      local val = row_map[col_name]
      if not is_na(val) then
        table.insert(values, tostring(val))
      end
    end

    -- 4. Join
    return table.concat(values, separator)
  end)
  return res
end


-- =============================================================================
-- 3. MAIN LOGIC
-- =============================================================================
local function generate_cv_section(args, kwargs, meta)
  -- 1. Required Arguments
  local sheet = get_arg(kwargs, "sheet", "")
  local func  = get_arg(kwargs, "func", "")

  if sheet == "" or func == "" then return pandoc.Strong(pandoc.Str("Missing sheet/func")) end

  -- 2. Load Data Source
  local cv_data_source = nil
  if meta.cv_data and meta.cv_data[sheet] then
    cv_data_source = meta.cv_data
  else
    local json_data = read_cv_data_json()
    if json_data and json_data.cv_data then
      cv_data_source = json_data.cv_data
    end
  end

  if not cv_data_source or not cv_data_source[sheet] then
     return pandoc.Strong(pandoc.Str("Sheet not found"))
  end

  local rows_raw = unwrap(cv_data_source[sheet])
  local rows = (pandoc.utils.type(rows_raw) == "MetaList" or (type(rows_raw)=="table" and rows_raw[1])) and rows_raw or {rows_raw}

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  -- ---------------------------------------------------------------------------
  -- PARSE CONFIGURATION
  -- ---------------------------------------------------------------------------

  -- Get all available columns from first row for Tidy Select resolution
  local all_columns = {}
  for _, field in ipairs(rows[1]) do
    if field.key then table.insert(all_columns, field.key) end
  end

  -- A. Parse 'pos-X' arguments
  local mapping_templates = {}
  local max_pos_index = -1

  for k, v in pairs(kwargs) do
    local idx_str = k:match("^pos%-(%d+)$")
    if idx_str then
      local idx = tonumber(idx_str)
      mapping_templates[idx] = pandoc.utils.stringify(v)
      if idx > max_pos_index then max_pos_index = idx end
    end
  end

  -- B. Parse 'exclude-cols'
  local raw_exclude = get_arg(kwargs, "exclude-cols", "")
  local exclude_cols_list = resolve_tidy_select(raw_exclude, all_columns)
  local exclude_set = {}
  for _, c in ipairs(exclude_cols_list) do exclude_set[c] = true end

  -- C. Identify explicitly consumed columns via 'pos-X'
  local explicit_consumed_global = {}

  for _, tmpl in pairs(mapping_templates) do
    if tmpl:find("{") then
      -- Pass all_columns to resolve tidy selectors inside templates
      local cols = extract_used_cols(tmpl, all_columns)
      for _, c in ipairs(cols) do explicit_consumed_global[c] = true end
    else
      -- Direct reference check
      if get_col_index(all_columns, tmpl) then
        explicit_consumed_global[tmpl] = true
      end
    end
  end

  -- D. NA Action
  local na_action = get_arg(kwargs, "na_action", "omit")

  local blocks = {}

  -- ---------------------------------------------------------------------------
  -- ROW PROCESSING LOOP
  -- ---------------------------------------------------------------------------
  for _, row_list in ipairs(rows) do

    local row_map = {}
    local ordered_keys = {}

    for _, item in ipairs(row_list) do
      row_map[item.key] = item.value
      table.insert(ordered_keys, item.key)
    end

    local consumed_keys = {}
    for k, _ in pairs(explicit_consumed_global) do consumed_keys[k] = true end
    for k, _ in pairs(exclude_set) do consumed_keys[k] = true end

    local final_args = {}
    local auto_fill_ptr = 1
    local current_slot = 0
    local safety_limit = max_pos_index + #ordered_keys + 10

    while current_slot < safety_limit do

      if current_slot > max_pos_index and auto_fill_ptr > #ordered_keys then
        break
      end

      -- Case A: Explicit Mapping
      if mapping_templates[current_slot] then
        local tmpl = mapping_templates[current_slot]
        local val = ""

        if tmpl:find("{") then
          -- Pass all_columns to support tidy select inside interpolation
          val = interpolate_str(tmpl, row_map, all_columns)
        else
          if row_map[tmpl] then
            val = row_map[tmpl]
             if is_na(val) then
               if na_action == "string" then val = "NA"
               elseif na_action == "keep" then val = "none"
               else val = "" end
             end
          else
            val = tmpl
          end
        end

        table.insert(final_args, clean_string(val))

      -- Case B: Auto-Fill
      else
        local found_next = false
        while auto_fill_ptr <= #ordered_keys do
          local candidate_key = ordered_keys[auto_fill_ptr]
          auto_fill_ptr = auto_fill_ptr + 1

          if not consumed_keys[candidate_key] then
             local val = row_map[candidate_key]

             if is_na(val) then
                if na_action == "string" then
                  table.insert(final_args, clean_string("NA"))
                elseif na_action == "keep" then
                   table.insert(final_args, "none")
                else
                   table.insert(final_args, '""')
                end
             else
               table.insert(final_args, clean_string(val))
             end

             found_next = true
             break
          end
        end

        if not found_next then
          if current_slot > max_pos_index then
            break
          else
            table.insert(final_args, '""')
          end
        end
      end

      current_slot = current_slot + 1
    end

    if #final_args > 0 then
      local call = "#" .. func .. "(" .. table.concat(final_args, ", ") .. ")"
      table.insert(blocks, call)
    end
  end

  if #blocks == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", table.concat(blocks, "\n"))
end

return { ["cv-section"] = generate_cv_section }
