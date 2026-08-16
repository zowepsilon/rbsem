#import "@preview/codly:1.3.0": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#show: codly-init.with()

#codly(
  display-name: false,
)

#set page(
  paper: "a4",
  margin: (x: 3cm, y: 3cm),
)

#set text(
  font: "New Computer Modern",
)
#set heading(numbering: "1.")

#let pat = tiling(
  size: (32pt, 32pt),
  relative: "parent",
  square(
    size: 32.1pt,
    fill: gradient.linear(..color.map.rainbow.map(it => it.desaturate(10%))),
  )
)


#let TODO = box({
  let content = strong(underline("TODO", extent: -2pt, stroke: (thickness: 1pt, cap: "round")))

  place(move(dx: -0.5pt, dy: 0.5pt, text(fill: gray, content)))
  text(content, fill: pat)
})

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

#outline(title: [Table of contents])

#set par(
  justify: true,
)

#show figure.caption: strong
#set figure(
  supplement: "Figure",
  kind: "everything",
  // placement: top
)

= Introduction

Ruby @Ruby is a dynamically-typed programming language.
Although there are several static type checkers for it,
they are unsound, meaning they allow programs that
produce a type error at runtime.
Meanwhile, the theory of set-theoretic types and semantic subtyping
is successfully being used in other dynamic languages such as Elixir and Python.
In this work we specify and prototype the framework for a new type checker for Ruby
based on semantic subtyping. We translate a fragment of Ruby and RBS (Ruby signature language @RBS)
to MLsem code to harness its implementation of set-theoretic types.
This encoding allows us to precisely type Ruby code using union, intersection,
negation types and control flow-sensitive informations.

= Background

Lately, efforts to type dynamic languages have seen sucessful developments. One of the most well-known example is TypeScript @TypeScript, a superset of Javascript with static typing.
Python has an official type checker called mypy @mypy and supports type annotations
meant to be used by external type checkers. Elixir is slowly integrating static typing
into its compiler @CDV23.
All of these type checkers have been widely adopted by their specific user bases.

A critical property of a type system is soundness, which ensures that
the types assigned by the type system correspond to the expected runtime values,
and therefore that operations don't fail at runtime because they provided unexpected
values.

== Ruby & RBS

Ruby is a dynamically typed and object-oriented programming language.
Its main features are classes, modules, mixins and advanced runtime reflection.
The base language has no support for static typing or even type annotation syntax,
but several external static type checkers exist and have seen widespread use
within the Ruby community, foremost Steep @Steep and Sorbet @Sorbet.

Steep is structured around #strong[R]u#strong[B]y #strong[S]ignature files (RBS) @RBS,
Ruby's official format for type signatures: 
it type checks Ruby code against one or several RBS files.
Steep has a nominal type system, featuring gradual typing, union and intersection
types, classes with inheritance and method overloading, and structural interfaces. 
We will be mainly talking about Steep since Sorbet has similar features,
the biggest difference being that it uses inline type annotations instead of RBS files.

The main issue of these type systems is that they are not sound,
because they always treat subclasses as subtypes.
This general issue was first brought up in @BruEtAl96. 
For instance, the following code (using inline signatures and excluding getters for conciseness) is not sound:

#figure(caption: "Unsound example in Steep")[
  ```ruby
  class Point
    #: (Integer, Integer) -> void
    def initialize(x, y)
      @x = x
      @y = y
    end
    #: (self) -> bool
    def equal(other)
      @x == other.x && @y == other.y
    end
  end

  class ColorPoint < Point
    #: (Integer, Integer, String) -> void
    def initialize(x, y, color)
      super(x, y)
      @color = color
    end
    #: (self) -> bool
    def equal(other)
      @x == other.x && @y == other.y && @color == other.color
    end
  end
  ```
]

In this example we defined two classes, `Point` and `ColorPoint`,
the latter inheriting from the former. The `initialize` method is
the constructor called when an instance is created, for instance
when calling #box[`Point.new(12, 67)`]. The `new` class method
of a class takes the same arguments as the constructor and returns
an instance of the class. `@x` represents an instance variable
(or _attribute_).

Given some `p1: ColorPoint` and `p2: Point`, since `ColorPoint` is a subtype of `Point`,
we can cast `p1` to a `p: Point`. Then the method call `p.equal(p2)` type checks, but
`ColorPoint#equal` is called with a `Point` argument while it expects a `ColorPoint` instance.
Despite this unsound behavior, Steep accepts this program.

== Set-theoretic types & semantic subtyping <SemSubBackground>

