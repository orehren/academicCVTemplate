-- =============================================================================
-- 1. UTILITIES
-- =============================================================================
local utils = {}

function utils.safe_string(obj)
  if obj == nil then return "" end
  local status, res = pcall(pandoc.utils.stringify, obj)
  if status then return res end
  return tostring(obj)
end

function utils.trim(s)
  if not s then return nil end
  return s:match("^%s*(.-)%s*$")
end

function utils.fix_quotes(s)
  if not s then return nil end
  s = tostring(s)
  s = s:gsub("“", '"'):gsub("”", '"')
  s = s:gsub("‘", "'"):gsub("’", "'")
  return s
end

function utils.file_exists(path)
  local f = io.open(path, "r")
  if f then io.close(f); return true else return false end
end

function utils.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

function utils.parse_key_val(str)
  local res = {}
  local s = utils.safe_string(str)
  for pair in string.gmatch(s, "([^,]+)") do
    local k, v = pair:match("^%s*([^=]+)=([^=]+)%s*$")
    if k and v then res[utils.trim(k)] = utils.trim(v) end
  end
  return res
end

function utils.parse_list_string(str)
  local res = {}
  local s = utils.safe_string(str)
  for item in string.gmatch(s, "([^,]+)") do
    table.insert(res, utils.trim(item))
  end
  return res
end

-- =============================================================================
-- 2. CONFIGURATION LOADING
-- =============================================================================
local config = {}

-- Reads metadata from the JSON file pointed to by QUARTO_EXECUTE_INFO
-- because 'meta' argument in Lua filters does not contain merged defaults.
local function read_global_metadata()
  local path = os.getenv("QUARTO_EXECUTE_INFO")
  if not path or path == "" then return {} end

  local content = utils.read_file(path)
  if not content or content == "" then return {} end

  local status, res = pcall(pandoc.json.decode, content)
  if status and res and res.format and res.format.metadata then
    return res.format.metadata
  end
  return {}
end

