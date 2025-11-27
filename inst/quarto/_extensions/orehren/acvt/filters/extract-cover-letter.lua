--[[
extract-cover-letter.lua – move the "Coverletter" section into document metadata
and append it to the metadata.typ file.
]]

local section_identifiers = {
  coverletter = true,
}
local collected = {}
local toplevel = 6

local TYPST_METADATA_FILE = quarto.utils.resolve_path("../typst/02-definitions-metadata.typ")


---
-- Handles the side-effect of writing collected blocks to a file.
---
local function write_coverletter_to_typst(content_blocks)
  if not content_blocks or #content_blocks == 0 then
    return
  end

  local content_as_string = pandoc.write(pandoc.Pandoc(content_blocks), 'typst')
  local typst_definition = '#let cover_letter_content = [' .. content_as_string .. ']\n'

  -- "a" = append mode
  local file, err = io.open(TYPST_METADATA_FILE, "a")

  if not file then
    -- 'pandoc.stderr' is used because it's the correct channel
    -- for filter warnings, unlike 'print()'.
    pandoc.stderr:write(
      string.format("WARNING (Lua Filter): Could not open '%s': %s\n", TYPST_METADATA_FILE, err)
    )
    return
  end

  file:write(typst_definition)
  file:close()
end


---
-- Main state-machine to separate section content from body content.
-- Populates the global 'collected' table as a side-effect.
---
local function extract_section_content (blocks)
  local body_blocks = {}
  local looking_at_section = false

  local function process_header(block)
    if block.level > toplevel then
      body_blocks[#body_blocks + 1] = block
      return looking_at_section
    end

    toplevel = block.level

    if section_identifiers[block.identifier] then
      collected[block.identifier] = {}
      return block.identifier -- New state: collecting
    else
      body_blocks[#body_blocks + 1] = block
      return false -- New state: not collecting
    end
  end

  local function process_section_block(block)
    -- A 'HorizontalRule' (---) signals the end of the special section
    if block.t == 'HorizontalRule' then
      return false -- New state: not collecting
    end

    local collect = collected[looking_at_section]
    collect[#collect + 1] = block
    return looking_at_section
  end


  for _, block in ipairs(blocks) do
    if block.t == 'Header' then
      looking_at_section = process_header(block)
    elseif looking_at_section then
      looking_at_section = process_section_block(block)
    else
      body_blocks[#body_blocks + 1] = block
    end
  end

  return body_blocks
end


---
-- PANDOC FILTER DEFINITIONS
---

Pandoc = function (doc)
  return doc
end

Blocks = function (blocks)
  local body_blocks = extract_section_content(blocks)
  write_coverletter_to_typst(collected["coverletter"])
  return body_blocks
end
