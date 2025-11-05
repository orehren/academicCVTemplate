--[[
correct-path.lua – prepends a relative path to the profile-photo metadata field.
]]

function Pandoc (doc)
  local meta = doc.meta
  if meta['profile-photo'] then
    local path = pandoc.utils.stringify(meta['profile-photo'])
    if path ~= "" then
      meta['profile-photo'] = pandoc.MetaInlines(pandoc.Str("../../../" .. path))
    end
  end
  return doc
end
