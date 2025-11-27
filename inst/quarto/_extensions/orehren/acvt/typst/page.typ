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
        #text(fill: color-accent)[#title.slice(0, 3)]#title.slice(3)
    ],
)
