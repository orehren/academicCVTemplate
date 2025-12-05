-- =============================================================================
-- 1. PERFORMANCE & CONSTANTS
-- =============================================================================

local t_insert = table.insert
local t_sort   = table.sort
local t_concat = table.concat
local s_match  = string.match
local s_gmatch = string.gmatch
local s_gsub   = string.gsub
local s_format = string.format
local s_lower  = string.lower
local p_type   = pandoc.utils.type
local p_str    = pandoc.utils.stringify
local p_json   = pandoc.json.decode
local p_pipe   = pandoc.pipe

local ENV_QUARTO_INFO = "QUARTO_EXECUTE_INFO"
local PATTERN_TRIM    = "^%s*(.-)%s*$"
local PATTERN_KEYVAL  = "^%s*([^=]+)=([^=]+)%s*$"
local PATTERN_LIST    = "([^,]+)"
local PATTERN_REF_ID  = "^ref%-(.+)$"
local PATTERN_EXT     = "^.+(%..+)$"
local PATTERN_RANK    = "^%s*(.-)%s*=%s*(%d+)%s*$"

local DEFAULT_FUNC    = "publication-list"
local DEFAULT_LABEL   = "Other"
local DEFAULT_HL      = "bold"

local STANDARD_LABELS = {
  article    = "Journal Article",
  conference = "Conference Paper",
  chapter    = "Book Chapter",
  book       = "Book",
  thesis     = "Thesis",
  report     = "Technical Report",
  misc       = "Miscellaneous"
}

-- Optimization: Single-pass substitution table for Typst escaping
local TYPST_ESCAPES = {
  ["\\"] = "\\\\",
  ['"']  = '\\"'
}


-- =============================================================================
-- 2. CORE UTILITIES
-- =============================================================================

local function ensure_string(obj)
  if obj == nil then return "" end
  local status, res = pcall(p_str, obj)
  return status and res or tostring(obj)
end

local function trim_whitespace(s)
  return s and s_match(s, PATTERN_TRIM) or ""
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then io.close(f); return true end
  return false
end

