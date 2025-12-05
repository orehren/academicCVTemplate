-- =============================================================================
-- 1. CONSTANTS & PERFORMANCE OPTIMIZATIONS
-- =============================================================================

-- Localizing global functions avoids repeated global table lookups in tight loops,
-- significantly improving performance in Lua.
local t_insert = table.insert
local t_concat = table.concat
local s_match  = string.match
local s_gmatch = string.gmatch
local s_gsub   = string.gsub
local s_find   = string.find
local p_type   = pandoc.utils.type
local p_str    = pandoc.utils.stringify

-- Centralized patterns prevent magic strings scattered throughout the logic.
local PATTERN_POS_ARG       = "^pos%-(%d+)$"
local PATTERN_INTERPOLATION = "{(.-)}"
local PATTERN_PIPE_SYNTAX   = "^(.-)%s*|%s*(.*)$"
local PATTERN_TRIM          = "^%s*(.-)%s*$"
local PATTERN_RANGE         = "^([%w_]+):([%w_]+)$"
local PATTERN_FUNCTION      = "^([%w_]+)%(['\"](.+)['\"]%)$"

local DEFAULT_NA_ACTION = "omit"
local DEFAULT_SEPARATOR = " "


-- =============================================================================
-- 2. TYPE SAFETY & STRING HANDLING
-- =============================================================================

local function extract_pandoc_content(pandoc_obj)
  if pandoc_obj == nil then return nil end

  local obj_type = p_type(pandoc_obj)

  if obj_type == 'MetaList' or obj_type == 'List' then
    local list_content = {}
    for i, item in ipairs(pandoc_obj) do
      list_content[i] = extract_pandoc_content(item)
    end
    return list_content

  elseif obj_type == 'MetaMap' or obj_type == 'Map' or obj_type == 'table' then
    local map_content = {}
    for key, value in pairs(pandoc_obj) do
      map_content[key] = extract_pandoc_content(value)
    end
    return map_content
  end

  return p_str(pandoc_obj)
end

local function is_value_empty_or_na(value)
  if not value then return true end
  local string_val = tostring(value)
  return (string_val == "" or string_val == "NA" or string_val == ".na.character")
end

local function escape_string_for_typst(value)
  -- Typst syntax is sensitive to unescaped quotes and backslashes.
  -- We must sanitize content to prevent compilation errors in the final document.
  return '"' .. tostring(value)
    :gsub("“", '"')
    :gsub("”", '"')
    :gsub("‘", "'")
    :gsub("’", "'")
    :gsub("\\", "\\\\")
    :gsub('"', '\\"') .. '"'
end

local function get_argument_or_default(kwargs, key, default_value)
  local value = kwargs[key]
  if not value then return default_value end

  local string_value = p_str(value)
  if string_value == "" then return default_value end

  return string_value
end

local function load_cached_database()
  local file_handle = io.open(".cv_data.json", "r")
  if not file_handle then return nil end

  local content = file_handle:read("*a")
  file_handle:close()

  if not content or content == "" then return nil end
  return quarto.json.decode(content)
end

local NA_STRATEGIES = {
  string = "NA",
  keep   = nil, -- Returning nil signals the formatter to output the Typst keyword 'none'
  omit   = ""
}

local function resolve_missing_value(strategy_key)
  local result = NA_STRATEGIES[strategy_key]
  -- Fallback ensures robust handling even if configuration is invalid
  if result == nil and strategy_key ~= "keep" then return "" end
  return result
end


-- =============================================================================
-- 3. COLUMN SELECTION ENGINE (Strategy Pattern)
-- =============================================================================

local function find_column_index(available_columns, column_name)
  for index, name in ipairs(available_columns) do
    if name == column_name then return index end
  end
  return nil
end

local function add_if_new(target_list, seen_set, column_name)
  if seen_set[column_name] then return end
  t_insert(target_list, column_name)
  seen_set[column_name] = true
end

local function try_select_range(selector_part, available_columns, result_list, seen_set)
  local start_col, end_col = s_match(selector_part, PATTERN_RANGE)
  if not (start_col and end_col) then return false end

  local idx_start = find_column_index(available_columns, start_col)
  local idx_end   = find_column_index(available_columns, end_col)

  if not (idx_start and idx_end) then return false end

  local step = (idx_start <= idx_end) and 1 or -1
  for i = idx_start, idx_end, step do
    add_if_new(result_list, seen_set, available_columns[i])
  end
  return true
end

local COLUMN_MATCHERS = {
  starts_with = function(col, arg) return s_find(col, "^" .. arg) end,
  ends_with   = function(col, arg) return s_find(col, arg .. "$") end,
  contains    = function(col, arg) return s_find(col, arg, 1, true) end,
  matches     = function(col, arg) return s_find(col, arg) end
}

