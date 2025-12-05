-- =============================================================================
-- 1. CONSTANTS & PERFORMANCE
-- =============================================================================

local t_insert = table.insert
local p_write  = pandoc.write
local p_Pandoc = pandoc.Pandoc
local p_Raw    = pandoc.RawBlock

-- Configuration
local TARGET_SECTION_ID = "coverletter"
local TYPST_VAR_NAME    = "cover_letter_content"
local META_INJECTION_KEY = "definitions-01b-injected-cover-letter"
local FORMAT_TYPST      = "typst"


-- =============================================================================
-- 2. PREDICATES (Decision Logic)
-- =============================================================================

-- Checks if a block is the specific header that starts the cover letter
local function is_start_header(block)
  return block.t == "Header" and block.identifier == TARGET_SECTION_ID
end

-- Checks if a block signals the end of the current section
-- (Either a Horizontal Rule or a Header of the same/higher level)
local function is_end_signal(block, current_section_level)
  if block.t == "HorizontalRule" then return true end

  if block.t == "Header" and block.level <= current_section_level then
    return true
  end

  return false
end


-- =============================================================================
-- 3. EXTRACTION ENGINE
-- =============================================================================

local function separate_blocks(all_blocks)
  local main_content = {}
  local extracted_content = {}

  local is_extracting = false
  local section_level = 0

  for _, block in ipairs(all_blocks) do

    -- State Transition: Start Extraction
    if is_start_header(block) then
      is_extracting = true
      section_level = block.level
      -- We do not add the header itself to either list (it is consumed)
      goto continue
    end

    -- State Transition: Stop Extraction
    if is_extracting and is_end_signal(block, section_level) then
      is_extracting = false
      -- The block that ended the section belongs to the main content
      t_insert(main_content, block)
      goto continue
    end

    -- Action: Distribute Block
    if is_extracting then
      t_insert(extracted_content, block)
    else
      t_insert(main_content, block)
    end

    ::continue::
  end

  return main_content, extracted_content
end


-- =============================================================================
-- 4. TYPST GENERATION
-- =============================================================================

local function generate_typst_variable(content_blocks)
  if #content_blocks == 0 then
    return string.format('#let %s = none', TYPST_VAR_NAME)
  end

  -- Convert Pandoc AST blocks to a Typst string
  local doc_fragment = p_Pandoc(content_blocks)
  local typst_body = p_write(doc_fragment, FORMAT_TYPST)

  -- Wrap in a Typst content variable structure
  return string.format('#let %s = [\n%s\n]', TYPST_VAR_NAME, typst_body)
end


-- =============================================================================
-- 5. MAIN ENTRY POINT
-- =============================================================================

function Pandoc(doc)
  -- 1. Separate the cover letter from the rest of the document
  local body_blocks, cover_blocks = separate_blocks(doc.blocks)

  -- 2. Generate the Typst code for the variable
  local typst_code = generate_typst_variable(cover_blocks)

  -- 3. Inject into metadata
  -- This makes the content available to the Typst template without printing it directly
  doc.meta[META_INJECTION_KEY] = p_Raw(FORMAT_TYPST, typst_code)

  -- 4. Update document body (removing the extracted section)
  doc.blocks = body_blocks

  return doc
end
