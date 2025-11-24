-- =============================================================================
-- 1. UTILS
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
-- 2. CONFIG LOADING
-- =============================================================================
local config = {}

function config.get(kwargs)
  local env_conf = {}
  local global_meta = {}

  local q_info = os.getenv("QUARTO_EXECUTE_INFO")
  if q_info and q_info ~= "" then
    local f = io.open(q_info, "r")
    if f then
      local c = f:read("*a")
      f:close()
      if c then
        local status, decoded = pcall(pandoc.json.decode, c)
        if status and decoded.format and decoded.format.metadata then
          global_meta = decoded.format.metadata
          env_conf = global_meta['publication-list'] or global_meta['publication_list'] or {}
        end
      end
    end
  end

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
    if kwargs[key] then return parser(kwargs[key]) end
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
    local keys_to_check = {"bib_file", "bib_files", "bibfile"}
    for _, key in ipairs(keys_to_check) do
      if kwargs[key] then
        local raw = utils.safe_string(kwargs[key])
        local parts = utils.parse_list_string(raw)
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

  local author_name = fetch("author_name")
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

  local hl_style = fetch("highlight_author") or "bold"
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

  -- KORREKTE CSL TYPEN:
  local standard_group_labels = {
    article = "Journal Article",     -- CSL: article-journal -> article
    conference = "Conference Paper", -- CSL: paper-conference -> conference
    chapter = "Book Chapter",        -- CSL: chapter
    book = "Book",                   -- CSL: book
    thesis = "Thesis",               -- CSL: thesis
    report = "Technical Report",     -- CSL: report
    misc = "Miscellaneous"
  }

  -- Merge-Logik: Erst Standards, dann User-Überschreibungen
  local user_labels = fetch_complex("group_labels", utils.parse_key_val, {})
  local final_group_labels = {}
  for k, v in pairs(standard_group_labels) do final_group_labels[k] = v end
  for k, v in pairs(user_labels) do final_group_labels[k] = v end

  return {
    bib_files = get_bib_files_list(),
    bib_style = fetch("bib_style") or fetch("csl_file"),
    author_name = author_name,
    highlight = highlight_markup,
    group_labels = final_group_labels,
    default_label = fetch("default_label") or "Other",
    group_order = fetch_complex("group_order", utils.parse_list_string, nil),
    func_name = fetch("typst_func_name") or "publication-list"
  }
end

-- =============================================================================
-- 3. CORE LOGIC (PIPELINE)
-- =============================================================================
local core = {}

function core.read_bib_file(path)
  if not utils.file_exists(path) then return {} end

  local ext = path:match("^.+(%..+)$")
  if ext then ext = ext:lower() end

  -- LOGIK FÜR YAML/YML
  if ext == ".yaml" or ext == ".yml" then
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()

    if not content or content == "" then return {} end

    local args = {"-f", "markdown", "-t", "csljson"}
    local input_data = content
    -- Wrapper, falls nur Liste ohne Header
    if not content:match("^%-%-%-") and not content:match("^references:") then
       input_data = "---\nreferences:\n" .. content .. "\n---\n"
    end

    local json_out = pandoc.pipe("pandoc", args, input_data)
    if not json_out or json_out == "" then return {} end

    local status, data = pcall(pandoc.json.decode, json_out)
    if status and type(data) == "table" then return data end
    return {}
  end

  -- LOGIK FÜR ANDERE FORMATE
  local args = {path, "-t", "csljson"}

  if ext == ".json" then
    table.insert(args, "--from=csljson")
  elseif ext == ".bib" then
    table.insert(args, "--from=biblatex")
  elseif ext == ".bibtex" then
    table.insert(args, "--from=bibtex")
  elseif ext == ".xml" then
    table.insert(args, "--from=endnotexml")
  elseif ext == ".ris" then
    table.insert(args, "--from=ris")
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
    -- CLEANING für Labels
    local type_clean = type_raw:gsub("%-journal", ""):gsub("paper%-", "")

    local year = 0
    if ref.issued and ref.issued["date-parts"] and ref.issued["date-parts"][1] then
      year = tonumber(ref.issued["date-parts"][1][1]) or 0
    end
    meta_map[id] = { type = type_clean, year = year }
  end

  local function find_entries(blocks)
    for _, el in ipairs(blocks) do
      if el.t == "Div" and el.identifier:match("^ref%-") then
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
      elseif el.t == "Div" then
        if el.content then find_entries(el.content) end
      end
    end
  end

  find_entries(doc.blocks)
  return entries
end

function core.sort_entries(entries, cfg)
  local group_rank = {}
  if cfg.group_order then
    for i, g in ipairs(cfg.group_order) do group_rank[g] = i end
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
  if kwargs["debug"] == "true" then
    local cfg = config.get(kwargs)
    print("\n[DEBUG publication-list]")
    print("Found Bibliography Files:")
    for i, f in ipairs(cfg.bib_files) do print("  " .. i .. ": " .. f) end
    return pandoc.RawBlock("typst", "// Debug active")
  end

  local cfg = config.get(kwargs)

  if #cfg.bib_files == 0 then
    return pandoc.Strong(pandoc.Str("Error: No 'bib_files' found (checked arguments and YAML)."))
  end
  if not cfg.bib_style then
    return pandoc.Strong(pandoc.Str("Error: 'bib_style' missing."))
  end
  if not utils.file_exists(cfg.bib_style) then
    return pandoc.Strong(pandoc.Str("Error: Style file not found: " .. cfg.bib_style))
  end

  local status, res = pcall(core.run_pandoc_pipeline, cfg.bib_files, cfg.bib_style)
  if not status then return pandoc.Strong(pandoc.Str("Lua Error: " .. tostring(res))) end

  if not res then return pandoc.RawBlock("typst", "#" .. cfg.func_name .. "(())") end

  local entries = core.process_data(res, cfg)
  entries = core.sort_entries(entries, cfg)

  local typst_items = {}
  for _, e in ipairs(entries) do
    local item_str = e.content:gsub("\\", "\\\\"):gsub('"', '\\"')
    table.insert(typst_items, string.format('(label: "%s", item: "%s")', e.label, item_str))
  end

  local body = table.concat(typst_items, ",\n")

  -- FIX für Typst Array Fehler: Zwingendes Komma am Ende
  return pandoc.RawBlock("typst", "#" .. cfg.func_name .. "((\n" .. body .. ",\n))")
end

return { ["publication-list"] = Shortcode }
