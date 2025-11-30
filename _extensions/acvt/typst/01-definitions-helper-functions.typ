// typst/helper-functions.typ
// Defines helper functions for the template
#import "@preview/fontawesome:0.5.0": *

// --- Helper: Ensure value is always an array ---
#let to-array(val) = if type(val) == array { val } else { (val,) }

// --- Helper: Check if (nested) object has content
#let has-content(dict, ..keys) = {
  let current = dict
  for key in keys.pos() {
    if current == none or type(current) != dictionary or current.at(key, default: none) == none {
      return false
    }
    current = current.at(key)
  }
  return current != ""
}

// Cleans up text potentially escaped from external sources (e.g., Pandoc).
#let unescape_text(text) = {
  let cleaned = text

  // Replaces non-breaking spaces (U+00A0) with regular spaces (U+0020)
  cleaned = cleaned.replace(" ", " ")

  // Removes literal backslashes (e.g., from Pandoc escaping)
  cleaned = cleaned.replace("\\", "")

  // Fixes a hyper-specific artifact (e.g., "end.~NextSentence")
  cleaned = cleaned.replace(".~", ". ")

  return cleaned
}


// Renders the fontawesome icons based on their string identifier.
#let render-icon(icon_string, color) = {
  if icon_string.starts-with("fa ") {
    let parts = icon_string.split(" ")
    if parts.len() == 2 {
      fa-icon(parts.at(1), fill: color)
    } else if parts.len() == 3 and parts.at(1) == "brands" {
      fa-icon(parts.at(2), fa-set: "Brands", fill: color)
    } else {
      assert(false, message: "Invalid FontAwesome icon string format: " + icon_string)
    }
  } else if icon_string.ends-with(".svg") {
    // Fallback for local SVG images
    box(image(icon_string))
  } else {
    assert(false, message: "Invalid icon string (expected 'fa ...' or '*.svg'): " + icon_string)
  }
}

// Renders a single author detail item (e.g., icon + link).
// This is defined as a code block {...} and builds content
// with '+' to create a robust, horizontal, non-breaking layout.
#let render-author-detail(item_data, item_accent_color) = {
  // 1. Get data from the dictionary
  let item_icon = item_data.at("icon", default: none)
  let item_url = item_data.at("url", default: none)
  let item_text_raw = item_data.at("text", default: "")
  let item_text = unescape_text(item_text_raw)

  // 2. Build the icon part
  let icon_part = if item_icon != none {
    render-icon(item_icon, item_accent_color) + h(0.2em)
  } else {
    [] // empty content
  }

  // 3. Build the text part
  let text_part = if item_url != none {
    link(item_url)[#item_text]
  } else if item_text != "" {
    item_text
  } else {
    [] // empty content
  }

  // 4. Return the combined, horizontal content
  return icon_part + text_part
}

// Renders a list of author details, joined by a separator.
#let render-author-details-list(
  list_data,
  item_accent_color,
  separator: h(0.5em) // Default separator is horizontal space
) = {
  // Guard clause for empty or non-existent list
  if list_data != none and list_data.len() > 0 {
    // 1. Map each data item to a rendered, boxed item
    let rendered_items = list_data.map(item =>
      // 'box()' ensures each item is treated as a single layout unit
      box(render-author-detail(item, item_accent_color))
    )
    // 2. Join the list of items with the separator
    rendered_items.join(separator)
  } else {
    [] // Return empty content if list is empty
  }
}

// --- Helper function to find contact info by icon ---
#let find_contact(author, icon_name) = {
  let item = author.contact.find(item => item.icon == icon_name)
  if item != none {
    if "url" in item {
      link(item.url, item.text)
    } else {
      item.text
    }
  } else {
    ""
  }
}

