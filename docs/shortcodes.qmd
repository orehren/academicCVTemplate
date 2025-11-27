---
title: "Shortcodes & Content"
---

# Shortcodes Reference

This chapter provides a detailed reference for the shortcodes included in the extension. These tools allow you to dynamically fetch, filter, and format your data from Google Sheets without writing complex code.

## 1. `{{< cv-section >}}` {#sec-cv-section}

The `cv-section` shortcode is the primary tool for building your CV. It acts as an iterator: it fetches a specific dataset (sheet) and processes it row by row, applying a selected Typst layout function to each entry.

### Arguments

| Argument | Description | Default | Example |
| :--- | :--- | :--- | :--- |
| `sheet` | **Required.** The `shortname` of the data sheet to load (defined in your YAML configuration). | - | `sheet="working"` |
| `func` | **Required.** The Typst function to use for rendering. | - | `func="resume-entry"` |
| `exclude-cols` | Columns to exclude from the output. Supports tidy selection. | `""` | `exclude-cols="id, notes"` |
| `combine-cols` | Columns to combine into a single text block. Supports tidy selection. | `""` | `combine-cols="starts_with('detail')"` |
| `combine-as` | The key name for the combined column. | `"details"` | `combine-as="description"` |
| `combine-sep` | Separator string for combined items. | `" "` | `combine-sep="\n"` |
| `combine-prefix` | String to prepend to each combined item. | `""` | `combine-prefix="• "` |
| `column-order` | Explicitly reorder columns. | `""` | `column-order="title=1"` |
| `na-action` | Action for empty values: `"omit"` (remove key), `"keep"` (pass `none`), `"string"` (pass `"NA"`). | `"omit"` | `na-action="keep"` |

### Layout Control

The `cv-section` shortcode acts as a bridge between your data and the layout. Understanding how this bridge works gives you full control over the final document.

1.  **Sequential Processing:** The Typst function you select (e.g., `#resume-entry`) processes the **content of the columns** passed to it in a strict sequence (1st column content -> Left Column, 2nd column content -> Right Column, etc.).
2.  **Column Headers:** The headers in your Google Sheet are critical because they allow the shortcode to identify data. However, they are **not** displayed in the final PDF. They are only used to map data to the correct position in the layout sequence.

You can control this mapping using `column-order` or `combine-cols`.

#### Examples

**1. Basic Reordering (`column_order`)**
Suppose your sheet has `Title`, `Location`, `Date`, but the layout expects `Date` first.
```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
    column-order="Date=1, Title=2, Location=3" 
>}}
```

**2. Partial Reordering (Fill-up)**
You only need to specify the columns that must be moved. The rest will fill in the remaining slots in their original order.
```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
    column-order="Date=1" 
>}}
```

**3. Combining Columns (`combine_cols`)**
Use Tidy Select helpers to merge multiple "detail" columns into a single bulleted list.
```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
    combine-cols="starts_with('detail')" 
    combine-as="description" 
    combine-prefix="• " 
    combine-sep="\n" 
>}}
```

### Tidy Selection Helpers

For arguments like `exclude_cols` and `combine_cols`, you can use these helper functions to select multiple columns at once:

*   `starts_with("prefix")`: Selects columns starting with the prefix (e.g., `starts_with("detail")`).
*   `ends_with("suffix")`: Selects columns ending with the suffix.
*   `contains("string")`: Selects columns containing the substring.
*   `matches("pattern")`: Selects columns matching a Lua pattern.
*   `col_a:col_b`: Selects a range of columns from `col_a` to `col_b` (inclusive).

## 2. `{{< publication-list >}}` {#sec-publication-list}

This shortcode automatically generates a formatted bibliography from one or more bibliography files.

### Arguments

You can configure the bibliography globally in the YAML header (under `publication-list:`) or locally by passing arguments to the shortcode. Local arguments override YAML settings.

| Argument | Description |
| :--- | :--- |
| `bib-file` | Path to the bibliography file(s). You can list multiple files separated by commas (e.g., `"papers.bib, talks.json"`). Formats can be mixed. Defaults to example bibliography files for all formats. |
| `bib-style` | Path to the CSL style file. Defaults to an altered version of the CSL for APA 7. edition. |
| `default-label` | Default Label for uncategorized items (Default: `"Other"`). |
| `group-labels` | Comma-separated key=value string mapping Pandoc types to custom headers (e.g., `"article=Papers, conference=Talks"`). **Note:** Keys must match standard Pandoc types (e.g., `article`, `book`, `conference`). |
| `group-order` | Comma-separated list string defining the sort order. Works exactly like `column-order` (supports indexing). |
| `author-name` | Name to highlight (e.g., "Doe, J."). |
| `highlight-author` | Style for highlighting. Accepts keywords (`bold`, `italic`, `color`) or a custom Typst string pattern (e.g., `"#strong[%s]"`). |

### Configuration & Interaction

The power of this shortcode lies in combining global and local configuration. Local arguments override YAML settings.

#### Example 1: Multiple Lists (Mixed Sources)
Define the style and author globally in YAML, but specify the files locally.

**YAML:**
```yaml
publication-list:
  bib-style: "assets/bib/apa-cv.csl"
  author-name: "Doe, J."
```

**Document:**
```markdown
## Peer-Reviewed Papers
{{< publication-list bib-file="journals.bib, conferences.yaml" >}}

## Presentations
{{< publication-list bib-file="talks.json" >}}
```

#### Example 2: Grouping and Ordering
You can customize the group labels (using Pandoc types) and their order (using names or indices).

```markdown
{{< publication-list 
    group-labels="article=Journal Papers, conference=Conference Proceedings" 
    group-order="Journal Papers=1, Conference Proceedings=2, Other" 
>}}
```
Note that `group-order` uses the **custom labels** you defined.

### Author Highlighting

You can highlight specific author names (e.g., make them bold) in the bibliography.

1.  **Automatic Inference:** If `author-name` is not set, the extension attempts to infer it from the `author.lastname` and `author.firstname` fields in your YAML header.
    *   **Note:** This works best for citation styles that use the standard `Lastname, F.` format.
2.  **Manual Configuration:** Set `author-name` to the exact string produced by the citation style (e.g., "Doe, J." for APA).

**Styling (`highlight-author`):**
You can customize how the name is highlighted using keywords or a custom Typst string.

*   `bold` (Default) -> **Doe, J.**
*   `italic` -> *Doe, J.*
*   `color` -> Uses the document's accent color.
*   **Custom Typst String:** You can pass a raw Typst format string where `%s` represents the author name.
    *   Example: `highlight-author="#text(fill: red, weight: \"bold\")[%s]"`

## 3. Visualizing Skills

To create a graphical representation of your skills (bar charts), you can use the `visualize-skills-list` function as part of the `cv-section` shortcode.

### Prerequisites
Your data sheet must contain a column named `value` with numeric values between `0.0` and `1.0`.

### Usage
Use `cv-section` with `func="visualize-skills-list"`. This will process your skills data and render the visualization.

```markdown
## Skills
{{< cv-section sheet="skills" func="visualize-skills-list" >}}
```
