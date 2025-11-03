// Some definitions presupposed by pandoc's typst output.
#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

// =============================================
//  TEMPLATE: Quarto Typst Modern-CV (Optimized)
// =============================================
// Version: 1.5
// Author: Oliver Rehren
// Description: An optimized Typst template for academic CVs,
//              addressing font override logic and show rule errors,
//              while preserving the original visual appearance.
// =============================================


// -- 1. Imports --
// ----------------
// #import "@preview/fontawesome:0.5.0": *
#import "_extensions/academiccvtemplate/typst/helper-functions.typ": *
#import "_extensions/academiccvtemplate/typst/metadata.typ": *
#import "_extensions/academiccvtemplate/typst/styling.typ": *
#import "_extensions/academiccvtemplate/typst/partial-functions.typ": *

#set text(..text-style-default)
#set grid(..grid-style-default)
#set table(..table-style-default)
#set par(justify: true, leading: 0.5em)

#set page(
    paper: "a4",
    margin: (x: 2cm, y: 1.5cm),
    header: align(right)[
        #box(width: 1fr, line(length: 100%))
        #set text(..text-style-header)
        #text(fill: color-accent)[Doc]uments of Application
    ],
)

// -- 7. Main Document Function --
// -------------------------------
#let resume(doc) = {

    // --- Local Show Rules ---
    show quote.where(block: true): it => {
        set align(center)
        set text(..text-style-quote)
        let attribution = if it.attribution != none {
          align(end, [\~ #it.attribution \~])
          } else { none }

        block(
            width: 100%, inset: 1em,
            {
                if it.quotes == true { quote(it.body) } else { it.body }
                attribution
            }
        )
    }

    // --- Document Assembly ---
    // -------------------------

    // 1. Render the Title Page
    title-page(author, profile-photo)

    // 2. Set up page settings for the rest of document (page numbering + footer)
    set page(footer: create-footer(author), numbering: "1")
    counter(page).update(1)

    // 3. Display optional quote
    if famous-quote.text != none {
        quote(attribution: famous-quote.attribution, block: true, quotes: true)[#famous-quote.text]
    }

    // 4. Display optional "About Me" section
    if aboutme != none {
        set text(..text-style-aboutme)
        align(center)[#aboutme]
        v(1em)
    }

    doc

}

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

// typst/typst-show.typ
// forwards yaml metadata to typst template


#show heading: set text(..text-style-header)
#show heading.where(level: 1): it => [
    #set block(above: 1.5em, below: 1em)
    #set text(..text-style-header)
    #align(left)[
        #strong[#text(fill: color-accent)[#it.body.text.slice(0, 3)]#text()[#it.body.text.slice(3)]]
        #box(width: 1fr, line(length: 99%))
    ]
]

#show heading.where(level: 2): it => {
    set text(fill: color-nord2, size: font-size-middle, weight: "thin")
    it.body
}

#show heading.where(level: 3): it => {
    set text(size: font-size-small, fill: color-nord3)
    smallcaps[#it.body]
}

#show: resume.with(


)