Set-theoretic typing models types as sets of values, which can be combined
using unions, intersections and negations. These type connectors can type very precisely
common idioms found in dynamic languages, such as type cases and pattern matching
(using union types #box[`t | u`]), function overloading (using intersection types `t & u`)
and fallback behavior (using negation types `~t`)#footnote[where `t` and `u` denote types.].

A basic set-theoretic type system has a few essential constructs,
apart from set operations: the top type `any` and bottom type `empty`,
tuple types `(t`$""_1$`, ..., t`$""_n$`)` which behave as expected, and finally arrow types `t -> u`.
Given two types `t` and `u`, `t -> u` is the type of all functions that,
given an argument of type `t`, returns only values of type `u`.
In particular it makes no claim about what happens in case the function is passed
an argument outside of `t` (i.e. in `~t`).
There are also singleton types, which contain exactly one value, such as `42`, `true`, etc.

The type `int | bool` is the union of types `int` and `bool`, i.e. the type of values in either `int` or `bool`. `true | false` is equivalent to `bool`.
#box[`(int -> string) & (string -> int)`] is the type of functions
that accept both arguments of type `int` or `string`, and return a `string` if the argument
was an `int` and vice versa. The domains may not be disjoint: let's say we have a function
of type #box[`(a -> c) & (b -> d)`] (where `a`, `b`, `c` and `d` are some fixed types).
Then passing an argument in `a & b` (in both `a` and `b`) returns a value of type `c & d`.
One final example: a function that checks whether a value is a `bool` typically has type
#box[`(bool -> true) & (~bool -> false)`].

For a more in-depth introduction to set-theoretic types, see @Cas24.

Semantic subtyping defines the meaning of these set-theoretic connectors in terms
of a subtyping relation. This allows the connectors to behave in a more natural way
for the programmer than a purely syntactical approach @SemSub.

// In the presence of these set-theoretic connectors, the type system must be equipped with
// a robust subtyping relation that behaves in an "natural" way for the programmer, i.e.
// behave like set inclusion. Semantic subtyping defines such relation by making sure
// that the subtyping relation is as large as it can be while remaining sound,
// including important features such as type variables @SemSub.

== MLsem

MLSem @CMK is an experimental research language using OCaml-like syntax and semantic subtyping.
It is the base implementation of a type checker for the current research on semantic subtyping.
It is only used for testing and research purposes.

The syntax of expressions is close to OCaml. Two new features are worth mentioning.
The first one is the type-coercion expression ```c e :> t```, which coerces an expression
of type `t'` to some supertype `t` of `t'`, for instance ```c 42 :> (int | bool)```.
The second one is the type case expression ```ocaml if e1 is t then e2 else e3```,
which tests whether `e1` is of type `t` and branches accordingly.

The syntax of types is an extension of the one we introduced
in #link(<SemSubBackground>)[the last section], however the MLsem type system
supports many more features. We will focus on constructors and records.

Constructors are structural abstract labels that start with a capital letter,
akin to polymorphic variants in OCaml, atoms in Elixir,
or symbols in Ruby. They can also carry data as an optional argument.
They have their corresponding types: #box[`Hello : Hello`]
(the second `Hello` is a singleton type) and #box[`MyInt(67) : MyInt(int)`].

MLsem also supports records. At the expression level, they are exactly like OCaml:
a literal syntax ```ocaml {x = 42; y = "perl"}```,
a record update expression ```ocaml {r with y = true}``` and field access `r.x`.
At the type level, records are structural: they don't need to be declared.
Record types have several forms: closed records ```ocaml {x : int; y : string}```
the type of records that have the _exact_ set of specified keys, 
open records #box[```ocaml {x : int; y : string ..}```] the type of records
that have _at least_ the set of specified keys,
record update #box[```ocaml {t with y : bool}```] which updates
the type of an existing record type,
and finally records with a tail #box[```haskell {x : int; y : string ;; <tail>}```]
where `<tail>` is either a row variable #raw("`x"), representing an indeterminate
set of keys, or a boolean combination of row variables.
An intersection tail #raw("`x & `y") means that the fields of both #raw("`x") and #raw("`y")
are added, while an union tail means that the fields added are the one in both #raw("`x")
and #raw("`y") (a record type is contravariant in its tail, like its set of keys).

= Encoding Ruby in MLsem

We type check Ruby code against its corresponding (RBS) signature file by using the existing MLsem type checker:
first we translate the RBS and Ruby files into MLsem type definitions and expressions respectively, 
then we pass the generated code to the MLsem type checker.

== Formalization of the problem

We formalize a fragment of both Ruby @RubySyntax and RBS @RBSsyntax:

#let r(s) = raw(s, lang: none)
#let new(content) = text(fill: orange, content)
#let later(content) = text(fill: green, content)
#let sep = $space space space$


#figure(caption: "Featherweight Ruby")[
  #set rect(stroke: green, radius: 4pt, inset: (x: 0% + 2pt))
  $
    
    bold("Expression") space
    &#r("E") ::= &&#r("L") | #r("X") | C | #r("self")
              | #r("nil") | #r("E.")f#r("(")#r("E")_1, ..., #r("E")_n#r(")") | #r("X = E") \
    &sep      | &&#r("if E; E else E end") | #r("E;E") | #r("return E") \
              
    bold("Literal") space
    &#r("L") ::= &&s | n | #r("true") | #r("false") \

    bold("Statement") space
    &#r("S") ::= &&#r("class") C" "(#r("<") C)^? " "overline(#r("K")) #r("end") \

    bold("Class statement") space
    &#r("K") ::=&&#r("def") f#r("(")x_1, ..., x_n#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def initialize(")x_1, ..., x_n#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def") #r("self.")f#r("(")x_1, ..., x_n#r(")") #r("E") #r("end") \
    &sep      | &&#rect[$#r("attr") x$] \

    bold("Binder") space
    &#r("X") := &&x | #r("@")x
  $
]

#figure(caption: "Featherweight RBS")[
  #set rect(stroke: green, radius: 4pt, inset: (x: 0% + 2pt))
  $
    bold("Type") space
    &#r("T") ::= &&#r("B") | #r("L") | C
               | (#r("T | T")) | #rect[$#r("T % T")$]
               | #rect[$#r("not T")$] \
               
    bold("Base type") space
    &#r("B") ::= &&#r("Symbol") | #r("Integer") | #r("self") | #r("nil") | #r("bot") \
    bold("Function type") space
    &#r("F") ::= &&#r("(T")_1, ..., #r("T")_n#r(") -> T") \
    bold("Declaration") space
    &#r("D") ::= &&#r("class") C space space overline(#r("M")) space #r("end") \
    &sep       | &&#r("class") C #rect(stroke: blue.darken(20%))[$#r("<") C$] space overline(#r("M")) space #r("end") \
    &sep       | &&#r("class") C #rect[$#r("<:") C$] space overline(#r("M")) space #r("end")  \
    bold("Member") space
    &#r("M") ::= &&#r("def") f#r(": N") \
    &sep       | &&#r("def initialize: N") \
    &sep       | &&#r("def") #r("self.")f#r(": N") \
    &sep       | &&#r("@")x#r(": T") \
    bold("Method type") space
    &#r("N") ::= &&#r("F")_1 #r("%") ... #r("%") #r("F")_n \
    &sep       | &&#r("F")_1 #r("&") ... #r("&") #r("F")_n \
  $

  where: #h(16em)
    - #align(left)[$n$ ranges over integers]
    - #align(left)[$x, f$ range over variable names]
    - #align(left)[$s$ ranges over symbol names]
    - #align(left)[$C$ ranges over class names]
]

*Notation.* We note $#r("T")_1 #r("&") #r("T")_2 := #r("not") (#r("not T")_1 | #r("not T")_2)$.

Expresions of the form $#r("E.")f#r("(")#r("E")_1, ..., #r("E")_n#r(")")$
are method calls (the only kind of call in Ruby) where `E` is the receiver
of the method $f$ and $#r("E")_1, ..., #r("E")_n$ are the arguments.
The #box[`def self.`$f$`: N`] statement (and its RBS counterpart) declares
a class method, and `@x: T` declares an attribute `x` of type `T`.

We add a few features to Ruby and RBS (boxed in green)
or we modify the meaning of existing ones (boxed in blue).

An `attr` $x$ statement inside a class declares an instance variable.
They are used to translate classes more easily. They can be inserted by
a preprocessing step that either looks at the attributes defined in RBS or collects
used instance variables in the Ruby code.

The `%` type is added to distinguish between the use of `|` for union types
and for method overloading, only used inside the translation.
We call $#r("T")_1 #r("%") #r("T")_2$ an _overload_ type.
Finally, the `not` type is a negation type intended to be used by the programmer.