function config.get(kwargs)
  local global_meta = read_global_metadata()
  local env_conf = global_meta['publication-list'] or {}

  local function fetch(key)
    if kwargs[key] then
      local s = utils.safe_string(kwargs[key])
      if utils.trim(s) ~= "" then return utils.trim(s) end
    end
    if env_conf[key] then
      local s = utils.safe_string(env_conf[key])
      if utils.trim(s) ~= "" then return utils.trim(s) end
    end
    return nil
  end

  local function fetch_complex(key, parser, default)
    local arg_val = kwargs[key]
    local arg_str = utils.safe_string(arg_val)
    if arg_val and utils.trim(arg_str) ~= "" then
      return parser(arg_val)
    end

    if env_conf[key] then
      local val = env_conf[key]
      if type(val) == "table" then
        local res = {}
        local is_list = (#val > 0)
        for k, v in pairs(val) do
          if is_list then table.insert(res, utils.safe_string(v))
          else res[utils.safe_string(k)] = utils.safe_string(v) end
        end
        return res
      end
      return parser(val)
    end
    return default
  end

  local function get_bib_files_list()
    local files = {}
    local keys_to_check = {"bib-file"}

    for _, key in ipairs(keys_to_check) do
      local arg_val = kwargs[key]
      local arg_str = utils.safe_string(arg_val)
      if arg_val and utils.trim(arg_str) ~= "" then
         local parts = utils.parse_list_string(arg_str)
         for _, p in ipairs(parts) do table.insert(files, p) end
      end

      if env_conf[key] then
        local val = env_conf[key]
        if type(val) == "table" then
          for _, v in pairs(val) do table.insert(files, utils.safe_string(v)) end
        else
          local parts = utils.parse_list_string(val)
          for _, p in ipairs(parts) do table.insert(files, p) end
        end
      end
    end

    -- to avoid duplicate entries
    local unique_files = {}
    local hash = {}
    for _, v in ipairs(files) do
      if not hash[v] and v ~= "" then
        table.insert(unique_files, v)
        hash[v] = true
      end
    end
    return unique_files
  end

  local author_name = fetch("author-name")
  if not author_name and global_meta.author then
    local ma = global_meta.author
    if type(ma) == "table" and ma.lastname then
       local ln = utils.safe_string(ma.lastname)
       local fn = utils.safe_string(ma.firstname)
       author_name = (fn ~= "") and (ln .. ", " .. fn:sub(1, 1) .. ".") or ln
    else
       author_name = utils.safe_string(ma)
    end
  end

  local hl_style = fetch("highlight-author") or "bold"
  local highlight_markup = "#strong[%s]"
  if hl_style == "bold" then highlight_markup = "#strong[%s]"
  elseif hl_style == "italic" then highlight_markup = "#emph[%s]"
  elseif hl_style == "color" then
    local col = "000000"
    if global_meta.style and global_meta.style['color-accent'] then
       col = utils.safe_string(global_meta.style['color-accent'])
    end
    highlight_markup = '#text(fill: rgb("' .. col .. '"))[%s]'
  elseif hl_style:match("%%s") then
    highlight_markup = utils.fix_quotes(hl_style)
  end

  local standard_group_labels = {
    article = "Journal Article",
    conference = "Conference Paper",
    chapter = "Book Chapter",
    book = "Book",
    thesis = "Thesis",
    report = "Technical Report",
    misc = "Miscellaneous"
  }

  local user_labels = fetch_complex("group-labels", utils.parse_key_val, {})
  local final_group_labels = {}
  for k, v in pairs(standard_group_labels) do final_group_labels[k] = v end
  for k, v in pairs(user_labels) do final_group_labels[k] = v end

  return {
    bib_files = get_bib_files_list(),
    bib_style = fetch("bib-style") or fetch("csl-file"),
    author_name = author_name,
    highlight = highlight_markup,
    group_labels = final_group_labels,
    default_label = fetch("default-label") or "Other",
    group_order = fetch_complex("group-order", utils.parse_list_string, nil),
    func_name = fetch("func-name") or "publication-list"
  }
end

-- =============================================================================
-- 3. PIPELINE LOGIC
-- =============================================================================
local core = {}

-- Handling Format detection to allow mixing of .bib, .json, .xml etc.
function core.read_bib_file(path)
  if not utils.file_exists(path) then return {} end

  local ext = path:match("^.+(%..+)$")
  if ext then ext = ext:lower() end

  -- Special case for YAML: Must be wrapped in dummy markdown to trigger citeproc conversion
  if ext == ".yaml" or ext == ".yml" then
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()

    if not content or content == "" then return {} end

    local args = {"-f", "markdown", "-t", "csljson"}
    local input_data = content
    -- To ensure valid YAML header structure if missing
    if not content:match("^%-%-%-") and not content:match("^references:") then
       input_data = "---\nreferences:\n" .. content .. "\n---\n"
    end

    local json_out = pandoc.pipe("pandoc", args, input_data)
    if not json_out or json_out == "" then return {} end

    local status, data = pcall(pandoc.json.decode, json_out)
    if status and type(data) == "table" then return data end
    return {}
  end

  local args = {path, "-t", "csljson"}
  if ext == ".json" then table.insert(args, "--from=csljson")
  elseif ext == ".bib" then table.insert(args, "--from=biblatex")
  elseif ext == ".bibtex" then table.insert(args, "--from=bibtex")
  elseif ext == ".xml" then table.insert(args, "--from=endnotexml")
  elseif ext == ".ris" then table.insert(args, "--from=ris")
  end

  local json_out = pandoc.pipe("pandoc", args, "")
  if not json_out or json_out == "" then return {} end

  local status, data = pcall(pandoc.json.decode, json_out)
  if status and type(data) == "table" then return data end
  return {}
end

function core.run_pandoc_pipeline(bib_files, csl)
  local all_refs = {}
  local seen_ids = {}

  -- to deduplicate entries from all files
  for _, file in ipairs(bib_files) do
    local refs = core.read_bib_file(file)
    for _, ref in ipairs(refs) do
      if ref.id and not seen_ids[ref.id] then
        table.insert(all_refs, ref)
        seen_ids[ref.id] = true
      end
    end
  end

  if #all_refs == 0 then return nil end

  local merged_json = pandoc.json.encode(all_refs)

  -- Use CSL-JSON input to generate formatted bibliography
  local args = {"--from=csljson", "--to=json", "--citeproc", "--csl=" .. csl}
  local result = pandoc.pipe("pandoc", args, merged_json)

  if not result or result == "" then error("Pandoc returned empty output.") end
  return result
end

function core.process_data(json_str, cfg)
  local doc = pandoc.json.decode(json_str)
  if not doc or not doc.meta or not doc.blocks then return {} end

  local entries = {}
  local meta_map = {}

  local refs = doc.meta.references or {}
  for _, ref in ipairs(refs) do
    local id = utils.safe_string(ref.id)
    local type_raw = utils.safe_string(ref.type)
    local type_clean = type_raw:gsub("%-journal", ""):gsub("paper%-", "")

    local year = 0
    if ref.issued and ref.issued["date-parts"] and ref.issued["date-parts"][1] then
      year = tonumber(ref.issued["date-parts"][1][1]) or 0
    end
    meta_map[id] = { type = type_clean, year = year }
  end

  -- to find all Div blocks containing formatted references
  local function find_entries(blocks)
    for _, el in ipairs(blocks) do
      if el.t == "Div" then
        if el.identifier:match("^ref%-") then
          local id = el.identifier:gsub("^ref%-", "")
          local meta = meta_map[id]
          if meta then
            local entry_doc = pandoc.Pandoc(el.content)
            local typst_code = pandoc.write(entry_doc, "typst")
            typst_code = utils.trim(typst_code)

            if cfg.author_name and cfg.author_name ~= "" then
              local pattern = cfg.author_name:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
              local replacement = string.format(cfg.highlight, cfg.author_name)
              typst_code = typst_code:gsub(pattern, replacement)
            end

            local label = cfg.group_labels[meta.type] or cfg.default_label
            table.insert(entries, { label = label, year = meta.year, content = typst_code })
          end
        else
          if el.content then find_entries(el.content) end
        end
      end
    end
  end

  find_entries(doc.blocks)
  return entries
end

function core.sort_entries(entries, cfg)
  local group_rank = {}

  -- 1. to collect all present labels
  local present_labels_set = {}
  local present_labels_list = {}
  for _, e in ipairs(entries) do
    if not present_labels_set[e.label] then
      present_labels_set[e.label] = true
      table.insert(present_labels_list, e.label)
    end
  end
  table.sort(present_labels_list)

  -- 2. to retain explicit order configuration
  local explicit_ranks = {}
  local config_implicit_list = {}
  local max_idx = 0

  if cfg.group_order and #cfg.group_order > 0 then
    for _, item in ipairs(cfg.group_order) do
      local label, idx_str = item:match("^%s*(.-)%s*=%s*(%d+)%s*$")
      if label and idx_str then
        local idx = tonumber(idx_str)
        explicit_ranks[idx] = label
        if idx > max_idx then max_idx = idx end
      else
        local clean_label = utils.trim(item)
        if clean_label and clean_label ~= "" then
          table.insert(config_implicit_list, clean_label)
        end
      end
    end
  end

  -- 3. to identify labels present in data but missing from config
  local leftovers = {}
  for _, lbl in ipairs(present_labels_list) do
    local is_in_explicit = false
    for _, v in pairs(explicit_ranks) do if v == lbl then is_in_explicit = true break end end

    local is_in_implicit = false
    for _, v in ipairs(config_implicit_list) do if v == lbl then is_in_implicit = true break end end

    if not is_in_explicit and not is_in_implicit then
      table.insert(leftovers, lbl)
    end
  end

  -- 4. to fill gaps in ranking
  local fill_pool = {}
  for _, v in ipairs(config_implicit_list) do table.insert(fill_pool, v) end
  for _, v in ipairs(leftovers) do table.insert(fill_pool, v) end

  local pool_idx = 1
  local rank_counter = 1

  while true do
    if rank_counter > max_idx and pool_idx > #fill_pool then break end

    if explicit_ranks[rank_counter] then
      group_rank[explicit_ranks[rank_counter]] = rank_counter
    else
      if pool_idx <= #fill_pool then
        group_rank[fill_pool[pool_idx]] = rank_counter
        pool_idx = pool_idx + 1
      end
    end
    rank_counter = rank_counter + 1
  end

  table.sort(entries, function(a, b)
    if a.label ~= b.label then
      local ra = group_rank[a.label] or 999
      local rb = group_rank[b.label] or 999
      if ra ~= rb then return ra < rb end
      return a.label < b.label
    end
    return a.year > b.year
  end)
  return entries
end

-- =============================================================================
-- 4. SHORTCODE MAIN
-- =============================================================================
function Shortcode(args, kwargs, meta)
  local cfg = config.get(kwargs)

  if kwargs["debug"] and utils.safe_string(kwargs["debug"]) == "true" then
    print("\n[DEBUG publication-list]")
    for k, v in pairs(cfg) do
      local val = (type(v) == "table") and "table" or tostring(v)
      print(string.format("%-15s: %s", k, val))
    end
    print("[DEBUG END]\n")
    return pandoc.RawBlock("typst", "// Debug active")
  end

  if #cfg.bib_files == 0 then
    return pandoc.Strong(pandoc.Str("Error: 'bib-file' missing or empty."))
  end
  if not cfg.bib_style then
    return pandoc.Strong(pandoc.Str("Error: 'bib-style' missing."))
  end

  for _, f in ipairs(cfg.bib_files) do
    if not utils.file_exists(f) then
      return pandoc.Strong(pandoc.Str("Error: File not found: " .. f))
    end
  end
  if not utils.file_exists(cfg.bib_style) then
    return pandoc.Strong(pandoc.Str("Error: File not found: " .. cfg.bib_style))
  end

  local status, res = pcall(core.run_pandoc_pipeline, cfg.bib_files, cfg.bib_style)

  if not status then
    return pandoc.Strong(pandoc.Str("Lua Error: " .. tostring(res)))
  end

  if not res then
     return pandoc.RawBlock("typst", "#" .. cfg.func_name .. "(())")
  end

  local entries = core.process_data(res, cfg)
  entries = core.sort_entries(entries, cfg)

  local typst_items = {}
  for _, e in ipairs(entries) do
    local item_str = e.content:gsub("\\", "\\\\"):gsub('"', '\\"')
    table.insert(typst_items, string.format('(label: "%s", item: "%s")', e.label, item_str))
  end

  local body = table.concat(typst_items, ",\n")

  -- Trailing comma ensures Typst interprets single-item results as arrays
  local result = "#" .. cfg.func_name .. "((\n" .. body .. ",\n))"

  return pandoc.RawBlock("typst", result)
end

return { ["publication-list"] = Shortcode }
