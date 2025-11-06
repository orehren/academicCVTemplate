--[[
correct-path.lua – prepends a relative path to the profile-photo metadata field.
]]

function Pandoc (doc)
  local meta = doc.meta

  -- Guard Clause 1: does meta entry exist?
  if not meta['profile-photo'] then
    return doc
  end

  local path = pandoc.utils.stringify(meta['profile-photo'])

  -- Guard Clause 2: is entry empty?
  if path == "" then
    return doc
  end

  meta['profile-photo'] = pandoc.MetaInlines(pandoc.Str("../../../" .. path))

  return doc
end