local function read_file_content(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function parse_comma_separated_list(str)
  local res = {}
  local s = ensure_string(str)
  for item in s_gmatch(s, PATTERN_LIST) do
    t_insert(res, trim_whitespace(item))
  end
  return res
end

local function parse_key_value_pairs(str)
  local res = {}
  local s = ensure_string(str)
  for pair in s_gmatch(s, PATTERN_LIST) do
    local k, v = s_match(pair, PATTERN_KEYVAL)
    if k and v then res[trim_whitespace(k)] = trim_whitespace(v) end
  end
  return res
end

local function escape_typst_string(s)
  -- Single-pass replacement for performance and clarity
  return tostring(s):gsub('[\\"]', TYPST_ESCAPES)
end


-- =============================================================================
-- 3. CONFIGURATION ENGINE
-- =============================================================================

local function load_global_metadata()
  local path = os.getenv(ENV_QUARTO_INFO)
  if not path or path == "" then return {} end

  local content = read_file_content(path)
  if not content or content == "" then return {} end

  local status, res = pcall(p_json, content)
  if status and res and res.format and res.format.metadata then
    return res.format.metadata
  end
  return {}
end

local function retrieve_string_config(key, kwargs, global_conf, default)
  if kwargs[key] then
    local s = ensure_string(kwargs[key])
    if trim_whitespace(s) ~= "" then return trim_whitespace(s) end
  end

  if global_conf[key] then
    local s = ensure_string(global_conf[key])
    if trim_whitespace(s) ~= "" then return trim_whitespace(s) end
  end

  return default
end

local function convert_pandoc_map_to_table(tbl)
  local res = {}
  for k, v in pairs(tbl) do
    if type(k) == "number" then
      t_insert(res, ensure_string(v))
    else
      res[ensure_string(k)] = ensure_string(v)
    end
  end
  return res
end

local function retrieve_structured_config(key, kwargs, global_conf, parser, default)
  local arg_val = kwargs[key]
  if arg_val and trim_whitespace(ensure_string(arg_val)) ~= "" then
    return parser(arg_val)
  end

  local env_val = global_conf[key]
  if not env_val then return default end

  if type(env_val) == "table" then
    return convert_pandoc_map_to_table(env_val)
  end

  return parser(env_val)
end

local function collect_files_from_source(source_val, target_list)
  if not source_val then return end

  if type(source_val) == "table" then
    for _, v in pairs(source_val) do t_insert(target_list, ensure_string(v)) end
    return
  end

  for _, f in ipairs(parse_comma_separated_list(source_val)) do
    t_insert(target_list, f)
  end
end

local function aggregate_bibliography_files(kwargs, global_conf)
  local raw_list = {}

  collect_files_from_source(kwargs["bib-file"], raw_list)
  collect_files_from_source(global_conf["bib-file"], raw_list)

  local unique = {}
  local seen = {}
  for _, f in ipairs(raw_list) do
    if f ~= "" and not seen[f] then
      t_insert(unique, f)
      seen[f] = true
    end
  end
  return unique
end

local function determine_author_name(kwargs, global_meta)
  local name = retrieve_string_config("author-name", kwargs, global_meta['publication-list'] or {}, nil)
  if name then return name end

  local auth = global_meta.author
  if not auth then return nil end

  if type(auth) == "table" and auth.lastname then
    local ln = ensure_string(auth.lastname)
    local fn = ensure_string(auth.firstname)
    return (fn ~= "") and (ln .. ", " .. fn:sub(1, 1) .. ".") or ln
  end

  return ensure_string(auth)
end

local function determine_highlight_format(style, accent_color)
  if style == "bold" then return "#strong[%s]" end
  if style == "italic" then return "#emph[%s]" end
  if style == "color" then
    return '#text(fill: rgb("' .. (accent_color or "000000") .. '"))[%s]'
  end
  if s_match(style, "%%s") then
    return style:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  end
  return "#strong[%s]"
end

local function build_configuration_object(kwargs)
  local global_meta = load_global_metadata()
  local pub_conf = global_meta['publication-list'] or {}
  local style_conf = global_meta.style or {}

  local user_labels = retrieve_structured_config("group-labels", kwargs, pub_conf, parse_key_value_pairs, {})
  local labels = {}
  for k, v in pairs(STANDARD_LABELS) do labels[k] = v end
  for k, v in pairs(user_labels) do labels[k] = v end

  local hl_style = retrieve_string_config("highlight-author", kwargs, pub_conf, DEFAULT_HL)

  return {
    bib_files     = aggregate_bibliography_files(kwargs, pub_conf),
    bib_style     = retrieve_string_config("bib-style", kwargs, pub_conf, retrieve_string_config("csl-file", kwargs, pub_conf, nil)),
    author_name   = determine_author_name(kwargs, global_meta),
    highlight_fmt = determine_highlight_format(hl_style, ensure_string(style_conf['color-accent'])),
    group_labels  = labels,
    default_label = retrieve_string_config("default-label", kwargs, pub_conf, DEFAULT_LABEL),
    group_order   = retrieve_structured_config("group-order", kwargs, pub_conf, parse_comma_separated_list, nil),
    func_name     = retrieve_string_config("func-name", kwargs, pub_conf, DEFAULT_FUNC)
  }
end


-- =============================================================================
-- 4. PANDOC PIPELINE
-- =============================================================================

local function convert_yaml_to_csljson(path)
  local content = read_file_content(path)
  if not content or content == "" then return {} end

  local input_data = content
  if not s_match(content, "^%-%-%-") and not s_match(content, "^references:") then
     input_data = "---\nreferences:\n" .. content .. "\n---\n"
  end

  local json_out = p_pipe("pandoc", {"-f", "markdown", "-t", "csljson"}, input_data)
  if not json_out or json_out == "" then return {} end

  local status, data = pcall(p_json, json_out)
  return (status and type(data) == "table") and data or {}
end

local function convert_bib_to_csljson(path, ext)
  local format_flag = "--from=bibtex"
  if ext == ".json" then format_flag = "--from=csljson"
  elseif ext == ".bib" then format_flag = "--from=biblatex"
  elseif ext == ".xml" then format_flag = "--from=endnotexml"
  elseif ext == ".ris" then format_flag = "--from=ris"
  end

  local json_out = p_pipe("pandoc", {path, "-t", "csljson", format_flag}, "")
  if not json_out or json_out == "" then return {} end

  local status, data = pcall(p_json, json_out)
  return (status and type(data) == "table") and data or {}
end

local function parse_bibliography_file(path)
  if not file_exists(path) then return {} end

  local ext = s_match(path, PATTERN_EXT)
  if ext then ext = s_lower(ext) end

  if ext == ".yaml" or ext == ".yml" then
    return convert_yaml_to_csljson(path)
  end
  return convert_bib_to_csljson(path, ext)
end

local function add_reference_if_unique(ref, target_list, seen_ids)
  if not ref.id then return end
  if seen_ids[ref.id] then return end

  t_insert(target_list, ref)
  seen_ids[ref.id] = true
end

local function process_single_bib_file(path, target_list, seen_ids)
  local refs = parse_bibliography_file(path)
  for _, ref in ipairs(refs) do
    add_reference_if_unique(ref, target_list, seen_ids)
  end
end

local function execute_pandoc_citeproc(bib_files, csl_path)
  local all_refs = {}
  local seen_ids = {}

  for _, file in ipairs(bib_files) do
    process_single_bib_file(file, all_refs, seen_ids)
  end

  if #all_refs == 0 then return nil end

  local merged_json = pandoc.json.encode(all_refs)
  local args = {"--from=csljson", "--to=json", "--citeproc", "--csl=" .. csl_path}

  local result = p_pipe("pandoc", args, merged_json)
  if not result or result == "" then error("Pandoc pipeline failed (empty output).") end
  return result
end


-- =============================================================================
-- 5. PROCESSING ENGINE
-- =============================================================================

local function extract_metadata_map(doc_meta)
  local map = {}
  local refs = doc_meta.references or {}

  for _, ref in ipairs(refs) do
    local id = ensure_string(ref.id)
    local type_raw = ensure_string(ref.type)
    local type_clean = type_raw:gsub("%-journal", ""):gsub("paper%-", "")

    local year = 0
    if ref.issued and ref.issued["date-parts"] and ref.issued["date-parts"][1] then
      year = tonumber(ref.issued["date-parts"][1][1]) or 0
    end
    map[id] = { type = type_clean, year = year }
  end
  return map
end

local function apply_author_highlighting(typst_code, author_name, fmt_string)
  if not author_name or author_name == "" then return typst_code end

  local pattern = author_name:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  local replacement = s_format(fmt_string, author_name)

  return typst_code:gsub(pattern, replacement)
end

local function process_reference_div(el, id, meta_map, config, target_list)
  local meta = meta_map[id]
  if not meta then return end

  local entry_doc = pandoc.Pandoc(el.content)
  local typst_code = trim_whitespace(pandoc.write(entry_doc, "typst"))

  typst_code = apply_author_highlighting(typst_code, config.author_name, config.highlight_fmt)

  local label = config.group_labels[meta.type] or config.default_label
  t_insert(target_list, { label = label, year = meta.year, content = typst_code })
end

-- Forward declaration for recursion
local collect_entries_recursive

local function dispatch_div_action(div_el, meta_map, config, target_list)
  local id = s_match(div_el.identifier, PATTERN_REF_ID)

  if id then
    process_reference_div(div_el, id, meta_map, config, target_list)
    return
  end

  if div_el.content then
    collect_entries_recursive(div_el.content, meta_map, config, target_list)
  end
end

collect_entries_recursive = function(blocks, meta_map, config, target_list)
  for _, el in ipairs(blocks) do
    if el.t == "Div" then
      dispatch_div_action(el, meta_map, config, target_list)
    end
  end
end

local function extract_entries_from_pandoc_json(json_str, config)
  local doc = p_json(json_str)
  if not doc or not doc.meta or not doc.blocks then return {} end

  local meta_map = extract_metadata_map(doc.meta)
  local entries = {}

  collect_entries_recursive(doc.blocks, meta_map, config, entries)
  return entries
end


-- =============================================================================
-- 6. SORTING ENGINE
-- =============================================================================

local function parse_single_rank_item(item, ranks, implicit_list, current_max)
  local label, idx_str = s_match(item, PATTERN_RANK)

  if label and idx_str then
    local idx = tonumber(idx_str)
    ranks[idx] = label
    return (idx > current_max) and idx or current_max
  end

  local clean = trim_whitespace(item)
  if clean ~= "" then t_insert(implicit_list, clean) end
  return current_max
end

local function parse_explicit_ranks(order_list)
  local ranks = {}
  local implicit_list = {}
  local max_rank = 0

  if not order_list then return ranks, implicit_list, max_rank end

  for _, item in ipairs(order_list) do
    max_rank = parse_single_rank_item(item, ranks, implicit_list, max_rank)
  end
  return ranks, implicit_list, max_rank
end

local function resolve_label_for_rank(rank, explicit_ranks, implicit_list, implicit_ptr)
  if explicit_ranks[rank] then
    return explicit_ranks[rank], implicit_ptr
  end

  if implicit_ptr <= #implicit_list then
    return implicit_list[implicit_ptr], implicit_ptr + 1
  end

  return nil, implicit_ptr
end

local function calculate_group_ranks(entries, config)
  local group_rank_map = {}

  local present_labels = {}
  for _, e in ipairs(entries) do present_labels[e.label] = true end

  local explicit_ranks, implicit_list, max_rank = parse_explicit_ranks(config.group_order)

  local current_rank = 1
  local implicit_ptr = 1
  local safety_limit = max_rank + #implicit_list + 10

  while current_rank <= safety_limit do
    local label, next_ptr = resolve_label_for_rank(current_rank, explicit_ranks, implicit_list, implicit_ptr)

    if label then
      group_rank_map[label] = current_rank
    end

    implicit_ptr = next_ptr
    current_rank = current_rank + 1
  end

  return group_rank_map
end

local function sort_entries_by_rank_and_year(entries, config)
  local rank_map = calculate_group_ranks(entries, config)

  t_sort(entries, function(a, b)
    if a.label ~= b.label then
      local ra = rank_map[a.label] or 9999
      local rb = rank_map[b.label] or 9999
      if ra ~= rb then return ra < rb end
      return a.label < b.label
    end
    return a.year > b.year
  end)

  return entries
end


-- =============================================================================
-- 7. MAIN ENTRY POINT
-- =============================================================================

local function Shortcode(args, kwargs, meta)
  local config = build_configuration_object(kwargs)

  if kwargs["debug"] == "true" then
    return pandoc.RawBlock("typst", "// Debug: Check console output")
  end

  if #config.bib_files == 0 then
    return pandoc.Strong(pandoc.Str("Error: 'bib-file' missing or empty."))
  end
  if not config.bib_style then
    return pandoc.Strong(pandoc.Str("Error: 'bib-style' missing."))
  end

  for _, f in ipairs(config.bib_files) do
    if not file_exists(f) then return pandoc.Strong(pandoc.Str("Error: File not found: " .. f)) end
  end
  if not file_exists(config.bib_style) then
    return pandoc.Strong(pandoc.Str("Error: File not found: " .. config.bib_style))
  end

  local status, res = pcall(execute_pandoc_citeproc, config.bib_files, config.bib_style)

  if not status then
    return pandoc.Strong(pandoc.Str("Lua Error: " .. tostring(res)))
  end

  if not res then
     return pandoc.RawBlock("typst", "#" .. config.func_name .. "(())")
  end

  local entries = extract_entries_from_pandoc_json(res, config)
  entries = sort_entries_by_rank_and_year(entries, config)

  local typst_items = {}
  for _, e in ipairs(entries) do
    local item_str = escape_typst_string(e.content)
    t_insert(typst_items, s_format('(label: "%s", item: "%s")', e.label, item_str))
  end

  local body = t_concat(typst_items, ",\n")
  local result = "#" .. config.func_name .. "((\n" .. body .. ",\n))"

  return pandoc.RawBlock("typst", result)
end

return { ["publication-list"] = Shortcode }
