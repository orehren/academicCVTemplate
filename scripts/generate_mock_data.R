# scripts/generate_mock_data.R

library(yaml)
library(purrr)

# Helper to create a row in the specific format required by the Lua filters
create_row <- function(...) {
  row_data <- list(...)
  purrr::imap(row_data, function(val, key) {
    list(key = key, value = val)
  }) |> unname()
}

# 1. Research Interests
interests_data <- list(
  create_row(
    label_2 = "Developed learning materials...",
    details_6 = "Developed learning materials for various media literacy training programs...",
    details_7 = "text(size: 8pt)[Developed the final concepts...]"
  ),
  create_row(
    label_2 = "Programmed learning modules...",
    details_6 = "Programmed learning modules for a planned media literacy app.",
    details_7 = "text(size: 8pt)[Completed the initial modules...]"
  )
)

# 2. Working Experiences
working_data <- list(
  create_row(
    start = "10/2018",
    end = "04/2023",
    date = "10/2018 - 04/2023",
    title = "Research Associate & PhD Candidate #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|] #text(size: 10pt, weight: \"regular\", style: \"italic\")[Professorship of Media Psychology]",
    location = "Chemnitz \\ University of Technology",
    description = "Served as Research Associate and Lecturer...",
    details_1 = "Instructed undergraduate and graduate students...",
    details_2 = "Supervised student research groups..."
  ),
  create_row(
    start = "11/2016",
    end = "09/2018",
    date = "11/2016 - 09/2018",
    title = "Graduate Assistant",
    location = "Chemnitz \\ University of Technology",
    description = "Supported Professor Dr. Peter Ohler...",
    details_1 = "Assisted with teaching activities..."
  )
)

# 3. Education
education_data <- list(
  create_row(
    start = "10/2015",
    end = "09/2018",
    title = "Master of Science",
    location = "Chemnitz \\ University of Technology",
    grade = "#text(size: 9pt)[Grade: very good]",
    thesistitle = "Empathy Revisited"
  )
)

# 4. IT Skills (example subset)
skills_data <- list(
  create_row(area = "Statistics", skill = "R / RStudio", value = 0.9, level = "Proficient"),
  create_row(area = "Publishing", skill = "Quarto", value = 0.75, level = "Proficient")
)


final_cv_data <- list(
  interests = interests_data,
  working = working_data,
  education = education_data,
  skills = skills_data
)

output_file <- "_cv_data.yml"
write_yaml(list(cv_data = final_cv_data), output_file)

# Save cache for the pre-render script to pick up
cache_file <- ".cv_cache.rds"
saveRDS(final_cv_data, cache_file)

message(sprintf("Successfully generated mock data in %s and cache in %s", output_file, cache_file))
