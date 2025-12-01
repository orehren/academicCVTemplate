--[[
extract-cover-letter.lua – move the "Coverletter" section into document metadata
as a raw typst variable, instead of writing to a file.
]]

local section_identifiers = {
  coverletter = true,
}
local collected_coverletter_blocks = {} -- Hier speichern wir die Blöcke zwischen
local toplevel = 6

---
-- Main state-machine to separate section content from body content.
-- Populates the local 'collected_coverletter_blocks' table.
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
      -- Start collecting -> Reset collection for safety or append? 
      -- Assuming one cover letter section, we can just use the global table.
      return block.identifier 
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

    -- Add to our internal collection instead of a complex table structure
    -- since we only care about 'coverletter' right now.
    if looking_at_section == "coverletter" then
      table.insert(collected_coverletter_blocks, block)
    end
    
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

-- 1. Blocks läuft zuerst: Trennt den Cover Letter vom Rest des Dokuments
function Blocks(blocks)
  return extract_section_content(blocks)
end

-- 2. Pandoc läuft danach: Nimmt die separierten Blöcke und injiziert sie als Variable
function Pandoc(doc)
  local raw_typst_code = ""

  if #collected_coverletter_blocks > 0 then
    -- Konvertiere die gesammelten Blöcke in Typst-Syntax
    local content_as_string = pandoc.write(pandoc.Pandoc(collected_coverletter_blocks), 'typst')
    
    -- Baue die Typst-Variable
    raw_typst_code = '#let cover_letter_content = [\n' .. content_as_string .. '\n]'
  else
    -- Fallback: Leere Variable definieren, damit Typst nicht meckert
    raw_typst_code = '#let cover_letter_content = none'
  end

  -- Injiziere den Code als RawBlock in die Metadaten
  doc.meta['01b-cover-letter-injection'] = pandoc.RawBlock('typst', raw_typst_code)
  
  return doc
end

return {
  { Blocks = Blocks },
  { Pandoc = Pandoc }
}