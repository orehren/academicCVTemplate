--- inject_metadata.lua - a Lua filter to automatically inject document metadata
--- into a Typst template.
---
--- REFACTORED VERSION (FINAL FIX):
--- - Reverts the core logic check to 'type(val) == "table"',
---   which was the original (and correct) way to catch
---   all table-like structures (MetaList, MetaMap, raw tables).
---   My previous "fix" (meta_type == 'table') was the source of the bug.

local M = {}

-- ---
-- 1. CONFIGURATION & HELPER
-- ---

local TYPST_METADATA_FILE = "_extensions/academiccvtemplate/typst/metadata.typ"

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

---
-- Recursively converts a Pandoc Meta value or raw Lua table
-- into a Typst value string.
---
local function to_typ_value(val)

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
    local parts = {}

    if is_typst_array(val) then
      -- Convert to Typst Array
      for _, item in ipairs(val) do
        table.insert(parts, to_typ_value(item))
      end
      return '(' .. table.concat(parts, ", ") .. (#parts > 0 and "," or "") .. ')'
    else
      -- Convert to Typst Dictionary
      for key, item in pairs(val) do
        local typst_key = tostring(key)
        table.insert(parts, typst_key .. ": " .. to_typ_value(item))
      end
      return '(' .. table.concat(parts, ", ") .. ')'
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
  local typst_definitions = {}

  for key, value in pairs(quarto_meta) do

    if not (type(key) == 'string' and key ~= "") then
      goto continue
    end

    local typst_val_str = to_typ_value(value)

    if not typst_val_str or
       typst_val_str == "none" or
       (typst_val_str == '""' and pandoc.utils.type(value) == 'string') or
       typst_val_str:match("^%(%s*%/%*") then
      goto continue
    end

    table.insert(typst_definitions, "#let " .. key .. " = " .. typst_val_str)

    ::continue::
  end

  local typst_definitions_string = table.concat(typst_definitions, "\n") .. "\n"

  local file, err = io.open(TYPST_METADATA_FILE, "w")
  if file then
    file:write(typst_definitions_string)
    file:close()
  else
    pandoc.stderr:write(
      string.format("WARNING (inject_metadata.lua): Could not write to '%s': %s\n", TYPST_METADATA_FILE, err)
    )
  end

  return doc
end

return { { Pandoc = M.Pandoc } }
