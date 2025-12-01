--- inject_metadata.lua - a Lua filter to automatically inject document metadata
--- into a Typst template as a single dictionary named 'meta-data'.

local M = {}

-- ---
-- 1. CONFIGURATION & HELPER
-- ---

-- Escapes a Lua string for use as a Typst string literal.
---
local function escape_typst_string(s)
  if s == nil then return '""' end
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

---
-- Checks if a Lua table should be treated as a Typst array
-- (i.e., has sequential integer keys starting from 1).
---
local function is_typst_array(tbl)
  -- An empty table is considered an array.
  if next(tbl) == nil then
    return true
  end

  local i = 1
  for k, _ in pairs(tbl) do
    if k ~= i then
      return false -- Found a non-sequential or non-integer key.
    end
    i = i + 1
  end

  return true -- All keys were sequential integers.
end

local to_typ_value -- Pre-declaration for circular dependency

---
-- Formats a Lua table (structured as an array) into a Typst array string literal.
---
local function format_typst_array(tbl)
  local parts = {}
  for _, item in ipairs(tbl) do
    table.insert(parts, to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. (#parts > 0 and "," or "") .. ')'
end

---
-- Formats a Lua table (structured as a dictionary) into a Typst dictionary string literal.
-- Keys are quoted to support hyphens (e.g. "profile-photo").
---
local function format_typst_dictionary(tbl)
  local parts = {}
  for key, item in pairs(tbl) do
    -- Quote keys to handle special characters (like hyphens in 'famous-quote')
    local typst_key = '"' .. tostring(key) .. '"'
    table.insert(parts, typst_key .. ": " .. to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. ')'
end

---
-- Checks if a given Typst value string should be considered "clutter"
-- and filtered out from the final metadata file.
---
local function is_metadata_clutter(typst_str)
  if not typst_str then return true end
  if typst_str == "none" then return true end
  if typst_str == '()' then return true end
  if typst_str == '""' then return true end
  if typst_str:match("^%(%s*%/%*") then return true end

  return false
end

---
-- Recursively converts a Pandoc Meta value or raw Lua table
-- into a Typst value string.
---
to_typ_value = function(val)

  if val == nil then
    return "none"
  end

  local meta_type = pandoc.utils.type(val)

  if meta_type == 'string' then
    return escape_typst_string(val)

  elseif meta_type == 'number' or meta_type == 'boolean' then
    return tostring(val)

  elseif meta_type == 'Inlines' or meta_type == 'Blocks' then
    return escape_typst_string(pandoc.utils.stringify(val))

  elseif type(val) == 'table' then
    if is_typst_array(val) then
      return format_typst_array(val)
    else
      return format_typst_dictionary(val)
    end

  else
    return "(/* Unhandled Pandoc Meta type: " .. meta_type .. " */)"
  end
end

-- ---
-- 2. MAIN FUNCTION (PANDOC FILTER)
-- ---

function M.Pandoc(doc)
  local quarto_meta = doc.meta or {}
  local typst_entries = {}

  for key, value in pairs(quarto_meta) do

    if not (type(key) == 'string' and key ~= "") then
      goto continue
    end

    local typst_val_str = to_typ_value(value)

    -- Optional: Skip empty content to keep the dict clean.
    -- If you prefer having explicit 'none' values in the dict, remove this check.
    if is_metadata_clutter(typst_val_str) then
      goto continue
    end

    -- Add to the dictionary list.
    -- We quote the key (e.g. "profile-photo") to ensure valid Typst syntax for keys with hyphens.
    table.insert(typst_entries, '  "' .. key .. '": ' .. typst_val_str)

    ::continue::
  end


  -- Wrap everything in a single dictionary named 'meta-data'
  local typst_content = "#let meta-data = (\n" .. table.concat(typst_entries, ",\n") .. "\n)\n"

  doc.meta['definitions-01a-injected-meta-data'] = pandoc.RawBlock('typst', typst_content)

  return doc
end

return { { Pandoc = M.Pandoc } }