// Groups a list of dictionaries by a specific field.
#let group-by-field(raw_fields_list, grouping_field) = {
  let grouped = (:) // Initialize an empty dictionary

  if raw_fields_list == none or raw_fields_list.len() == 0 {
    return grouped
  }

  for field_entry in raw_fields_list {
    // Get the value of the field we are grouping by
    let current_field = field_entry.at(grouping_field, default: "Uncategorized")

    if not (current_field in grouped) {
      // This is the first entry for this category; create a new array
      grouped.insert(current_field, (field_entry,))
    } else {
      // This category already exists; append to its array
      let existing_list = grouped.at(current_field)
      // Create a new array by concatenating the old list and the new item
      grouped.insert(current_field, existing_list + (field_entry,))
    }
  }

  return grouped
}


// Renders the fontawesome icons based on their string identifier.
#let render-icon(icon_string, color) = {
  if icon_string.starts-with("fa ") {
    let parts = icon_string.split(" ")
    if parts.len() == 2 {
      fa-icon(parts.at(1), fill: color)
    } else if parts.len() == 3 and parts.at(1) == "brands" {
      fa-icon(parts.at(2), fa-set: "Brands", fill: color)
    } else {
      assert(false, message: "Invalid FontAwesome icon string format: " + icon_string)
    }
  } else if icon_string.ends-with(".svg") {
    // Fallback for local SVG images
    box(image(icon_string))
  } else {
    assert(false, message: "Invalid icon string (expected 'fa ...' or '*.svg'): " + icon_string)
  }
}

// Renders a single author detail item (e.g., icon + link).
// This is defined as a code block {...} and builds content
// with '+' to create a robust, horizontal, non-breaking layout.
#let render-author-detail(item_data, item_accent_color) = {
  // 1. Get data from the dictionary
  let item_icon = item_data.at("icon", default: none)
  let item_url = item_data.at("url", default: none)
  let item_text_raw = item_data.at("text", default: "")
  let item_text = unescape_text(item_text_raw)

  // 2. Build the icon part
  let icon_part = if item_icon != none {
    render-icon(item_icon, item_accent_color) + h(0.2em)
  } else {
    [] // empty content
  }

  // 3. Build the text part
  let text_part = if item_url != none {
    link(item_url)[#item_text]
  } else if item_text != "" {
    item_text
  } else {
    [] // empty content
  }

  // 4. Return the combined, horizontal content
  return icon_part + text_part
}

// Renders a list of author details, joined by a separator.
#let render-author-details-list(
  list_data,
  item_accent_color,
  separator: h(0.5em) // Default separator is horizontal space
) = {
  // Guard clause for empty or non-existent list
  if list_data != none and list_data.len() > 0 {
    // 1. Map each data item to a rendered, boxed item
    let rendered_items = list_data.map(item =>
      // 'box()' ensures each item is treated as a single layout unit
      box(render-author-detail(item, item_accent_color))
    )
    // 2. Join the list of items with the separator
    rendered_items.join(separator)
  } else {
    [] // Return empty content if list is empty
  }
}

// --- Helper function to find contact info by icon ---
#let find_contact(author, icon_name) = {
  let item = author.contact.find(item => item.icon == icon_name)
  if item != none {
    if "url" in item {
      link(item.url, item.text)
    } else {
      item.text
    }
  } else {
    ""
  }
}

// Groups a list of dictionaries by a specific field.
#let group-by-field(raw_fields_list, grouping_field) = {
  let grouped = (:) // Initialize an empty dictionary

  if raw_fields_list == none or raw_fields_list.len() == 0 {
    return grouped
  }

  for field_entry in raw_fields_list {
    // Get the value of the field we are grouping by
    let current_field = field_entry.at(grouping_field, default: "Uncategorized")

    if not (current_field in grouped) {
      // This is the first entry for this category; create a new array
      grouped.insert(current_field, (field_entry,))
    } else {
      // This category already exists; append to its array
      let existing_list = grouped.at(current_field)
      // Create a new array by concatenating the old list and the new item
      grouped.insert(current_field, existing_list + (field_entry,))
    }
  }

  return grouped
}
