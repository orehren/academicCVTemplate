--[[
embed-attachments.lua - A Lua filter to extract attachment metadata
and append the corresponding files to the end of the document.
]]

function Pandoc(doc)

  -- Helper function to normalize a filename into a Typst-safe figure ID
  -- e.g., "assets/master.svg" -> "fig-assets_master_svg"
  local function normalize_to_id(filename)
    if not filename or filename == "" then
      return ""
    end
    -- Replace all non-alphanumeric characters with underscores
    local sanitized = string.gsub(filename, "[^%w]", "_")
    return "fig-" .. sanitized
  end

  -- Helper function to check if a file exists
  local function check_file_exists(file)
    local file_handle = io.open(file, "r")

    if file_handle then
      file_handle:close()
      return true
    else
      pandoc.stderr:write(string.format("WARNING (Lua Filter): Attachment file not found: %s\n", file))
      return false
    end
  end

  -- Guard Clause 1: Exit silently if 'attachments' metadata is missing
  -- or is not a valid table (which Quarto YAML provides).
  if not doc.meta.attachments or type(doc.meta.attachments) ~= 'table' then
    return doc
  end

  local attachments = doc.meta.attachments

  -- Iterate through the list of attachments
  for i, item in ipairs(attachments) do

    -- Guard Clause 2: Skip any item in the list that is not a table.
    if type(item) ~= 'table' then
      goto continue
    end

    -- --- Main processing path for valid items ---

    -- 1. Insert a format-agnostic pagebreak signal.
    -- This inserts a paragraph with only a Form Feed ("\f") character.
    -- This signal is designed to be caught by Quarto's 'pagebreak.lua'
    -- filter, which runs later and converts it to the correct format
    -- (e.g., #pagebreak() for Typst, \newpage for LaTeX).
    doc.blocks:insert(pandoc.Para(pandoc.Str("\f")))

    -- 2. Extract data from the item
    local name = pandoc.utils.stringify(item.name)
    local file = pandoc.utils.stringify(item.file)

    -- 3. Optionally insert the appendix heading
    if name and name ~= "" then
      local header = pandoc.Header(2, {pandoc.Str(name)}, {class = "appendix"})
      doc.blocks:insert(header)
    end

    -- 4. Optionally insert the image
    if file and file ~= "" then

      -- Guard Clause 3: Use the helper function to check file existence.
      if not check_file_exists(file) then
        goto continue -- Skip to the next item in the 'for' loop
      end

      -- File exists, proceed with image creation
      local fig_id = normalize_to_id(file)
      local caption = { pandoc.Str(name or "") }
      local image = pandoc.Para(
        pandoc.Image(
          caption,
          file,
          "", -- title attribute
          {
            id = fig_id,
            width = "95%",
            fig_align = "center"
          }
        )
      )
      doc.blocks:insert(image)
    end

    -- 'goto' target to skip to the next iteration
    ::continue::
  end

  return doc
end