= Research Interests
<research-interests>
#research-interests(label_1: "#text(fill: rgb(\"5e81ac\"))[Empathy]", details_1: "Dissecting the empathic process in its cognitive, affective and motoric subprocesses.", label_2: "#text(fill: rgb(\"5e81ac\"))[Embodied Digital Technologies]", details_2: "The interaction of (de-)anthropomorphism and empathy in the human robotic interaction and its influence on certain phenomena such as the uncanny valley.", label_3: "#text(fill: rgb(\"5e81ac\"))[Dark Triad]", details_3: "Using dark personality traits to dissect the empathic process.", label_4: "#text(fill: rgb(\"5e81ac\"))[Neurodiversity]", details_4: "Digital Media as a tool to counter the effects of the impaired dopaminerge System in ADHD.", label_5: "#text(fill: rgb(\"5e81ac\"))[Neurodiversity]", details_5: "Facilitating Learning and Social Live of neurodiverse People.", label_6: "#text(fill: rgb(\"5e81ac\"))[Statistics]", details_6: "The application of new methods to reduce statistical biases in science.", label_7: "#text(fill: rgb(\"5e81ac\"))[Data Science]", details_7: "Artificial Intelligence, neural networks and advanced statistical modelling.")
= Working Experiences
<working-experiences>
#resume-entry(date: "04/2020 - 03/2024", title: "Research Associate and PhD Candidate #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|] #text(size: 10pt, weight: \"regular\", style: \"italic\")[CRC Hybrid Societies - Human Minds in Digital Technologies]", location: "Chemnitz \\ University of Technology", description: "Research Associate & PhD Candidate at the Institute for Media Research, worked within Subproject B01 – 'Human Minds in Digital Technologies – Processes and Effects of (De)Anthropomorphism' of the Collaborative Research Centre (CRC) 'Hybrid Societies'. Responsible for the design, implementation, and analysis of laboratory studies for this DFG-funded CRC focused on shaping future hybrid societies.", note_label: "Doctoral Dissertation", note: "Anthropomorphism as an Enhancement of Empathy during humans interaction with embodied digital technologies. (Submissoin scheduled for Oktober 2025)", label_2: "Key Responsibilities \\ and Achievements", details: "· Developed novel methods and experimental designs for research on (de-)anthropomorphism and embodied digital technologies. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Developed a multidimensional anthropomorphism questionnaire.]\\ \\ · Implemented and conducted various experimental studies. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Developed a virtual experimenter using Unity to overcome pandemic-related restrictions on in-person data collection.]\\ \\ · Collaborated with interdisciplinary project groups within the CRC to conduct joint research. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Successfully conducted multiple studies and published findings in peer-reviewed journals.]\\ \\ · Communicated and presented research findings at scientific events and public forums. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Delivered presentations at multiple conferences and scientific events.]\\ \\ · Performed statistical analysis of collected research data. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Achieved a detailed understanding of the psychological processes underlying (de-)anthropomorphism and phenomena such as the Uncanny Valley.]\\ \\ · Authored scientific articles and project reports. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Authored/Co-authored multiple peer-reviewed publications (see Publications section).]")
#resume-entry(date: "10/2018 - 03/2020", title: "Research Associate and PhD Candidate #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|] #text(size: 10pt, weight: \"regular\", style: \"italic\")[Research Project Media Literacy]", location: "Chemnitz \\ University of Technology", description: "Research Associate in the DFG funded research project Media Literacy (Mediale Zeichenkompetenz), responsible for the design, implementation, and analysis of field studies within a collaborative research project between the Professorship of Media Psychology (TU Chemnitz) and the Professorship of Developmental Psychology (JM University of Würzburg), operating at the forefront of research in developmental media psychology.", label_2: "Key Responsibilities \\ and Achievements", details: "· Analyzed longitudinal data from kindergarten field studies and developed learning materials for various media literacy training programs based on the findings. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Developed the final concepts for the individual training programs.]\\ \\ · Programmed learning modules for a planned media literacy app. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Completed the initial modules of the app.]\\ \\ · Planned and conducted workshops for researchers and student assistants on implementing field studies with kindergarten and preschool children. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Successfully trained a qualified research team, enabling effective data collection in kindergartens and preschools.]\\ \\ · Managed various administrative tasks, including project budget administration, recruitment of schools and classes for study participation, and study planning/preparation in coordination with school officials and authorities of the State of Saxony. #text(size: 8pt, weight: \"medium\", style: \"oblique\", fill: rgb(\"5e81ac\"))[Organized and led informational events for kindergartens, schools, and state authorities, resulting in an officially approved list for mandatory participation of recruited institutions.]")
#resume-entry(date: "10/2018 - 04/2023", title: "Research Associate & PhD Candidate #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|] #text(size: 10pt, weight: \"regular\", style: \"italic\")[Professorship of Media Psychology]", location: "Chemnitz \\ University of Technology", description: "Served as Research Associate and Lecturer at the Institute of Media Research, supporting the Bachelor's and Master's programs: 'Media Communication', 'Computational and Communication Science', 'Media Psychology and Instructional Psychology', and 'Digital Media and Cultural Communication'.", label_2: "Key Responsibilities \\ and Achievements", details: "· Instructed undergraduate and graduate students in fundamental concepts and their application within relevant fields, teaching a total of 24 courses across these programs.\\ \\ · Supervised student research groups and a total of 19 Bachelor's theses and 23 Master's theses.\\ \\ · Performed institutional service, including serving on faculty hiring committees, curriculum committees, organizing academic conferences, and contributing to grant writing/funding proposals.")
#resume-entry(date: "11/2016 - 09/2018", title: "Graduate Assistant #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|] #text(size: 10pt, weight: \"regular\", style: \"italic\")[Professorship of Media Psychology]", location: "Chemnitz \\ University of Technology", description: "Supported Professor Dr. Peter Ohler with teaching activities and preliminary work for research projects within the Professorship.", label_2: "Key Responsibilities \\ and Achievements", details: "· Assisted with teaching activities for the 'Research Specialization: Media Psychology' course (Bachelor's program 'Media Communication'), contributing to the successful delivery of the seminar, assuming full teaching responsibility for the two-semester course the following semester.\\ \\ · Programming and implementation of behavioral scripts for the robot Nao, as part of research into toddler robotics and enabling the first successful use of robots in courses and student research at the Institute for Media Research.\\ \\ · Conceptualized and developed the blended learning course 'Scripting for Communication Scientists', which was subsequently implemented at the Institute for Media Research.")
#resume-entry(date: "11/2016 - 09/2018", title: "Graduate Assistant #text(fill: rgb(\"5e81ac\"), weight: \"bold\")[|]  #text(size: 10pt, weight: \"regular\", style: \"italic\")[Faculty of Humanities]", location: "Chemnitz \\ University of Technology", description: "Performed various support tasks for the Institutes of German Studies and Media Research.", label_2: "Key Responsibilities \\ and Achievements", details: "· Administered and redesigned websites for multiple professorships (Prof. Malinowski, Prof. Thielmann, Prof. Fraas) within the Institutes of German & Communication Studies and Media Research.\\ \\ · Developed and Implemented the online information portal for the 'Intercultural German Studies' Master's program.\\ \\ · Managed the migration of the faculty's transcription analysis system from ATLAS.ti to MAXQDA.")
= Education
<education>
#resume-entry(title: "Master of Science, #text(size: 10pt, weight: \"regular\", style: \"italic\")[Media Psychology & Instructional Psychology]", location: "Chemnitz \\ University of Technology", grade: "#text(size: 9pt)[Grade: very good]", thesistype: "Master Thesis", thesistitle: "Empathy Revisited - An empirical evaluation of the process model of empathy based on media mediated stimuli (grade: very good)", notetitle: "Extract of Subjects", note: "#table([· Mediapsychology], [· General Linear Model], [· Multivariate Statistical Methods], 
[· Neurocognition I], [· Neurocognition II], [· Neural Modelling in Psychology], 
[· Advanced Cognition], [· Digital Game Studies], [· Cognitiv Processing of V. E.],  
[· Human Factors], [· Cinemapsychology: Empathy], [· Advanced Emotion & Motivation])")
#resume-entry(title: "Bachelor of Science, #text(size: 10pt, weight: \"regular\", style: \"italic\")[Psychology]", location: "Chemnitz \\ University of Technology", grade: "#text(size: 9pt)[Grade: good]", thesistype: "Bachelor Thesis", thesistitle: "Influence of the vehicle size on speed estimation - an empirical verification of the
Leibowitz-effect (grade: good)")
= Raised Fundings
<raised-fundings>
```r
#| output: asis
#| label: lst-funds

cv_sheets$raised_fundings |>
format_typst_section(
  typst_func = "#resume-entry", 
  exclude_cols = c(start, end)
) |> cat()
```

