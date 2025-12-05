-- =============================================================================
-- 1. CONSTANTS & CONFIGURATION
-- =============================================================================

local table_insert   = table.insert
local string_format  = string.format
local string_gsub    = string.gsub
local pandoc_stringify = pandoc.utils.stringify

-- Typst Configuration
local FORMAT_TYPST          = "typst"
local TYPST_PAGEBREAK_CMD   = "#pagebreak()"
local APPENDIX_HEADER_LEVEL = 1
local APPENDIX_CLASS        = "appendix"

-- Image Configuration
local FIGURE_ID_PREFIX      = "fig-"
local DEFAULT_IMAGE_WIDTH   = "95%"
local DEFAULT_IMAGE_ALIGN   = "center"

-- Single-pass substitution table for Typst string escaping
local TYPST_ESCAPE_MAP = {
  ["\\"] = "\\\\",
  ['"']  = '\\"'
}


-- =============================================================================
-- 2. CORE UTILITIES
-- =============================================================================

local function safely_convert_to_string(input_object)
  if input_object == nil then return "" end
  local status, result = pcall(pandoc_stringify, input_object)
  return status and result or tostring(input_object)
end

local function file_exists_on_disk(file_path)
  local file_handle = io.open(file_path, "r")
  if file_handle then
    io.close(file_handle)
    return true
  end
  return false
end

local function generate_typst_figure_id(filename)
  if not filename or filename == "" then return "" end
  local sanitized_name = string_gsub(filename, "[^%w]", "_")
  return FIGURE_ID_PREFIX .. sanitized_name
end

local function escape_text_for_typst(text_to_escape)
  return tostring(text_to_escape):gsub('[\\"]', TYPST_ESCAPE_MAP)
end


-- =============================================================================
-- 3. CONTENT GENERATORS
-- =============================================================================

local function generate_pagebreak_block()
  return pandoc.RawBlock(FORMAT_TYPST, TYPST_PAGEBREAK_CMD)
end

local function generate_appendix_heading_block(index, title)
  local label_text = string_format("Appendix %d: %s", index, title)
  local safe_label = escape_text_for_typst(label_text)

  -- We construct the heading manually using raw Typst syntax instead of
  -- pandoc.Header. This is necessary because Pandoc parses strings containing
  -- colons (e.g., "Appendix 1: Title") as a Sequence of elements rather than
  -- a single Text object. Typst templates expecting a '.text' field on the
  -- heading body will crash if they receive a Sequence. Passing a quoted string
  -- literal forces Typst to treat the content as atomic text.
  local typst_code = string_format('#heading(level: %d, "%s")', APPENDIX_HEADER_LEVEL, safe_label)

  return pandoc.RawBlock(FORMAT_TYPST, typst_code)
end

local function generate_image_paragraph(file_path, caption_text)
  local figure_id = generate_typst_figure_id(file_path)
  local caption_element = { pandoc.Str(caption_text) }

  local image_element = pandoc.Image(
    caption_element,
    file_path,
    "",
    {
      id = figure_id,
      width = DEFAULT_IMAGE_WIDTH,
      fig_align = DEFAULT_IMAGE_ALIGN
    }
  )

  return pandoc.Para(image_element)
end


-- =============================================================================
-- 4. ATTACHMENT PROCESSING
-- =============================================================================

local function process_single_attachment(attachment_entry, index)
  if type(attachment_entry) ~= 'table' then return nil end

  local display_name = safely_convert_to_string(attachment_entry.name)
  local file_path = safely_convert_to_string(attachment_entry.file)

  if file_path == "" or not file_exists_on_disk(file_path) then
    pandoc.stderr:write(string_format("WARNING (embed-attachments): File not found: '%s'. Skipping.\n", file_path))
    return nil
  end

  local content_blocks = {}

  table_insert(content_blocks, generate_pagebreak_block())

  if display_name ~= "" then
    table_insert(content_blocks, generate_appendix_heading_block(index, display_name))
  end

  table_insert(content_blocks, generate_image_paragraph(file_path, display_name))

  return content_blocks
end


-- =============================================================================
-- 5. MAIN ENTRY POINT
-- =============================================================================

function Pandoc(doc)
  local attachment_list = doc.meta.attachments

  if not attachment_list or type(attachment_list) ~= 'table' then
    return doc
  end

  local appendix_counter = 1

  for _, attachment_entry in ipairs(attachment_list) do
    local entry_blocks = process_single_attachment(attachment_entry, appendix_counter)

    if entry_blocks then
      doc.blocks:extend(entry_blocks)
      appendix_counter = appendix_counter + 1
    end
  end

  return doc
end