local function try_select_predicate(selector_part, available_columns, result_list, seen_set)
  local func_name, arg = s_match(selector_part, PATTERN_FUNCTION)
  if not func_name then return false end

  local matcher_function = COLUMN_MATCHERS[func_name]
  if not matcher_function then return false end

  for _, col_name in ipairs(available_columns) do
    if matcher_function(col_name, arg) then
      add_if_new(result_list, seen_set, col_name)
    end
  end
  return true
end

local function try_select_literal(selector_part, available_columns, result_list, seen_set)
  if not find_column_index(available_columns, selector_part) then return false end
  add_if_new(result_list, seen_set, selector_part)
  return true
end

-- Memoization prevents expensive regex re-parsing when the same selector
-- is applied to multiple rows (which is the common case).
local SELECTOR_CACHE = {}

local function resolve_column_selectors(selector_string, available_columns)
  if not selector_string or selector_string == "" then return {} end

  local cache_key = selector_string .. t_concat(available_columns, "|")
  if SELECTOR_CACHE[cache_key] then return SELECTOR_CACHE[cache_key] end

  local selected_columns = {}
  local seen_columns = {}

  for part in s_gmatch(selector_string, "([^,]+)") do
    local clean_part = s_match(part, PATTERN_TRIM)

    -- Chain of Responsibility allows easy extension of selection logic
    local _ = try_select_range(clean_part, available_columns, selected_columns, seen_columns)
           or try_select_predicate(clean_part, available_columns, selected_columns, seen_columns)
           or try_select_literal(clean_part, available_columns, selected_columns, seen_columns)
  end

  SELECTOR_CACHE[cache_key] = selected_columns
  return selected_columns
end


-- =============================================================================
-- 4. TEMPLATE INTERPOLATION ENGINE
-- =============================================================================

local function parse_interpolation_syntax(content_inside_braces)
  local selector_part, separator_part = s_match(content_inside_braces, PATTERN_PIPE_SYNTAX)

  if selector_part then
    return s_match(selector_part, PATTERN_TRIM), separator_part
  end

  return s_match(content_inside_braces, PATTERN_TRIM), DEFAULT_SEPARATOR
end

local function process_template_match(content_inside_braces, available_columns, consumed_map)
  local selector, _ = parse_interpolation_syntax(content_inside_braces)
  local resolved_cols = resolve_column_selectors(selector, available_columns)

  for _, col_name in ipairs(resolved_cols) do
    consumed_map[col_name] = true
  end
end

local function analyze_template_consumption(template_string, available_columns, consumed_map)
  if s_find(template_string, "{") then
    for content in s_gmatch(template_string, PATTERN_INTERPOLATION) do
      process_template_match(content, available_columns, consumed_map)
    end
    return
  end

  if find_column_index(available_columns, template_string) then
    consumed_map[template_string] = true
  end
end

local function identify_consumed_columns(templates, available_columns)
  local consumed_map = {}
  for _, template_string in pairs(templates) do
    analyze_template_consumption(template_string, available_columns, consumed_map)
  end
  return consumed_map
end

local function interpolate_values(template_string, row_data, available_columns)
  return s_gsub(template_string, PATTERN_INTERPOLATION, function(content)
    local selector, separator = parse_interpolation_syntax(content)
    local target_columns = resolve_column_selectors(selector, available_columns)

    local values = {}
    for _, col_name in ipairs(target_columns) do
      local cell_value = row_data[col_name]
      if not is_value_empty_or_na(cell_value) then
        t_insert(values, tostring(cell_value))
      end
    end

    return t_concat(values, separator)
  end)
end


-- =============================================================================
-- 5. CONFIGURATION PARSER
-- =============================================================================

local function parse_positional_argument(arg_name, arg_value, config)
  local position_index = tonumber(s_match(arg_name, PATTERN_POS_ARG))

  if not position_index then return end

  config.templates[position_index] = p_str(arg_value)

  if position_index > config.max_position_index then
    config.max_position_index = position_index
  end
end

local function parse_shortcode_arguments(kwargs, available_columns)
  local config = {
    templates = {},
    max_position_index = -1,
    excluded_columns_set = {},
    na_strategy = get_argument_or_default(kwargs, "na_action", DEFAULT_NA_ACTION)
  }

  for key, value in pairs(kwargs) do
    parse_positional_argument(key, value, config)
  end

  local exclude_string = get_argument_or_default(kwargs, "exclude-cols", "")
  local excluded_list = resolve_column_selectors(exclude_string, available_columns)

  for _, col_name in ipairs(excluded_list) do
    config.excluded_columns_set[col_name] = true
  end

  return config
end


-- =============================================================================
-- 6. ROW PROCESSING (Iterator Pattern)
-- =============================================================================

local function resolve_explicit_template(template_string, context)
  if s_find(template_string, "{") then
    return interpolate_values(template_string, context.row_data, context.available_columns)
  end

  local cell_value = context.row_data[template_string]
  if cell_value then
    if is_value_empty_or_na(cell_value) then
      return resolve_missing_value(context.config.na_strategy)
    end
    return cell_value
  end

  return template_string
