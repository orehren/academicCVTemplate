---
title: "Shortcodes Reference"
---

This chapter provides a detailed reference for the shortcodes included in the extension. These tools allow you to dynamically fetch, filter, and format your data from Google Sheets or local files without writing complex code.

## 1. `{{< cv-section >}}` {#sec-cv-section}

The `cv-section` shortcode is the primary tool for building your CV. It acts as a bridge between your data and the layout: it fetches a specific dataset (sheet) and processes it row by row, mapping data columns to the arguments of a selected Typst layout function.

### Arguments

| Argument | Description | Default | Example |
| :--- | :--- | :--- | :--- |
| `sheet` | **Required.** The `shortname` of the data sheet to load (defined in your YAML configuration). | - | `sheet="working"` |
| `func` | **Required.** The Typst function to use for rendering. This determines the grid layout. | - | `func="resume-entry"` |
| `pos-<N>` | **The Mapping Engine.** Defines the content for the **Nth** argument (grid position) of the Typst function. Supports string interpolation and **column aggregation** (e.g., `"{starts_with('det') \| , }"`). | - | `pos-0="{Date}"` |
| `exclude-cols` | Columns to exclude from the **Auto-Fill** process. Supports tidy selection helpers. | `""` | `exclude-cols="id, notes"` |
| `na-action` | Action for empty values: `"omit"` (pass empty string), `"keep"` (pass `none`), `"string"` (pass `"NA"`). | `"omit"` | `na-action="string"` |

---

### The Mapping Logic (Hybrid Mode)

The power of `cv-section` lies in its **Hybrid Mapping Logic**. It combines precise control (via `pos-X`) with convenient automation (Auto-Fill).

The logic works slot by slot (Argument 0, Argument 1, Argument 2, ...) for the chosen Typst function:

1.  **Check for Explicit Mapping:** Is `pos-<current_slot>` defined in the shortcode?
    *   **YES:** Use the provided string. You can use **String Interpolation** to combine columns or add static text (e.g., `"{Title} at {Company}"`). The columns used here are marked as "consumed".
    *   **NO:** Switch to **Auto-Fill**. Pick the next available column from your data that hasn't been consumed or excluded yet.

This allows you to customize specific parts of the layout (e.g., combining dates) while letting the rest of the data fill in automatically.

### String Interpolation & Aggregation

When using `pos-<N>`, you can reference column names by wrapping them in curly braces `{}`.

#### 1. Simple Reference & Combination
*   **Simple Reference:** `pos-0="{Location}"` inserts the value of the 'Location' column.
*   **Combination:** `pos-0="{Start} -- {End}"` combines two columns.
*   **Formatting:** `pos-1="**{Title}**"` adds Markdown formatting (if supported) or static text around the value.
*   **Static Text:** `pos-2="Projects"` ignores data columns and passes the static string "Projects".

#### 2. Column Aggregation (The Pipe Syntax)
You can aggregate multiple columns into a single string using **Tidy Selectors** and a **Separator**. This is useful for combining multiple detail columns (e.g., `detail_1`, `detail_2`, `detail_3`) into one block without worrying about empty values.

**Syntax:** `{ <SELECTOR> | <SEPARATOR> }`

*   **Selector:** A column name, a range (`colA:colB`), or a helper function (like `starts_with`).
*   **Separator:** The string used to join the values.

**Behavior:**
*   It finds all columns matching the selector.
*   It filters out empty (`NA`) values automatically.
*   It joins the remaining values using the separator.

**Example:** `"{starts_with('detail') | , }"` joins all detail columns with a comma.

---

### Examples

#### 1. The "Auto-Pilot" (Zero Configuration)
If your spreadsheet columns are already in the correct order for the Typst function (e.g., `Date`, `Title`, `Company`), you don't need any mapping arguments.

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
>}}
```

- **Result:** Arg 0 gets Col 1, Arg 1 gets Col 2, etc.   

#### 2. Reordering & Interpolation

Suppose your data has columns `Start`, `End`, `Job`, `Employer`, but the layout expects the Date (combined) first, then the Job.

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
    pos-0="{Start} -- {End}" 
    pos-1="{Job}"
>}}
```

*   **Slot 0:** Combines 'Start' and 'End'.
*   **Slot 1:** Uses 'Job'.
*   **Slot 2+:** Auto-fills with remaining columns (e.g., 'Employer') automatically.

#### 3. Adding Static Text & Formatting

You can inject labels or format specific fields directly in the shortcode.

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry" 
    pos-1="**{Role}**" 
    pos-2="Team: {TeamName} at {Company}" 
>}}
```

#### 4. Handling Gaps (Skipping Slots)

Sometimes a layout function has a slot you want to leave empty (e.g., a subtitle slot you don't use). You can explicitly set it to an empty string to skip it, or simply map the next slot to a later index.

**Option A: Explicit Empty String**

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry"
    pos-1="{Title}"
    pos-2="" 
>}}
```

**Option B: Jumping Indexes**

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry"
    pos-5="{Description}"
>}}
```

#### 5. Aggregating Columns (Dynamic Lists)

If you have a variable number of detail columns (`detail_1` to `detail_7`) and want to join them with a Typst line break (`\ \`), use the pipe syntax.

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry"
    pos-5="{starts_with('detail') | \\ \\ }"
>}}
```

---

### Tidy Selection Helpers

Both `exclude-cols` and the **interpolation syntax `{...}`** support the following helper functions to select columns dynamically:

*   `starts_with("prefix")`: Selects columns starting with the prefix (e.g., `starts_with("detail")`).
*   `ends_with("suffix")`: Selects columns ending with the suffix.
*   `contains("string")`: Selects columns containing the substring.
*   `matches("pattern")`: Selects columns matching a Lua pattern.
*   `col_a:col_b`: Selects a range of columns from `col_a` to `col_b` (inclusive).    

```markdown
{{< cv-section 
    sheet="working" 
    func="resume-entry"
    exclude-cols="id, notes, starts_with('internal_')"
>}}
```

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
