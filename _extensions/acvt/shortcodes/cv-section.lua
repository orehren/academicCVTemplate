-- =============================================================================
-- 1. UTILS
-- =============================================================================

-- Recursively unwrap Pandoc elements to get raw values
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

-- Check if a value is considered NA/Empty
local function is_na(val)
  if not val then return true end
  local s = tostring(val)
  return (s == "" or s == "NA" or s == ".na.character")
end

-- Escape strings for Typst (handle quotes and backslashes)
local function clean_string(val)
  local s = tostring(val)
  -- Normalize fancy quotes
  s = s:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  -- Escape backslashes and double quotes
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. s .. '"'
end

-- Safely retrieve an argument from kwargs
local function get_arg(kwargs, key, default)
  local val = kwargs[key]
  if not val then return default end
  local s = pandoc.utils.stringify(val)
  if s == "" then return default end
  return s
end

-- Read the hidden JSON data file directly
local function read_cv_data_json()
  local f = io.open(".cv_data.json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil end
  -- quarto.json is available in Lua filters running in Quarto context
  return quarto.json.decode(content)
end

-- String Interpolation Helper
-- Replaces placeholders like {ColumnName} with values from the row map.
local function interpolate_str(template, row_map)
  -- Find all placeholders
  local res = template:gsub("{(.-)}", function(col_name)
    -- Trim whitespace in key (e.g., { Name } -> Name)
    col_name = col_name:match("^%s*(.-)%s*$")

    local val = row_map[col_name]

    -- If value is NA or not found, return empty string for interpolation
    if is_na(val) then
      return ""
    else
      return tostring(val)
    end
  end)
  return res
end

-- Helper: Extract all column names used in a template string
local function extract_used_cols(template)
  local cols = {}
  for col_name in template:gmatch("{(.-)}") do
    col_name = col_name:match("^%s*(.-)%s*$")
    table.insert(cols, col_name)
  end
  return cols
end

-- =============================================================================
-- 2. TIDY SELECT LOGIC (For 'exclude-cols')
-- =============================================================================

-- Find index of a column by name
local function get_col_index(cols, name)
  for i, v in ipairs(cols) do
    if v == name then return i end
  end
  return nil
end

-- Resolve selectors like 'starts_with("a"), b:d' into a list of column names
local function resolve_tidy_select(selector_str, all_columns)
  if not selector_str or selector_str == "" then return {} end

  local selected_cols = {}
  local seen = {}

  -- Split by comma, assuming no nested commas in function calls for simplicity
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
-- 3. MAIN LOGIC
-- =============================================================================
local function generate_cv_section(args, kwargs, meta)
  -- 1. Required Arguments
  local sheet = get_arg(kwargs, "sheet", "")
  local func  = get_arg(kwargs, "func", "")

  if sheet == "" or func == "" then return pandoc.Strong(pandoc.Str("Missing sheet/func")) end

  -- 2. Load Data Source
  -- Try meta (injected via filter) first, then fallback to file reading
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

  -- Unwrap data structure
  local rows_raw = unwrap(cv_data_source[sheet])
  local rows = (pandoc.utils.type(rows_raw) == "MetaList" or (type(rows_raw)=="table" and rows_raw[1])) and rows_raw or {rows_raw}

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  -- ---------------------------------------------------------------------------
  -- PARSE CONFIGURATION
  -- ---------------------------------------------------------------------------

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
  -- Retrieve all available column names from the first row for Tidy Select
  local all_columns = {}
  for _, field in ipairs(rows[1]) do
    if field.key then table.insert(all_columns, field.key) end
  end

  local raw_exclude = get_arg(kwargs, "exclude-cols", "")
  local exclude_cols_list = resolve_tidy_select(raw_exclude, all_columns)

  -- Create a set for fast lookup of excluded columns
  local exclude_set = {}
  for _, c in ipairs(exclude_cols_list) do exclude_set[c] = true end

  -- C. Identify explicitly consumed columns via 'pos-X'
  -- These columns should be skipped during the auto-fill phase to avoid duplication.
  local explicit_consumed_global = {}

  for _, tmpl in pairs(mapping_templates) do
    if tmpl:find("{") then
      -- It's a template string (e.g. "{Start} - {End}")
      local cols = extract_used_cols(tmpl)
      for _, c in ipairs(cols) do explicit_consumed_global[c] = true end
    else
      -- It's a direct reference or static text.
      -- We assume if it matches a column name exactly, it consumes that column.
      explicit_consumed_global[tmpl] = true
    end
  end

  -- D. NA Action
  local na_action = get_arg(kwargs, "na_action", "omit")

  local blocks = {}

  -- ---------------------------------------------------------------------------
  -- ROW PROCESSING LOOP
  -- ---------------------------------------------------------------------------
  for _, row_list in ipairs(rows) do

    -- Create map for interpolation: Key -> Val
    local row_map = {}
    -- Keep list of keys in original order for auto-fill iteration
    local ordered_keys = {}

    for _, item in ipairs(row_list) do
      row_map[item.key] = item.value
      table.insert(ordered_keys, item.key)
    end

    -- Track consumed keys for this specific row
    local consumed_keys = {}
    -- Mark global explicit columns as consumed
    for k, _ in pairs(explicit_consumed_global) do consumed_keys[k] = true end
    -- Also mark excluded columns as consumed (so they are skipped in auto-fill)
    for k, _ in pairs(exclude_set) do consumed_keys[k] = true end

    local final_args = {}
    local auto_fill_ptr = 1 -- Pointer to ordered_keys
    local current_slot = 0

    -- Determine loop limit:
    -- We must cover all 'pos-X' slots.
    -- We also want to auto-fill remaining valid columns.
    -- Since we don't know exactly how many valid auto-fill columns remain,
    -- we iterate carefully until both conditions are met.
    local safety_limit = max_pos_index + #ordered_keys + 10 -- Safety buffer

    while current_slot < safety_limit do

      -- Check exit condition:
      -- We are past the highest explicit position AND we have exhausted the auto-fill columns.
      if current_slot > max_pos_index and auto_fill_ptr > #ordered_keys then
        break
      end

      -- Case A: Slot is explicitly defined via 'pos-X'
      if mapping_templates[current_slot] then
        local tmpl = mapping_templates[current_slot]
        local val = ""

        if tmpl:find("{") then
          -- Interpolation logic
          val = interpolate_str(tmpl, row_map)
        else
          -- Direct mapping or static text
          if row_map[tmpl] then
            val = row_map[tmpl] -- It is a column name
            -- Handle NA for direct mapping
             if is_na(val) then
               if na_action == "string" then val = "NA"
               elseif na_action == "keep" then val = "none" -- Typst none
               else val = "" end
             end
          else
            val = tmpl -- It is static text (or unknown column)
          end
        end

        table.insert(final_args, clean_string(val))

      -- Case B: Slot is empty -> Auto-Fill
      else
        -- Find the next column that is not 'consumed'
        local found_next = false
        while auto_fill_ptr <= #ordered_keys do
          local candidate_key = ordered_keys[auto_fill_ptr]
          auto_fill_ptr = auto_fill_ptr + 1

          if not consumed_keys[candidate_key] then
             -- Found a candidate!
             local val = row_map[candidate_key]

             -- Handle NA for auto-fill
             if is_na(val) then
                if na_action == "string" then
                  table.insert(final_args, clean_string("NA"))
                elseif na_action == "keep" then
                   -- For Typst, passing empty string usually renders nothing, which is desired.
                   -- 'none' might be useful depending on Typst function signature.
                   table.insert(final_args, "none")
                else
                   -- Default: "omit" -> empty string
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
          -- No more data available for auto-fill.
          -- If we are past the max_pos_index, we can stop.
          if current_slot > max_pos_index then
            break
          else
            -- If we are before max_pos_index (gap between auto-fill and a later pos-X),
            -- we must fill with empty strings to maintain grid alignment.
            table.insert(final_args, '""')
          end
        end
      end

      current_slot = current_slot + 1
    end

    -- Construct Typst Call
    if #final_args > 0 then
      local call = "#" .. func .. "(" .. table.concat(final_args, ", ") .. ")"
      table.insert(blocks, call)
    end
  end

  if #blocks == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", table.concat(blocks, "\n"))
end

return { ["cv-section"] = generate_cv_section }