end

local function extract_value_if_valid(row_data, column_name, na_strategy)
  local cell_value = row_data[column_name]
  if is_value_empty_or_na(cell_value) then
    return resolve_missing_value(na_strategy)
  end
  return cell_value
end

-- Encapsulating the iteration state in a closure keeps the main processing loop
-- stateless and flat, adhering to the "Never Nesting" philosophy.
local function create_autofill_iterator(context)
  local column_cursor = 1
  local ordered_columns = context.ordered_columns
  local consumed_map = context.consumed_map
  local row_data = context.row_data
  local na_strategy = context.config.na_strategy

  return function()
    while column_cursor <= #ordered_columns do
      local column_name = ordered_columns[column_cursor]
      column_cursor = column_cursor + 1

      if not consumed_map[column_name] then
        return extract_value_if_valid(row_data, column_name, na_strategy)
      end
    end
    return nil -- Signal exhaustion
  end
end

local function format_output_value(raw_value, slot_index, context)
  if raw_value ~= nil then
    return escape_string_for_typst(raw_value)
  end

  -- We must fill gaps in the grid to maintain alignment with the Typst function signature.
  if slot_index <= context.config.max_position_index then
    return '""'
  elseif context.config.na_strategy == "keep" then
    return "none"
  end

  return nil -- Signal to stop processing
end

local function fetch_next_content(slot_index, context, autofill_iterator)
  local template_string = context.config.templates[slot_index]

  if template_string then
    return resolve_explicit_template(template_string, context)
  end

  return autofill_iterator()
end

local function process_single_row(row_item_list, config, global_consumed_map, available_columns)
  local context = {
    row_data = {},
    ordered_columns = {},
    consumed_map = {},
    config = config,
    available_columns = available_columns
  }

  for _, item in ipairs(row_item_list) do
    context.row_data[item.key] = item.value
    t_insert(context.ordered_columns, item.key)
  end

  for k in pairs(global_consumed_map) do context.consumed_map[k] = true end
  for k in pairs(config.excluded_columns_set) do context.consumed_map[k] = true end

  local get_next_autofill = create_autofill_iterator(context)
  local final_arguments = {}
  local current_slot_index = 0
  local safety_limit = config.max_position_index + #context.ordered_columns + 5

  while current_slot_index < safety_limit do
    local raw_value = fetch_next_content(current_slot_index, context, get_next_autofill)

    -- Stop if we have satisfied all explicit templates and run out of auto-fill data.
    if raw_value == nil and current_slot_index > config.max_position_index then
      break
    end

    local formatted_value = format_output_value(raw_value, current_slot_index, context)
    if formatted_value then
      t_insert(final_arguments, formatted_value)
    end

    current_slot_index = current_slot_index + 1
  end

  return final_arguments
end


-- =============================================================================
-- 7. MAIN ENTRY POINT
-- =============================================================================

local function generate_cv_section(args, kwargs, meta)
  local sheet_name = get_argument_or_default(kwargs, "sheet", "")
  local func_name  = get_argument_or_default(kwargs, "func", "")

  if sheet_name == "" or func_name == "" then
    return pandoc.Strong(pandoc.Str("Error: Missing 'sheet' or 'func' argument."))
  end

  -- We prioritize metadata injection (from R) over file reading for speed,
  -- but fallback to JSON for robustness if the filter chain is modified.
  local raw_data_source = nil
  if meta.cv_data and meta.cv_data[sheet_name] then
    raw_data_source = meta.cv_data[sheet_name]
  else
    local json_db = load_cached_database()
    if json_db and json_db.cv_data then
      raw_data_source = json_db.cv_data[sheet_name]
    end
  end

  if not raw_data_source then
    return pandoc.Strong(pandoc.Str("Error: Sheet '" .. sheet_name .. "' not found."))
  end

  local unwrapped_data = extract_pandoc_content(raw_data_source)

  local rows = (p_type(unwrapped_data) == "MetaList" or (type(unwrapped_data)=="table" and unwrapped_data[1]))
               and unwrapped_data or {unwrapped_data}

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  -- Calculating column metadata once per sheet avoids redundant processing in the row loop.
  local available_columns = {}
  for _, field in ipairs(rows[1]) do
    if field.key then t_insert(available_columns, field.key) end
  end

  local config = parse_shortcode_arguments(kwargs, available_columns)
  local global_consumed_map = identify_consumed_columns(config.templates, available_columns)

  local typst_function_calls = {}
  for _, row in ipairs(rows) do
    local arguments_list = process_single_row(row, config, global_consumed_map, available_columns)

    if #arguments_list > 0 then
      local call_string = "#" .. func_name .. "(" .. t_concat(arguments_list, ", ") .. ")"
      t_insert(typst_function_calls, call_string)
    end
  end

  if #typst_function_calls == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", t_concat(typst_function_calls, "\n"))
end

return { ["cv-section"] = generate_cv_section }
