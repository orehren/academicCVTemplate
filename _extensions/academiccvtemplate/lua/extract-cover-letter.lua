--[[
extract-cover-letter.lua – move the "Coverletter" section into document metadata.
]]
local stringify = (require 'pandoc.utils').stringify
local section_identifiers = {
  coverletter = true,
}
local collected = {}
local toplevel = 6

local function extract_section_content (blocks)
  local body_blocks = {}
  local looking_at_section = false

  for _, block in ipairs(blocks) do
    if block.t == 'Header' and block.level <= toplevel then
      toplevel = block.level
      if section_identifiers[block.identifier] then
        looking_at_section = block.identifier
        collected[looking_at_section] = {}
      else
        looking_at_section = false
        body_blocks[#body_blocks + 1] = block
      end
    elseif looking_at_section then
      if block.t == 'HorizontalRule' then
        looking_at_section = false
      else
        local collect = collected[looking_at_section]
        collect[#collect + 1] = block
      end
    else
      body_blocks[#body_blocks + 1] = block
    end
  end

  return body_blocks
end

Pandoc = function (doc)
  local meta = doc.meta

  local blocks = pandoc.utils.walk_block(
    pandoc.Div(doc.blocks),
    {Blocks = extract_section_content}
  ).content

  for metakey in pairs(section_identifiers) do
    metakey = stringify(metakey)
    local section_content = collected[metakey]
    if not meta[metakey] and section_content and #section_content > 0 then
      local content_as_string = pandoc.write(pandoc.Pandoc(section_content), 'typst')
      meta['cover_letter_content'] = pandoc.MetaString(content_as_string)
    end
  end
  return pandoc.Pandoc(blocks, meta)
end
