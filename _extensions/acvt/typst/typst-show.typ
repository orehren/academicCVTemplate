// typst/typst-show.typ
// forwards yaml metadata to typst template

#show heading: set text(..text-style-header)
#show heading.where(level: 1): it => [
    #set block(above: 1.5em, below: 1em)
    #set text(..text-style-header)
    #align(left)[
        #strong[#text(fill: color-accent)[#it.body.text.slice(0, 3)]#it.body.text.slice(3)]
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
