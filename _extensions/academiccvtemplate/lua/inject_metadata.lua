--- inject_metadata.lua - a Lua filter to automatically inject document metadata
--- into a Typst template.
---
--- This filter reads all metadata from the YAML header of a .qmd file,
--- converts the key-value pairs into Typst variable definitions
--- (e.g., `#let my_variable = "my_value"`), and writes them to the
--- `typst/metadata.typ` partial file. This makes all YAML metadata
--- available as variables within the Typst templates.
---
--- This process is fully automated, allowing users to add new keys to the
--- YAML header without needing to modify any other code.
---
--- Copyright: © 2025 Oliver Rehren
--- License:   MIT – see LICENSE file for details

local M = {}

local to_typst_value
local stringify_pandoc_object

-- Converts any Pandoc object to a string.
stringify_pandoc_object = function(obj)
  if obj == nil then return nil end
  if pandoc and pandoc.utils and pandoc.utils.stringify then
    return pandoc.utils.stringify(obj)
  else
    if type(obj) == 'table' and obj.t == 'Str' and type(obj.c) == 'string' then return obj.c end
    if type(obj) == 'table' and #obj == 1 and type(obj[1]) == 'table' and obj[1].t == 'Str' and type(obj[1].c) == 'string' then return obj[1].c end
    return tostring(obj)
  end
end

-- Recursively converts a Lua object (from Pandoc metadata) into a Typst value string.
to_typst_value = function(val)
  if val == nil then
    return "none"
  end

  local val_type = pandoc.utils.type(val)

  if val_type == 'string' then
    return '"' .. val:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
  elseif val_type == 'number' or val_type == 'boolean' then
    return tostring(val)
  elseif val_type == 'Inlines' or val_type == 'Blocks' or (type(val) == 'table' and (val.t or (#val > 0 and type(val[1]) == 'table' and val[1].t))) then
    local str_val = stringify_pandoc_object(val)
    return '"' .. str_val:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
  elseif type(val) == 'table' then
    local parts = {}
    local is_array = true
    local i = 1
    for k, _ in pairs(val) do
      if k ~= i then is_array = false; break end
      i = i + 1
    end
    if #val == 0 and next(val) ~= nil then is_array = false end

    if is_array then
      for _, item in ipairs(val) do
        table.insert(parts, to_typst_value(item))
      end
      return '(' .. table.concat(parts, ", ") .. ( #parts > 0 and "," or "" ) .. ')'
    else
      for key, item in pairs(val) do
        local typst_dict_key_str = tostring(key)
        table.insert(parts, typst_dict_key_str .. ": " .. to_typst_value(item))
      end
      return '(' .. table.concat(parts, ", ") .. ')'
    end
  else
    return "(/* Unhandled Lua type: " .. type(val) .. " */)"
  end
end

function M.Pandoc(doc)
  local quarto_meta = doc.meta or {}
  local typst_definitions = {}

  for key, value in pairs(quarto_meta) do
    local typst_var_name = key
    local typst_val_str = to_typst_value(value)

    if type(typst_var_name) == 'string' and typst_var_name ~= "" and
       typst_val_str and typst_val_str ~= "" and typst_val_str ~= "none" and
       not typst_val_str:match("^%(%s*%/%*%s*Unhandled") then
        table.insert(typst_definitions, "#let " .. typst_var_name .. " = " .. typst_val_str)
    end
  end

  local typst_definitions_string = table.concat(typst_definitions, "\n") .. "\n"

  local generated_filename = "_extensions/academiccvtemplate/typst/metadata.typ"
  local file = io.open(generated_filename, "w")
  if file then
    file:write(typst_definitions_string)
    file:close()
  end
  return doc
end

return { { Pandoc = M.Pandoc } }