The inheritance syntax has a different meaning than in Steep.
In our new syntax, #box[`class` $C$ `<` $D$] only implies $C$ is a subclass of $D$,
not that $C$ is a subtype of $D$, whereas `class` $C$ `<:` $D$ means that
$C$ inherits $D$ _and_ that $C$ is a subtype of $D$. In the case that the complete
signature of $C$ does not allow it to be a subtype of $D$, the type checker rejects it.

We define two functions: $[|dot|]_"Ruby"$ which encodes Ruby code as MLsem expressions,
and $[|dot|]_"RBS"$ which encodes RBS signatures as MLsem types.
These two functions together encode the semantics of Ruby programs and types.
We type check using MLsem the concatenation of the translated RBS signatures
and the translated Ruby code.

== Variable scoping and the monadic encoding

Ruby assignments such as `x = 42` are expressions.
This means that evaluating a Ruby expression can change the scope it was evaluated in.
For instance, the expression #box[`(x = 12) + x`] evaluates to `24` in Ruby and should type check. 
We call _binding_ expressions which extend the context they are evaluated in.
MLsem has mutable variables through `let mut` expressions that declare mutable variables
that can later be assigned to.
But Ruby binding expressions cannot be directly encoded by MLsem's `let mut` expressions
because their scoping is only local. This is why we use a monad @Moggi to encode variables and scopes.

=== The heterogeneous state monad

#let bind = math.class("binary", $>>#move(dx: -0.6em)[=]#h(-0.6em)$)

We recall that a monad is a type family
#box[$M: "Type" -> "Type"$] together with two operations: 
  $
    &"pure" : a -> M(a) \
    &"bind" : M(a) -> (a -> M(b)) -> M(b)
  $
satisfying some coherence laws.

*Notation.* We write $m bind f$ for $"bind"(m, f)$.

Morally, one can think of monads as a way of encoding side effects in a pure environment.
One notable monad is the state monad:

*Definition.* Let $S$ be a type. We define the _state monad_ as the type family
#box[$"state"_S : A mapsto (S -> (A times S))$] with $"pure"(x) := lambda s. space (x, s)$
and $m bind f := lambda s. space f (m(s))$.

This monad encodes computations that uses some limited but mutable environment.
In fact, if we use a record such as `{x : int; y : int}` for the state,
we get a scope-like environment we can use to encode expressions like `(x = 42) + y`.
One obvious downside is that the set of variables is fixed: variables are always
defined and have the same type throughout the whole scope.

To solve this, we introduce the heterogeneous state monad
#footnote[
  Strictly speaking, this is an abuse of terminology since the type family as well as the two operations
  do not have the correct signatures.
]:

*Definition.* We define the _heterogeneous state monad_:
  $ "hetState"(Gamma, Delta, v, r) := &{ ;; Gamma } -> [mono(V)(v, { ;; Gamma #r("&") Delta }) | mono(R)(r)] $
  where $Gamma, Delta$ are row variables, $v, r$ are type variables
  and $mono(V)(...), mono(R)(...)$ are constructor types.

Let's unpack this definition.
The ${ ;; Gamma }$ part is the type of records whose fields are exactly contained in $Gamma$,
and ${ ;; Gamma #r("&") Delta }$ is ${ ;; Gamma }$ extended by the fields contained in $Delta$.
Dropping the $mono(R)$ case, we get ${ ;; Gamma } -> mono(V)(v, { ;; Gamma #r("&") Delta })$,
which is the original state monad modified to allow evaluation to extend by $Delta$
its state at the type level. This will allow us to precisely encode the scope of variables.
For instance, for the expression $(x = 42) + y$, we can translate
the assignment $x = 42$ to an expression of type
${ ;; Gamma } -> mono(V)(mono("int"), { x : mono("int") ;; Gamma })$ and $y$ to an expression
of type ${ y : mono("int") ;; Gamma } -> mono(V)(mono("int"), { y : mono("int") ;; Gamma })$
(for some value of $Gamma$). Here, $mono(V)$ stands for "value".
The $mono(R)$ case is to allow encoding of early returns:
we will make this more precise once we have defined the _value_ and _bind_ operations.

*Definition.* The operations associated with the heterogeneous state monad are:
$ 
  &"value" : v -> "hetState"(Gamma, {}, v, #r("empty"))\
  &"value"(x) := lambda s. space mono(V)(x, s) \
$
$
  "bind" : &"hetState" (Gamma, Delta, v, r)  \
           &-> (v -> "hetState" (Gamma #r("&") Delta, Delta', b, r)) \
           &-> "hetState" (Gamma, Delta #r("&") Delta', b, r)\ 
  "bind"(m, f) := &lambda Gamma. "match" m(Gamma) "with" \
                 &| mono(V)(v, Gamma') -> f(v)(Gamma') \
                 &| mono(R)(r) -> mono(R)(r) \
                 &"end"
$

The _value_ operation corresponds to the _pure_ operation of the state monad:
it returns a value without accessing or modifying its scope.
The _bind_ operation composes two monadic computations with compatible scopes.
If both $m$ and $f(v)$ evaluate to a $mono(V)$, we get the following chain of scopes:

$
  &{ ;; Gamma } -->^m { ;; Gamma #r("&") Delta } -->^(f(v)) { ;; Gamma #r("&") Delta #r("&") Delta' } \
  &{ ;; Gamma } stretch(->, size: #237%)^"bind"(m, f) { ;; Gamma #r("&") Delta #r("&") Delta' }
$

If $m$ is an $mono(R)$, _bind_ will simply ignore the computation of $f$. This is to model early returns.
In the following expression:

#show raw.where(block: true): it => align(center, it)

#no-codly[```ruby
return 67; puts(12)
```]

the computation is short-circuited by ```ruby return``` and `puts` is never called.
We use $mono(R)$ as a value that bypasses any remaining computations. 

*Definition.* We introduce a new operation for returning #footnote[
  This is different from the `return` function found in Haskell.
]:
$
  &"return" : r -> "hetState"(Gamma, {}, #r("empty"), r) \
  &"return"(x) := lambda s. space mono(R)(x)
$

Finally, we introduce operations for manipulating variables:

*Definition.* Let $mono(x)$ be a Ruby variable. \
  We define an operation for accessing $mono(x)$:
  $
    &"get" mono(x) : "hetState" ({x: alpha, ..}, {}, alpha, #r("empty"))\
    &"get" mono(x) = lambda s. space mono(V)(s.mono(x), s) \ 
  $

  As well as one for assigning to $mono(x)$:
  $
    &"set" mono(x) : alpha -> "hetState" (Gamma, {mono(x): alpha}, alpha, #r("empty")) \
    &"set" mono(x) space v = lambda s. space mono(V)(v, {s "with" mono(x) = v}]) 
  $

The types of these operations are precise enough to couple types with control flow:
when typing branches (such as an `if` or a `case` expression), you get union types:

#let hS(g, d, v, rr) = $({ ;; #g } -> [mono(V)(#v, { ;; #g #r("&") #d }) | mono(R)(#rr)])$

$
  &"hetState"(Gamma, Delta_1, v_1, r_1) | "hetState"(Gamma, Delta_2, v_2, r_2) \
    &#h(2em) = hS(Gamma, Delta_1, v_1, r_1) | hS(Gamma, Delta_2, v_2, r_2) \
    &#h(2em) <: { ;; Gamma } ->
      [mono(V)(v_1, { ;; Gamma #r("&") Delta_1 }) | mono(V)(v_2, { ;; Gamma #r("&") Delta_2 }) | mono(R)(r_1 | r_2)] \
    &#h(2em) <: { ;; Gamma } -> (mono(V)(v_1 | v_2, { ;; Gamma #r("&") (Delta_1 | Delta_2) }) | mono(R)(r_1 | r_2)) \
    &#h(2em) <: "hetState"(Gamma, (Delta_1 | Delta_2), (v_1 | v_2), (r_1 | r_2))
$

Taking the union of the monads is more precise than taking the union of the context and values component-wise.
For a concrete example, see @flow_example.

=== Translating expressions

We can finally define the full translation of expressions.
Note that MLsem cannot express first-class key polymorphism nor row variables 
in type aliases at the time of writing this report,
so the definition of hetState as well as _value_, _return_, _bind_, _get_ and _set_ need to be expanded when used in the translation.

*Notation.* We note `truthy` $:=$ `~(false | ())`.

#let transRaw(m, arg) = $[|#arg|]_#r(m)$
#let trans(arg) = $[|#arg|]$
#let transE(arg) = transRaw("E", arg)
#let transX(arg) = transRaw("X", arg)
#let transS(arg) = transRaw("S", arg)
#let transKClass(arg) = $[|#arg|]_#r("K")^#r("Class")$
#let transKInst(arg) = $[|#arg|]_#r("K")^#r("Inst")$
#let transT(arg) = transRaw("T", arg)
#let transF(arg) = transRaw("F", arg)
#let transR(arg) = transRaw("R", arg)
#let transQ(arg) = transRaw("Q", arg)
#let transN(arg) = transRaw("N", arg)
#let transDInst(arg) = $[|#arg|]_#r("D")^#r("Inst")$
#let transDClass(arg) = $[|#arg|]_#r("D")^#r("Class")$
#let transMInst(arg) = $[|#arg|]_#r("M")^#r("Inst")$
#let transMClass(arg) = $[|#arg|]_#r("M")^#r("Class")$

#figure(caption: "Translation of expressions")[
  $
    #transE[#r("L")] &= "value" #r("L") \
    #transE[#r("x")] &= "get" #r("x") \
    #transE[#r("@x")] &= "value self.__attr_"#r("x") \
    #transE[$C$] &= "value" C \
    #transE[#r("nil")] &= "value" #r("()") \
    #transE[#r("self")] &= "value" #r("self") \
    #transE[$#r("E.f(")#r("E")_1, ..., #r("E")_n#r(")")$]
      &= [|#r("E")|] bind lambda r. space #trans[$#r("E")_1$] bind lambda a_1. space dots.h.c space #trans[$#r("E")_n$] bind lambda a_n. "value" r.#r("f")""(a_1, ..., a_n) \
    #transE[#r("return E")] &= #trans(r("E")) bind "return"\
    #transE[#r("x = E")] &= #trans(r("E")) bind ("set" #r("x"))\
    #transE[#r("@x = E")] &= #trans(r("E")) bind lambda v. ("self :=" {"self" "with self.__attr_"#r("x") = v }; "value" v)\
    #transE[$#r("if E")_1#r("; E")_2#r(" else E")_3#r(" end")$]
      &= [|#r("E")_1|] bind lambda b. space "if" b "is truthy then" [|#r("E")_2|] "else" [|#r("E")_3|] \
    #transE[$#r("E")_1 #r(";") #r("E")_2$] &= [|#r("E")_1|] bind lambda#r("_"). space [|#r("E")_2|] \
  $
]

Some examples of translations:

#align(center)[
  #let spaaaaace = $space space space space space space space space$
  $
    #raw("(x = 1); x") space &~~> space
      "value 1"\ &spaaaaace bind lambda v. "set x" v \ &spaaaaace bind lambda#r("_"). "get x" \
  $
  $
    #raw("return self.set_level(10)") space &~~> space
      "value self"\ &spaaaaace bind lambda r. "value 10" \
      &spaaaaace bind lambda a. "value" r."set_level"(a) \
      &spaaaaace bind "return"
  $
]

Ruby expressions are translated into fairly standard monadic code using the operations we defined.
We translate #r("if") expressions to check for `truthy` values instead of just #r("true") because
the only falsy values in Ruby are ```rb false``` and ```rb nil```. Finally, the translation of 
instance variables (```ruby @x``` and ```ruby @x = E```) will be explained alongside
the encoding of classes in the next section.


== Encoding classes and inheritance

One of Ruby's main features is its classes, which we cannot translate directly in MLsem.
Classes have several features we want to encode in the type system:
attributes, methods, inheritance, the `self` type, nominal typing,
and being able to control whether inheritance generates a subtype.

We suppose that we have two values `rec : ('a -> 'a) -> 'a` to encode recursion
at the type level and `opaque : 'a` to get opaque values of any type
(using type casts: #box[`opaque :> int`]).
They can be declared by top-level statements in MLsem:
```ml
val rec : ('a -> 'a) -> 'a
val opaque : 'a
```

=== Translating classes at the type level

We need to encode classes as runtime values in MLsem, since classes are first-class values in Ruby.
We encode classes and instances as recursive records, whose fields contain attributes and methods.
Nominal subtyping is encoded by a special extra field.

The translation of classes is composed of two parts: the RBS declaration is translated to MLsem types
and the Ruby code is translated into an MLsem expression.

Let's take a simple class signature as an example:

#figure(caption: [`IntWrapper` RBS class signature])[
  ```ruby
  class IntWrapper
    @x: Integer

    def initialize: (Integer) -> top
    def get_x: () -> Integer
    def equal: (self) -> bool
  end
  ```
]

At the type level, a class generates three types: two types of its instances
and the type of the class singleton. In @intwrappertrans, the `tyClassIntWrapper` type represents the type of the class singleton.
The fields of the record (except for `__name`) represent the class methods
of the class. In the case of `IntWrapper`, the only one is `new`, whose type was generated
from the signature of `initialize`. The type of `IntWrapper` instances is defined by open
recursion: in `tyIntWrapperRec`, the `'self` type parameter is bound to represent
the `self` type to allow changing when a class inherits from `IntWrapper`.
Finally, the type `tyIntWrapper` closes the recursion, instantiating the self type to `tyIntWrapper`.

#figure(caption: [`IntWrapper` MLsem type translation])[
```ML
type tyIntWrapperRec('self) = {
  __name : ~Inst__A; 
  __attr_x : int; 
  get_x : () -> int;
  equal : 'self -> bool
  ..
}
and tyIntWrapper = tyIntWrapperRec(tyIntWrapper)
and tyClassIntWrapper = {
  __name : ~Class__IntWrapper;
  new : (int) -> tyIntWrapper
  ..
}
```
] <intwrappertrans>


We give another example to illustrate how inheritance and nominal typing is encoded:

#figure(caption: [Inheritance with subtyping example])[
  ```ruby
  class A
    def get_level: () -> Integer
  end
  class B <: A end
  class C <: B end
  class D <: A end
  ```
] <inherit_ex>

This example produces the following types (omitting the class types):

#figure(caption: [Translation of @inherit_ex])[
  ```ml
  type tyARec('self) =
    { __name : ~Inst__A; eq : () -> int .. }
  type tyA = tyARec(tyA)

  type tyBRec('self) =
    { tyARec('self) with __name : ~(Inst__B | Inst__A) }
  type tyB = tyBRec(tyB)

  type tyCRec('self) =
    { tyBRec('self) with __name : ~(Inst__C | Inst__B | Inst__A) }
  type tyC = tyCRec(tyC)

  type tyDRec('self) =
    { tyARec('self) with __name : ~(Inst__D | Inst__A) }
  type tyD = tyDRec(tyD)
  ```
]

We use the record type update syntax to include the parent's fields into the type.
The `__name` field encodes nominal typing, ensuring that
two different classes with the same signatures stay distinct for the type checker.
However, we want to allow a subclass to be a subtype of its parent class,
so the field must take into account every transtive parents in the inheritance tree (@inherit_tree).
We negate the type to account for variance: we want the `__name` field of a subclass to be 
a subtype of the `__name` of its parent class. Making the `__name` field contravariant with respect
to inheritance mimics the fact that the set of keys in a record is contravariant.

#figure(
  caption: [Subtyping tree of @inherit_ex],
// https://q.uiver.app/#r=typst&q=WzAsNCxbMSwwLCJcIkFcIiJdLFswLDEsIlwiQlwiIl0sWzAsMiwiXCJDXCIiXSxbMiwxLCJcIkRcIiJdLFswLDFdLFsxLDJdLFswLDNdXQ==
  diagram({
    node((1, -1), [`A`])
    node((0.5, 0), [`B`])
    node((0.5, 1), [`C`])
    node((1.5, 0), [`D`])
    edge((1, -1), (0.5, 0), "->")
    edge((0.5, 0), (0.5, 1), "->")
    edge((1, -1), (1.5, 0), "->")
  })
) <inherit_tree>

Finally, a check is added ensure that the type generated by a `:>` subclass is a subtype:

```ml
let _checkVal = ((opaque :> tyB) :> tyA)
```

This encoding fixes the issue of subtyping in the presence of inheritance highlighted in @BruEtAl96
because the type checker ensures that a subtype is being generated
when the subclass is explicitly specified to be a subtype. Suppose we have the following signature:

#figure(caption: "Incorrect use of subtyping inheritance")[
  ```ruby
  class A
    def equal: (self) -> bool
  end
  class B <: A
    def equal: (self) -> bool
  end
  ```
]

We get the following types (after simplifying open recursion and record updates):

#no-codly[```ml
  tyA = { __name : ~Inst__A            ; eq : tyA -> bool .. }
  tyB = { __name : ~(Inst__A | Inst__B); eq : tyB -> bool .. }
```]

Due to `'self` appearing in a contravariant position, `tyB` is not a subtype of `tyA`
despite `B` inheriting from `A`, so the subtyping check fails and the signature does not type check, thus restoring soundness.
We can however inherit from `A` without generating a subtype:
replacing `class B <: A` by `class B < A` yields the following types:

#no-codly[```ml
  tyA = { __name : ~Inst__A; eq : tyA -> bool .. }
  tyB = { __name : ~Inst__B; eq : tyB -> bool .. }
```]

With `<` inheritance, the `__name` field only refers to the current class.

=== Encoding classes in MLsem expressions

A class `A` generates a top-level statement of the form (excluding some type coercions for clarity):

#figure(caption: [Top level statement generated from class `A`])[
```ml
let classA =
  rec (fun (self : tyClassA) ->
    let mut self = self in
    {
      __name = (opaque :> ~Class__A);
      (* class methods *)
    }
  )
```

]

The `new` class method has a particular translation of the form (again, omitting type coercions):

#figure(caption: [The `new` field generated from class `A`])[
```ml
new = 
  fun args -> rec (fun (self : tyA) -> 
    let mut self = self in
    self := {
      __name = (opaque :> ~Inst__A); 
      (* instance methods and attributes *)
    };
    (* translation of the initialize method *)
    self
  )
```
]

In both the class and instance translations, the `__name` field is present to reflect
our type-level encoding. Similarly, an attribute is translated to a special field
initialized to `opaque`.
Our translation does not keep track of the initialization state of attributes.

=== Encoding methods

Instance methods and class methods have a non-trivial encoding because of the monadic encoding of expressions.
A translation of methods needs to:
- initialize the method's context
- add the method's arguments to the context
- translate the body of the function
- extract the return value from the monad.

*Definition.* We define an _extract_ operation:
$
  "extract"(("x"_1, ..., "x"_n), #r("E")) := &"match" #trans[#r("E")]""({ "x"_1 = "x"_1; ...; "x"_n = "x"_n }) "with" \
                                             &| mono(V)(v, #r("_")) -> v \
                                             &| mono(R)(r) -> r \
                                             &"end"
$
The _extract_ operation takes a list of Ruby variables and an expression.

We can then define the translation of a method as:

#figure(caption: [Translation of methods])[
#table(
  align: center+horizon,
  columns: (1fr, auto, 1fr),
  stroke: none,
  [```ruby 
  def my_method(x, y)
    <body>
  end
  ```],
  $~~>$,
  [```ml
  my_method =
    fun (x, y) ->
      extract((x, y), <body>)
  ```]
)
]

The fact that the monadic state is only managed by the method means that the monadic encoding is transparent
at the type level, so that function types are not polluted with an extra state argument.

RBS allows the programmers to overload methods:

#figure(caption: "Method overloading in RBS")[
#columns(2)[
```ruby
def process: (42) -> String
           % (Integer) -> Integer 
           % (Symbol) -> Symbol
```

#align(center)[(formalized syntax)]

#colbreak()

```ruby
def process: (42) -> String
           | (Integer) -> Integer 
           | (Symbol) -> Symbol
```

#align(center)[(real RBS syntax)]
]]

Contrary to MLsem intersection types, this overloading mecanism is order-sensitive.
If one passes `42` to `process`, the first overload matches the type of the argument passed and
the second overload is never considered. This type can be rewritten using intersection types:

#no-codly[
  ```mlsem
  (42 -> String) & (Integer \ 42 -> Integer) & (Symbol -> Symbol)
  ```
]

*Definition.* We define _domain_ and _codomain_ functions for RBS types:

$
  "dom"(#r("T")) &= cases(
    (#r("U")_1, ..., #r("U")_n) &&"if" #r("T") = #r("(")#r("U")_1\, ...\, #r("U")_n#r(") -> R"),
  "dom"(#r("T")_1) #r("|") "dom"(#r("T")_2) space &&"if" #r("T") = #r("T")_1 #r("%") #r("T")_2,
    "undefined" &&"otherwise"
  ) \
  "cod"(#r("T")) &= cases(
    #r("R") &&"if" #r("T") = #r("(")#r("U")_1\, ...\, #r("U")_n#r(") -> R"),
    "undefined" space &&"otherwise"
  )
$

We assume chains of `%` are always of the form $(("F"_1 #r("%") "F"_2) #r("%") ...) #r("%") "F"_n$.
We can then define the translation of overload types as:

$
  #transT[$#r("T")_1 #r("%") #r("T")_2$] &:=
    [|#r("T")_1|] #r("&") ([|"dom"(#r("T")_2)|] #r("\\") [|"dom"(#r("T")_1)|] #r("->") [|"cod"(#r("T")_2)|])
$

Since we defined classes with open recursion at the type level, we also define:
$ #transT[#r("self")] := #r("'self") $

The remaining cases of $transT(dot)$ are straightforward.

== Technical details of the full translation

The full translation can be found in @full_trans.

To actually implement the translation, you need to insert `attr x` statements
in the Ruby code, since you don't declare attributes in Ruby. This can be done simply
by collecting every attribute mentioned in the class and then inserting the `attr` statements.
The translation also assumes the `initialize` method is defined both in Ruby and RBS
in order to generate the `new` class method.

Another pass is needed to build the inheritance hierarchy, to generate the `__name` field
(this can be done during the translation of the RBS signatures).

You can then translate the RBS, and then concatenate it with the translation of
the Ruby code. You also need to prepend the definition of the several constants
we needed during the translation (as shown in @begin_trans).

= Prototype

An implementation of the full translation is available on Github @RbSem.
Several examples can be found in the `test` folder of the repository.
The output can be read (the generated MLsem code should be nicely formatted)
and pasted directly into MLsem @MLsem.

We give two examples of programs that we are able to type check using
our translation and MLsem:

#box[
#columns(2)[
  #v(1em)
  #figure(caption: "Flow-sensitive scopes")[
    ```ruby
    def f(b)
      if b then
        x = 1
      else
        y = 2
      end
      if b then
        z = x
      else
        z = y
      end
      z
    end
    ```
  ] <flow_example>

  #colbreak()

  This code type checks for both signatures:
  ```python
  def f: (bool) -> Integer
  def f: (true) -> 1 | (false) -> 2
  ```
  
  Our encoding is capable of capturing control flow-based typing information.
  Trying to access `x` outside of the second `if` expression would result
  in a type error because `x` is not defined in the case that `b` is falsy,
  but the encoding is precise enough to analyze the branches.
  It can also determine that `z` is defined in all cases after the second `if` expression.
  This sort of flow-based analysis can become very useful if integrated with
  type cases in the future (using `Object#is_a?` @ruby_is_a).
]]

This next example involves reading and writing to an attribute:

#figure(caption: "Methods and attributes inside a class")[
#columns(2)[
  ```ruby
  class A
    attr x

    def initialize(x)
      @x = x
    end

    def get_x()
      @x
    end
  end
  ```

  #colbreak()

  #v(3em)
  ```ruby
  class A
    @x: Integer

    def initialize: (Integer) -> top
    def get_x: () -> Integer
  end
  ```
]]

Changing ```ruby initialize: (Integer) -> top``` to ```ruby initialize: (Symbol) -> top```
makes the example no longer compile, as expected, since the assignment `@x = x`
tries to assign a `Symbol` where an `Integer` is expected.

= Conclusion

We have encoded Ruby programs inside MLsem, allowing us to type Ruby programs
using the existing semantic subtyping framework, addressing soundness holes
(assuming the translation is indeed correct) by providing new constructs
(the two types of inheritance). We implemented a small type checker for Ruby
using the translation we defined, which can be used for further testing. 
The various examples tested using our prototype hint that set-theoretic types
and semantic subtyping are a useful approach to type Ruby programs.

The next step is to integrate more features to our encoding such as type variables
and gradual typing. Type variables must also be able to quantify over the subclass hierarchy
of a particular class using F-bounded polymorphism @Fbounded or the matching relation brought up
in @BruEtAl96: since subclasses are no longer
subtypes simple subtyping constraints are not as useful for polymorphism.
Gradual typing is also essential to type dynamic languages to allow the programmer
to migrate their untyped code progressively instead of require the whole program to be
typed. It would be also useful to have a proof that our encoding is sound and preserves
operational semantics, as this would increase our confidence in the encoding.

#bibliography("ref.bib", full: true)

#set heading(numbering: "A.1.", supplement: "Appendix")
#counter(heading).update(0)

= Full translation <full_trans>

== Featherweight Ruby & RBS

#[
  #set rect(stroke: green, radius: 4pt, inset: (x: 0% + 2pt))
  $
    
    bold("Expression") space
    &#r("E") ::= &&#r("L") | #r("X") | C | #r("self")
              | #r("nil") | #r("E.")f#r("(")#r("E")_1, ..., #r("E")_n#r(")") | #r("X = E") \
    &sep      | &&#r("if E; E else E end") | #r("E;E") | #r("return E") \
              
    bold("Literal") space
    &#r("L") ::= &&s | n | #r("true") | #r("false") \

    bold("Statement") space
    &#r("S") ::= &&#r("class") C" "(#r("<") C)^? " "overline(#r("K")) #r("end") \

    bold("Class statement") space
    &#r("K") ::=&&#r("def") f#r("(")x_1, ..., x_n#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def initialize(")x_1, ..., x_n#r(")") #r("E") #r("end")  \
    &sep      | &&#r("def") #r("self.")f#r("(")x_1, ..., x_n#r(")") #r("E") #r("end") \
    &sep      | &&#rect[$#r("attr") x$] \

    bold("Binder") space
    &#r("X") := &&x | #r("@")x \
    \
    bold("Type") space
    &#r("T") ::= &&#r("B") | #r("L") | C
               | (#r("T | T")) | #rect[$#r("T % T")$]
               | #rect[$#r("not T")$] \
               
    bold("Base type") space
    &#r("B") ::= &&#r("Symbol") | #r("Integer") | #r("self") | #r("nil") | #r("bot") \
    bold("Function type") space
    &#r("F") ::= &&#r("(T")_1, ..., #r("T")_n#r(") -> T") \
    bold("Declaration") space
    &#r("D") ::= &&#r("class") C space space overline(#r("M")) space #r("end") \
    &sep       | &&#r("class") C #rect(stroke: blue.darken(20%))[$#r("<") C$] space overline(#r("M")) space #r("end") \
    &sep       | &&#r("class") C #rect[$#r("<:") C$] space overline(#r("M")) space #r("end")  \
    bold("Member") space
    &#r("M") ::= &&#r("def") f#r(": N") \
    &sep       | &&#r("def initialize: N") \
    &sep       | &&#r("def") #r("self.")f#r(": N") \
    &sep       | &&#r("@")x#r(": T") \
    bold("Method type") space
    &#r("N") ::= &&#r("F")_1 #r("%") ... #r("%") #r("F")_n \
    &sep       | &&#r("F")_1 #r("&") ... #r("&") #r("F")_n \
  $

  where: #h(16em)
    - #align(left)[$n$ ranges over integers]
    - #align(left)[$x, f$ range over variable names]
    - #align(left)[$s$ ranges over symbol names]
    - #align(left)[$C$ ranges over class names]
]

*Notation.* We note $#r("T")_1 #r("&") #r("T")_2 := #r("not") (#r("not T")_1 | #r("not T")_2)$.

== Monadic encoding

#let bind = $>>#move(dx: -0.6em)[=]#h(-0.4em)$
#let bindr = $>>#move(dx: -0.6em)[=]#h(-0.6em)_r#h(0.2em)$

$
  &"hetState"(Gamma, Delta, v, r) := { ;; Gamma } -> [mono(V)(v, { ;; Gamma #r("&") Delta }) | mono(R)(r)] \
  &#h(3em) "where" Gamma, Delta  "are row variables and" v, r "are type variables."
$
  

$ 
  &"value" : v -> "hetState"(Gamma, {}, v, #r("empty"))\
  &"value"(x) := lambda s. space mono(V)(x, s) \
$
$
  "bind" : &"hetState" (Gamma, Delta, v, r)  \
           &-> (v -> "hetState" (Gamma #r("&") Delta, Delta', b, r)) \
           &-> "hetState" (Gamma, Delta #r("&") Delta', b, r)\ 
  "bind"(m, f) := &lambda Gamma. "match" m(Gamma) "with" \
                 &| mono(V)(v, Gamma') -> f(v)(Gamma') \
                 &| mono(R)(r) -> mono(R)(r) \
                 &"end"
$
$
  &"return" : r -> "hetState"(Gamma, {}, #r("empty"), r) \
  &"return"(x) := lambda s. space mono(R)(x)
$
$
  &"get" mono(x) : "hetState" ({x: alpha, ..}, {}, alpha, #r("empty"))\
  &"get" mono(x) = lambda s. space mono(V)(s.#r("x"), s) \ 
$
$
  &"set" mono(x) : alpha -> "hetState" (Gamma, {x: alpha}, alpha, #r("empty")) \
  &"set" mono(x) space v = lambda s. space mono(V)(v, {s "with" #r("x") = v}]) 
$

$
  "extract"(("x"_1, ..., "x"_n), #r("E")) := &"match" #trans[#r("E")]""({ "x"_1 = "x"_1; ...; "x"_n = "x"_n }) "with" \
                                             &| mono(V)(v, #r("_")) -> v \
                                             &| mono(R)(r) -> r \
                                             &"end"
$

*Notation.* We write $m bind f$ for $"bind" m space f$.

== Ruby Translation

#figure(caption: "Beginning of a translated file")[```ocaml
type truthy = ~(false | ())
val opaque: 'a
val rec: ('a -> 'a) -> 'a
```] <begin_trans>

$
  #transE[#r("L")] &= "value" #r("L") \
  #transE[#r("x")] &= "get" #r("x") \
  #transE[#r("@x")] &= "value self.__attr_"#r("x") \
  #transE[$C$] &= "value" C \
  #transE[#r("nil")] &= "value" #r("()") \
  #transE[#r("self")] &= "value" #r("self") \
  #transE[$#r("E.f(")#r("E")_1, ..., #r("E")_n#r(")")$]
    &= [|#r("E")|] bind lambda r. space #trans[$#r("E")_1$] bind lambda a_1. space dots.h.c space #trans[$#r("E")_n$] bind lambda a_n. "value" r.#r("f")""(a_1, ..., a_n) \
  #transE[#r("return E")] &= #trans(r("E")) bind "return"\
  #transE[#r("x = E")] &= #trans(r("E")) bind ("set" #r("x"))\
  #transE[#r("@x = E")] &= #trans(r("E")) bind lambda v. ("self :=" {"self" "with self.__attr_"#r("x") = v }; "value" v)\
  #transE[$#r("if E")_1#r("; E")_2#r(" else E")_3#r(" end")$]
    &= [|#r("E")_1|] bind lambda b. space "if" b "is truthy then" [|#r("E")_2|] "else" [|#r("E")_3|] \
  #transE[$#r("E")_1 #r(";") #r("E")_2$] &= [|#r("E")_1|] bind lambda#r("_"). space [|#r("E")_2|] \
$

#let blue(x) = text(fill: color.blue, x)
#let orange(x) = text(fill: color.orange, x)

$#transS[$#r("class") #blue("name") ((#r("<")|#r("<:")) #orange[sup]))^? space #r("K")_1#r(",")...#r(",K")_n " "#r("end")$] =$
  `
  let `#blue[name] `= rec (fun self ->
    let mut self = self in {
    `(`(opaque :> `#orange[sup]`Class)) with`)$""^?$`
    __name = (opaque :> ~`$NN^#r("Class") (blue("name"))$`);
    `$[| #r("K")_1 |]^#r("Class")$`; ...; `$[| #r("K")_n |]^#r("Class")$`
  })
  `

$#transKClass[$#r("def initialize(")mono(x)_1, ..., mono(x)_n#r(")") #r("E") #r("end")$] =$
  `
    new = fun (`$mono(x)_1, ..., mono(x)_n$`) -> rec (fun self ->
      let mut self = self in
      self := {
        `(`(opaque :> `#orange[sup]`_(`#blue[name]`)) with`)$""^?$`
        __name = (opaque :> ~`$NN^#r("Inst") (#blue[name])$`);
        `$[| #r("K")_1 |]^#r("Inst")$`; ...; `$[| #r("K")_n |]^#r("Inst")$`;
      };
      extract ((`$mono(x)_1, ..., mono(x)_n$`), `$[|$`E`$|]$`);
      self
    );`

$#transKClass[$#r("def") #r("self.")f#r("(")mono(x)_1, ..., mono(x)_n#r(")") #r("E") #r("end")$] = f$` = fun `$(mono(x)_1, ..., mono(x)_n)$` -> `extract $((mono(x)_1, ..., mono(x)_n), [|$`E`$|]$)`;`

$#transKInst[$#r("def") f#r("(")mono(x)_1, ..., mono(x)_n#r(")") #r("E") #r("end")$] = f$` = fun `$(mono(x)_1, ..., mono(x)_n)$` -> `extract $((mono(x)_1, ..., mono(x)_n), [|$`E`$|])$`;`

$#transKInst[$#r("attr") x$] =$ `__attr_`$x$` = opaque;`

== RBS Translation

$
  #transT[`Symbol`] &= #r("enum") \
  #transT[`Integer`] &= #r("int") \
  #transT[`self`] &= #r("'self") \
  #transT[`nil`] &= #r("()") \
  #transT[`bot`] &= #r("empty") \

  #transT[$#r("T")_1 #r("|") #r("T")_2$] &= #trans[$#r("T")_1$] #r("|") #trans[$#r("T")_2$] \
  #transT[$#r("T")_1 #r("%") #r("T")_2$] &= [|#r("T")_1|] #r("&") ([|"dom"(#r("T")_2)|] #r("\\") [|"dom"(#r("T")_1)|] #r("->") [|"cod"(#r("T")_2)|])\
  #transT[$C$] &= C \
  #transT[#r("not T")] &= #r("~")#trans[`T`] \
  \
  #transT[`L`] &= #r("L") \
  \
  #transF($#r("(T")_1, ..., #r("T")_n#r(") -> U")$) &= (#trans[$#r("T")_1$], ..., #trans[$#r("T")_n$]) #r("->") #trans(r("U"))
$

$
  "dom"(#r("T")) &= cases(
    (#r("U")_1, ..., #r("U")_n) &&"if" #r("T") = #r("(")#r("U")_1\, ...\, #r("U")_n#r(") -> R"),
    "dom"(#r("T")_1) #r("|") "dom"(#r("T")_2) space &&"if" #r("T") = #r("T")_1 #r("%") #r("T")_2,
    "undefined" &&"otherwise"
  ) \
  "cod"(#r("T")) &= cases(
    #r("R") &&"if" #r("T") = #r("(")#r("U")_1\, ...\, #r("U")_n#r(") -> R"),
    "undefined" space &&"otherwise"
  )
$

$
  NN^#r("Inst") (C_1) &:= #r("_C")_1 #r("|") ... #r(" | _C")_n \
          &#h(-2em) "where" {C_i} "is the set of parents of" C_1 "in the subtyping tree" \
  NN^#r("Class") (C_1) &:= #r("_Class_C")_1 #r("| _Class") \
$

$#transDInst[$#r("class") #blue[name] ((#r("<")|#r("<:")) #orange[sup]))^? space #r("M")_1#r(",")...#r(",M")_n " "#r("end")$] =$
  `
    type `#blue[name]`_('self) = {
      `(#orange[sup]`_('self) with`)$""^?$`
      __name: ~`$NN^#r("Inst") (#blue[name])$`;
      `$[| #r("M")_1 |]^#r("Inst")$`; ...; `$[| #r("M")_n |]^#r("Inst")$`
    ..}
    type `#blue[name]` = `#blue[name]`_(`#blue[name]`)
  `


$#transDClass[$#r("class") #blue[name] ((#r("<")|#r("<:")) #orange[sup])^? space #r("M")_1#r(",")...#r(",M")_n " "#r("end")$] =$
  `
    type `#blue[name]`Class = {
      `(#orange[sup]`Class with`)$""^?$`
      __name: ~`$NN^#r("Class") (#blue[name])$`;
      `$[| #r("M")_1 |]^#r("Class")$`; ...; `$[| #r("M")_n |]^#r("Class")$`
    ..}
  `

$
  #transMInst[$#r("def") f #r(" : N")$] &= f #r(":") [|#r("N")|] \
  #transMInst[$#r("@")x #r(": T")$] &= #r("__attr_")x #r(":") [| #r("T") |] \
  #transMClass[$#r("def") #r("self.")f #r(" : N")$] &= f #r(":") [|#r("N")|] \
  #transMClass[$#r("def initialize:") #r("F")_1 #r("% ")...#r(" % F")_n$] &= #r("new :") [|II(#r("F")_1) #r("%") ... #r("%") II(#r("F")_n)|] \
  #transMClass[$#r("def initialize:") #r("F")_1 #r("& ")...#r(" & F")_n$] &= #r("new :") [|II(#r("F")_1) #r("& ")...#r(" &") II(#r("F")_n)|] \

  II(#r("F")) &= "dom"(#r("F")) #r("-> self")
$


= Contexte du stage

Mon stage s'est déroulé à l'IRIF, une unité mixte de recherche
entre le CNRS et l'Université Paris-Cité. Pendant ce stage
j'ai pu interagir régulièrement avec mon encadrant et d'autres
chercheurs de l'IRIF. J'ai aussi pu interagir avec Yaozhu Sun,
post-doctorant au National Institute of Informatics de Tokyo,
notamment par des appels vidéos hebdomadaires.