= Publications List
<publications-list>
#publication-list((
  (label: "Book Chapters", item: "Rehren, O., & Ohler, P. (2025). Enhancing  -  the  of  and the Interplay of Empathy and Anthropomorphism during Human Interaction with Embodied Digital Technologies. In E. Fricke & M. Siefkes (Eds.), . In Review; Stauffenburg Verlag."),
  (label: "Conference Papers", item: "Jahn, K., Rehren, O., Jansen, S., Ohler, P., & Rey, G. D. (2025). Designing Computer-Mediated Communication with Affective Technology to Increase Feedback Acceptance. In B. Meyer, U. Thomas, & O. Kanoun (Eds.),  (Vol. 1). Springer."),
  (label: "Conference Papers", item: "Jansen, S., Rehren, O., Jahn, K., Ohler, P., & Rey, G. D. (2025). Make It More !  about the Anthropomorphic Processes on Empathy. In B. Meyer, U. Thomas, & O. Kanoun (Eds.),  (Vol. 1). Springer."),
  (label: "Conference Papers", item: "Ohler, P., & Rehren, O. (2023). Wenn Du Schon Hässlich Bist, Sei Wenigstens Warmherzig Und Klug. In E. Fricke & M. Meiler (Eds.), . TU Chemnitz."),
  (label: "Conference Papers", item: "Jahn, K., Rehren, O., Schneider, S., Ohler, P., & Rey, G. D. (2022). Emotional  of : . In A. Rosenthal-von der Pütten, M. Elson, & S. Schiffer (Eds.), . RWTH Aachen University. "),
  (label: "Conference Papers", item: "Krabbes, P., Queck, M., Scherf, A., Ohler, P., & Rehren, O. (2022). To Err Makes Human -  Influence of Errors and Speech Parameters on Perceived Humanness of Robots. In A. Rosenthal-von der Pütten, M. Elson, & S. Schiffer (Eds.), . RWTH Aachen University. "),
  (label: "Conference Papers", item: "Rehren, O., Jahn, K., Schneider, S., Forner, L., Rey, G. D., Ohler, P., Rosenthal-von Der Pütten, A., Elson, M., & Schiffer, S. (2022). Creating an Anthropomorphism Questionnaire -  Multidimensional Approach. . 12th Media Psychology Conference 2021 ( 2021). "),
  (label: "Conference Papers", item: "Rehren, O., Jahn, K., Rey, G. D., & Ohler, P. (2022). The  as a Dynamic Anthropomorphism/de-Anthropomorphism Process. In C. Bermeitinger & W. Greve (Eds.), . Pabst Science Publisher."),
  (label: "Conference Papers", item: "Scheller, N., Ohler, P., Rehren, O., Rosenthal-von Der Pütten, A., Elson, M., & Schiffer, S. (2022). Anthropomorphize to  -  Interaction of  and . , pages 115–118. "),
  (label: "Journal Articles", item: "Gaebert, C., Rehren, O., Jansen, S., Jahn, K., Ohler, P., Rey, G. D., & Thomas, U. (2025). Effects of  in  on the  of . , 3714475. "),
  (label: "Journal Articles", item: "Rehren, O., Jansen, S., Seemann, M., & Ohler, P. (2025). Task-Related Errors as a Catalyst for Empathy towards Embodied Pedagogical Agents. , . "),
  (label: "Journal Articles", item: "Salamah, S., Brunnett, G., Bräuer, S., Uhlmann, T., Rehren, O., Jahn, K., Milani, T. L., & Rey, G. D. (2023). :  for . . "),
  (label: "Journal Articles", item: "Rehren, O., Schilling, J., Valtin, G., Jansen, S., Forner, L., Jahn, K., Rey, G. D., & Ohler, P. (n.d.). .")
))
= Institutional Services
<institutional-services>
#resume-entry(title: "Curriculum Commitee Master Program", location: "Chemnitz \\ University of Technology", description: "Member curriculum commitee of the master programm ’Media Psychology and Instructional Psychology’")
#resume-entry(title: "Appointment commitee W2 Professorship", location: "Chemnitz \\ University of Technology", description: "Member appointment commitee Professorship ’Media Communication’")
#resume-entry(title: "Appointment commitee W3 Professorship", location: "Chemnitz \\ University of Technology", description: "Member appointment commitee Professorship ’Human-Machine-Interaction’")
#resume-entry(title: "Appointment commitee W3 Professorship", location: "Chemnitz \\ University of Technology", description: "Member appointment comitee Professorship ’Predictive Analytics’")
= Additional Academic Activity
<additional-academic-activity>
#resume-entry(title: "Conference Organization MediaPsych 2019", location: "Chemnitz \\ University of Technology", description: "Member of the organizing team for the 11.th conference of the German Psychological Society - Division Media Psychology")
#resume-entry(title: "Voluntary Tutor / Teaching Assistant, #text(size: 10pt, weight: \"regular\")[Professorship of Psychology of learning with digital media]", location: "Chemnitz \\ University of Technology", description: "Tutorial 'Statistical Methods and the General Linear Model'")
= Teaching Experiences
<teaching-experiences>
#resume-entry(title: "Lecturer", location: "Chemnitz \\ University of Technology", Professorship: "Professorship of Media Psychology", label_1: "Courses for Bachelor's Progam", ba_courses: "Taught #strong[13 courses] in total within the Bachelor's programs 'Media Communication' and 'Computer Science and Communication Science'. Courses taught include: 'Statistics for Computer Science and Communication Science', 'Quantitative Empirical Social Research', 'Scripting for Communication Scientists', Research Project: 'Measuring Media Literacy', Research Project: 'Toddler Robotics', and Research Project: 'Empathy'.", label_2: "Courses for Master's Program", ma_courses: "Taught #strong[11 courses] in total within the Master's programs 'Media Psychology and Instructional Psychology', 'Digital Media and Communication Cultures', and 'Psychology'. Courses taught include 'Multivariate Statistical Analysis Methods', Research Project: 'Empathy', 'Fundamentals of Media Psychology', 'Digital Games Studies', 'Qualitative Social Research in Social Media', and the Colloquium")
#resume-entry(title: "Supervisor", location: "Chemnitz \\ University of Technology", Professorship: "Professorship of Media Psychology", label_1: "Bachelor's Theses Supervised", ba_courses: "Supervised a total of 19 Bachelor's theses for the Bachelor's program 'Media Communication'.", label_2: "Master's Theses Supervised", ma_courses: "Supervised a total of 23 Master's theses: 16 for the Master's program 'Media Psychology and Instructional Psychology'; 5 for the Master's program 'Digital Media and Communication Cultures'; 1 for the Master's program 'Value Chain Management'; 1 for the Master's program 'Psychology' at the University of Jena (in collaboration with Professor Dr. Rüdiger Trimpop)")
#resume-entry(title: "Teaching Assistant", location: "Chemnitz \\ University of Technology", Professorship: "Professorship of Media Psychology", label_1: "#text()[]", ba_courses: "Supported Professor Dr. Peter Ohler in teaching the undergraduate Research Project \"Toddler Robotics\". Prepared teaching materials and led several class sessions. Provided academic guidance and support to students throughout the semester. Assisted in the administration and grading of the final examination.")
#resume-entry(title: "Tutor (Statistics)", location: "Chemnitz \\ University of Technology", Professorship: "Professorship of learning with digital media", label_1: "#text()[]", ba_courses: "Led weekly tutorial sessions complementing the main statistics lecture \"General Linear Model\" for 12 students. Reviewed key statistical concepts and guided students through practical exercises and problem sets. Addressed student questions and provided clarification on challenging topics. Supported students in preparing for examinations.")
= Training and Professional Development
<training-and-professional-development>
#resume-entry(title: "Mentor Certification Training 'Huckepack Kinderförderung e.V. Chemnitz'", location: "Chemnitz", Description: "Completed comprehensive training program certifying mentors for a project focused on preventing aggressive behavior in preschool children. Included full-day workshops covering key topics such as:", label_1: "#text()[ ]", details: "· Fostering social and emotional competencies in children\\ \\ · Understanding and managing aggressive behavior in preschoolers\\ \\ · Handling difficult situations in working with children\\ \\ · Effective communication and interpersonal skills")
#resume-entry(title: "Professional Development Workshop: Handling Encounters with Xenophobic Parents", location: "Chemnitz", Description: "Attended a full-day workshop focused on strategies for interacting with parents exhibiting xenophobic attitudes.", label_1: "#text()[ ]", details: "")
= Internships
<internships>
#resume-entry(title: "Mentor 'Huckepack Kinderförderung e.V. Chemnitz'", location: "Chemnitz", description: "Project for Mentor-Supported Prevention of Aggressive Behavior in Preschool Children", label_1: "Key Responsibilities \\ and Achievements", details: "· Provided weekly mentoring to two preschool children exhibiting behavioral difficulties, focusing on the development of social and emotional competencies.\\ \\ · Trained social and emotional skills through targeted activities in both one-on-one and small-group settings.\\ \\ · Participated regularly in supervised case seminars for professional reflection and peer consultation.\\ \\ · Conducted developmental review meetings with the children's parents and preschool educators to coordinate support strategies.\\ \\ · Assisted in the project's evaluation process by collecting and analysing data, and documenting case developement.")
#resume-entry(title: "Diagnostical Research Internship 'Huckepack Kinderförderung e.V. Chemnitz'", location: "Chemnitz", description: "Selection diagnostic of preschool children for the prevention program of ’Huckepack Kinderförderung e.V Chemnitz’", label_1: "Key Responsibilities \\ and Achievements", details: "· Completed comprehensive training program on conducting psychological assessments with kindergarten and preschool-aged children.\\ \\ · Planned and administered comprehensive psychological assessments to a total of 60 children across various kindergartens/preschools, utilizing a range of diagnostic instruments/tools.\\ \\ · Conducted informational sessions/meetings with parents, preschool/kindergarten teachers, and caregivers.\\ \\ · Processed and analyzed the collected assessment data.")
= Reviewer
<reviewer>
#resume-entry(outlet: "Journals", details: "· Communication Research Reports\\ · Transactions on Human-Robot Interaction")
#resume-entry(outlet: "Conferences", details: "· International Conference of Media Psychology 2019 (MediaPsych2019)")
= Social Engagement
<social-engagement>
#resume-entry(title: "Volunteer Youth Worker | Häuser der Jugend (Youth Centers)", location: "Hamburg", description: "Volunteered at community youth centers, fostering positive engagement and development through sports for children and adolescents from socially disadvantaged neighborhoods and underprivileged areas.", details: "· Planned and organized a variety of regular sporting activities and athletic events.\\ \\ · Mentoring for various young children and adolescents.")
#resume-entry(title: "Volunteer Handball Coach | Sports Club TV Billstedt", location: "Hamburg", description: "Coached a co-ed (mixed-gender) handball team for children aged 5-9.", details: "· Planned and conducted regular training sessions focusing on fundamental handball skills, teamwork, and sportsmanship.\\ \\ · Managed the team during practices and local games/tournaments.\\ \\ · Fostered an inclusive and positive learning environment for young players.")
= Language Skills
<language-skills>
#visualize-skills-list((
  (area: "Language", skill: "German", value: "1", level: "Native"),
  (area: "Language", skill: "English", value: "0.8", level: "C1"),
  (area: "Language", skill: "Latin", value: "0", level: "Latinum")
))
= Tech Stack
<tech-stack>
#visualize-skills-list((
  (area: "Research", skill: "PsychoPy / E-Prime", value: "0.5", level: "Intermediate"),
  (area: "Research", skill: "SoSci Survey / Lime Survey / Qualtrics", value: "0.9", level: "Expert"),
  (area: "Statistics", skill: "R / RStudio", value: "0.9", level: "Proficient"),
  (area: "Statistics", skill: "SPSS / G*Power", value: "0.5", level: "Intermediate"),
  (area: "Publishing and Data Science", skill: "Quarto", value: "0.75", level: "Proficient"),
  (area: "Publishing and Data Science", skill: "Jupyter", value: "0.5", level: "Intermediate"),
  (area: "Publishing and Data Science", skill: "Overleaf", value: "1", level: "Expert"),
  (area: "Neural Simulation", skill: "Matlab / Oktave", value: "0.5", level: "Intermediate"),
  (area: "Neural Simulation", skill: "ANNarchy / Simbrain / Emergent", value: "0.5", level: "Intermediate"),
  (area: "PKM and Data Mangement", skill: "Git / SVN", value: "0.5", level: "Intermediate"),
  (area: "PKM and Data Mangement", skill: "Obsidian", value: "0.75", level: "Proficient"),
  (area: "Markup Languages", skill: "HTML / CSS / Typst / LaTeX / Markdown", value: "0.75", level: "Proficient"),
  (area: "Programming Languages", skill: "Python", value: "0.5", level: "Intermediate"),
  (area: "Programming Languages", skill: "PHP", value: "0.5", level: "Intermediate"),
  (area: "Programming Languages", skill: "Java", value: "0.5", level: "Intermediate"),
  (area: "Programming Languages", skill: "R Statistic Language", value: "0.9", level: "Proficient")
))
= Employments
<employments>
#resume-entry(title: "Eventmanager, #text(size: 10pt, weight: \"regular\", style: \"italic\")[Eurest c/o Nordex]", location: "Hamburg", description: "Gastronomy", label_1: "Activities (Extract)", details: "· Planning of events (up to 200 participants)\\ \\ · Planning and implementation of caterings\\ \\ · Work Scheduling\\ \\ · Buisness Management")
#resume-entry(title: "Team leader and training manager, #text(size: 10pt, weight: \"regular\", style: \"italic\")[Buhl GPS]", location: "Hamburg", description: "Gastronomy", label_1: "Activities (Extract)", details: "· Planning and implementation of service training\\ \\ · Supervision and management of work assignments\\ \\ · Customer acquisition")
#resume-entry(title: "Different emplyments in gastronomy", location: "Hamburg", details: "· 2007 - 2010: Crew trainer, McDonalds Company\\ \\ · 2003 - 2008: Bar Manager, Stage Entertainment\\ \\ · 2000 - 2003: Crew employee and bar manager, Mövenpick Marché")




