#set page(
  paper: "a4",
  margin: (x: 3cm, y: 3cm),
)
#set text(
  font: "New Computer Modern",
)
#set heading(numbering: "1.")

#place(
  top + center,
  float: true,
  scope: "parent",
  clearance: 2em,
  {
    text(size:16pt)[*École Normale Supérieure de Lyon*]
    text[\ *Computer Science Department*]

    v(1cm)
    text(size:24pt)[*Research Internship Report*]
    v(1cm)
    line(length:100%,stroke:(thickness:3pt))
    text(size:20pt,weight: "bold")[Set-theoretic types for Ruby]
    line(length:100%,stroke:(thickness:3pt))

    v(1cm)
    image("ens_lyon.png", width:25%)

    v(1fr)
    text(size:16pt)[Student:\ Zoé Garreau]
    v(1fr)
    text(size:16pt)[Supervised by: \ Giuseppe Castagna]
    v(1fr)

    text[01/06/2026 -- 24/07/2026]
  }
)


#set page(numbering: "1/1")

#outline(title:[Table of contents])

#set par(justify: true)

#show figure.caption: strong
#set figure(
  supplement: "Figure",
  // placement: top
)


= Introduction

= Set-theoretic types and semantic subtyping

= Encoding Ruby in MLSem

We type check Ruby code against its corresponding signature (RBS) file by using the existing MLSem type checker:
first we translate the RBS and Ruby files to MlSem type definitions and expressions respectively, 
then we pass the generated code to the MLSem type checker.

#pagebreak()

== Formalization of the problem

We formalize a fragment of both Ruby and RBS:

#let pat = tiling(
  size: (32pt, 32pt),
  relative: "parent",
  square(
    size: 32.1pt,
    fill: gradient.linear(..color.map.rainbow.map(it => it.desaturate(10%))),
  )
)

#let TODO = {
  let content = strong(underline("TODO", extent: -2pt, stroke: (thickness: 1pt, cap: "round")))

  place(move(dx: -0.5pt, dy: 0.5pt, text(fill: gray, content)))
  text(content, fill: pat)
}

#let r(s) = raw(s, lang: none)
#let new(content) = text(fill: orange, content)
#let later(content) = text(fill: green, content)
#let par = math.class("binary", math.amp.inv)
#let sep = $space space space$

#set raw(lang: "ocaml")


#figure(caption: "Featherweight Ruby")[
  #let r(s) = raw(s, lang: "ruby")
  $
    
    bold("Expression") space
    &#r("E") ::= &&#r("L") | #r("X") | C | #r("self")
              | #r("nil") | #r("E.")x#r("(")overline(#r("E"))#r(")") | #r("X = E") \
    &sep      | &&#r("if E; E else E end") | #r("E;E") | #r("return E")
              | #r("(")overline(#r("E"))#r(")") \
              
    bold("Literal") space
    &#r("L") ::= &&s | n | #r("true") | #r("false") \

    bold("Statement") space
    &#r("S") ::= &&#r("class") C" "(#r("<") C)? " "overline(#r("K")) #r("end") \

    bold("Class statement") space
    &#r("K") ::=&&#r("def") f#r("(")x#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def initialize(")x#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def") #r("self.")f#r("(")x#r(")") #r("E") #r("end") \
    &sep      | &&#r("attr") x \

    bold("Binder") space
    &#r("X") := &&x | #r("@")x
  $
]

#TODO : talk about Featherweight Ruby \


#figure(caption: "Featherweight RBS")[
  #let r(s) = raw(s, lang: "ruby")
  $
    bold("Type") space
    &#r("T") ::= &&#r("B") | #r("L") | C
               | (#r("T | T")) | #r("T") par #r("T")
               | #r("not T") \
               
    bold("Base type") space
    &#r("B") ::= &&#r("Symbol") | #r("Integer") | #r("self") | #r("nil") | #r("bot") \
    bold("Function type") space
    &#r("F") ::= &&#r("(T) -> T") \
    bold("Declaration") space
    &#r("D") ::= &&#r("class") C space (#r("<") C)^? space overline(#r("M")) space #r("end") \
    bold("Member") space
    &#r("M") ::= &&#r("def") x #r("  F") \
    &sep       | &&#r("def initialize: F") \
    &sep       | &&#r("def") #r("self.")x#r(": F") \
    &sep       | &&#r("@")x #r(": T")
  $

  where: #h(16em)
    - #align(left)[$n$ ranges over integers]
    - #align(left)[$x, f$ ranges over variable names]
    - #align(left)[$s$ ranges over symbol names]
    - #align(left)[$C$ ranges over class names]
]




#bibliography("ref.bib")
