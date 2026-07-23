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

#TODO

= Background

#TODO
Python, JS, 
steep, typescript,
Sorbet,
unsound, example,
we follow elixir which is sound 

== Ruby & RBS

Ruby @Ruby sqidjqsd \
RBS @RBS

#TODO

== Set-theoretic types & semantic subtyping

pq utiliser ça language dyn, union (cases), intersection pour les fonctions précises
négations cas par défaut

on va traduire en MLsem

== MLsem

*Notation.* We note $bb(0)$ the empty type and $emptyset$ the empty row.

on binary methods, encodage, limites (f-bounded)
autre grosse limitation, pas de gradual typing

= Encoding Ruby in MLsem

We type check Ruby code against its corresponding (RBS) signature file by using the existing MLsem type checker:
first we translate the RBS and Ruby files to MLsem type definitions and expressions respectively, 
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
              | #r("nil") | #r("E.")x#r("(")#r("E")_1, ..., #r("E")_n#r(")") | #r("X = E") \
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
    &sep       | &&#r("class") C #rect[$#r("<") C$] space overline(#r("M")) space #r("end") ("ne pas générer de sous-typage") \
    &sep       | &&#r("class") C #rect[$#r("<:") C$] space overline(#r("M")) space #r("end") ("vérifier sous-typage") \
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

We add a few features to Ruby and RBS for the needs of the formalization (boxed in green).

An `attr` $x$ statement inside a class declares an instance variable.
They are used to translate classes more easily. They can be inserted by
a preprocessing step that either looks at the attributes defined in RBS or collects
used instance variables in the Ruby code.

The $%$ type is added to distinguish between the use of `|` for union types
and for method overloading, only used inside the translation.
We call $#r("T")_1 #r("%") #r("T")_2$ an _overload_ type.
Finally, the `not` type is a negation type intended to be used by the programmer.

The inheritance syntax has a different meaning than in current RBS.
In our new syntax, `class` $C$ `<` $D$ only implies $C$ is a subclass of $D$,
not that $C$ is a subtype of $D$. On the other hand, `class` $C$ `<:` $D$ means that $C$ inherits $D$ _and_ that $C$ is a subtype. In the case that the complete signature of $C$ does not allow it to be a subtype of $D$, 


We want 2 functions
  $ [|dot|]_"Ruby" : "Ruby" -> "Expr MLsem" "and" [|dot|]_"RBS" : "RBS" -> "Types MLsem" $
that together encode the semantic of Ruby programs and types.

== Variable scoping and the monadic encoding

Ruby assignments such as `x = 42` are expressions.
This means that evaluating a Ruby expressions can change the scope it was evaluated in.
For instance, the expression #box[`(x = 12) + x`] evaluates to `24` in Ruby and should type check. 
We call _binding_ expressions which extend the context they are evaluated in.
Such binding expressions cannot be directly encoded by MLsem's `let` expressions nor 
by `let mut` expressions and assignments because their scoping is only local.

We use a monad to encode variables and scopes.

=== The heterogeneous state monad

#let bind = math.class("binary", $>>#move(dx: -0.6em)[=]#h(-0.6em)$)

We recall that a monad is a type family
#box[$M: "Type" -> "Type"$] together with two operations: 
  $
    &"pure" : a -> M(a) \
    &"bind" : M(a) -> (a -> M(b)) -> M(b)
  $
satisfying some coherence laws.

*Notation.* We note $m bind f := "bind"(m, f)$.

Morally, one can think of monads as a way of encoding side effects in a pure environment.


One notable monad is the state monad:

*Definition* (state monad)*.* Let $S$ be a type. We define the _state monad_ as the type family
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
  $ #r("hetState")""(Gamma, Delta, v, r) := &{ ;; Gamma } -> [mono(V)(v, { ;; Gamma #r("&") Delta }) | mono(R)(r)] $
  where $Gamma, Delta$ are row variables and $v, r$ are type variables.

Let's unpack this definition.
Dropping the $mono(R)$ case, we get ${ ;; Gamma } -> (v, { ;; Gamma #r("&") Delta })$.
This is the original state monad modified to allow the evaluation to extend its state at the type level.
This will allow us to precisely encode the scope of variables.
For instance, we can translate the assignment $x = 42$ to an expression of type
${ ;; Gamma } -> (mono("int"), { x : mono("int") ;; Gamma })$ and $y$ to an expression
of type ${ y : mono("int") ;; Gamma } -> (mono("int"), { y : mono("int") ;; Gamma })$
(for some value of $Gamma$). The $mono(R)$ case is to allow encoding of early returns:
we will make this more precise once we have defined the _pure_ and _bind_ operations.

*Definition.* The operations associated with the heterogeneous state monad are:
$ 
  &"pure" : v -> "hetState"(Gamma, emptyset, v, bb(0))\
  &"pure"(x) := lambda s. space mono(V)(x, s) \
$
$
  "bind" : &"hetState" (Gamma, Delta, v, r)  \
           &-> (v -> "hetState" (Gamma #r("&") Delta, Delta', b, r)) \
           &-> "hetState" (Gamma, Delta #r("&") Delta', b, r)\ 
  "bind"(m, f) := &lambda Gamma. "match" m(Gamma) "with" \
                 &| mono(V)(v, Gamma') -> f(v)(Gamma') \
                 &| mono(R)(r) -> mono(R)(r) \
$

For this monad, we will also refer to pure as _value_, i.e. $"value"(x) = lambda s. space mono(V)(x, s)$.

The _value_ operation returns a value without accessing or modifying its scope.
The _bind_ operation composes two monadic computations with compatible scopes.
If both $m$ and $f(v)$ evaluate to a $mono(V)$, we get the following chain of scopes :

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

*Definition.* We introduce a new opetation for returning #footnote[
  This is different from the `return` function found in Haskell.
]:
$
  &"return" : r -> "hetState"(Gamma, emptyset, bb(0), r) \
  &"return"(x) := lambda s. space mono(R)(x)
$

Finally, we introduce operations for manipulating variables :

*Definition.* Let $mono(x)$ be a Ruby variable. \
  We define an operation for accessing $mono(x)$:
  $
    &"get" mono(x) : "hetState" ({x: alpha, ..}, emptyset, alpha, bb(0))\
    &"get" mono(x) = lambda Gamma. space mono(V)(Gamma.#r("x"), Gamma) \ 
  $

  As well as one for assigning to $mono(x)$:
  $
    &"set" mono(x) : alpha -> "hetState" (Gamma, {x: alpha}, alpha, bb(0)) \
    &"set" mono(x) space v = lambda Gamma. space mono(V)(v, {Gamma "with" #r("x") = v}]) 
  $

The types of these operations are precise enough to couple types with control flow:
when typing branches (such as an `if` or a `case` expression), you get union types:

#let hS(g, d, v, rr) = $({ ;; #g } -> [mono(V)(#v, { ;; #g #r("&") #d }) | mono(R)(#rr)])$

$
  &#r("hetState")""(Gamma, Delta_1, v_1, r_1) | #r("hetState")""(Gamma, Delta_2, v_2, r_2) \
    &#h(2em) = hS(Gamma, Delta_1, v_1, r_1) | hS(Gamma, Delta_2, v_2, r_2) \
    &#h(2em) = { ;; Gamma } ->
      [mono(V)(v_1, { ;; Gamma #r("&") Delta_1 }) | mono(V)(v_2, { ;; Gamma #r("&") Delta_2 }) | mono(R)(r_1 | r_2)] \
    &#h(2em) <: { ;; Gamma } -> (mono(V)(v_1 | v_2, { ;; Gamma #r("&") (Delta_1 | Delta_2) }) | mono(R)(r_1 | r_2)) \
    &#h(2em) <: #r("hetState")""(Gamma, (Delta_1 | Delta_2), (v_1 | v_2), (r_1 | r_2))
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
      &= [|#r("E")|] bind lambda r. space #trans[$#r("E")_1$] bind lambda a_1. space dots.h.c space #trans[$#r("E")_n$] bind lambda a_n. "value" (r.#r("f")""(a_1, ..., a_n)) \
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
    \
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
attributes, methods, inheritance, the `self` type, and nominal (sub)typing.

=== Translating classes at the type level

We need to encode classes as runtime values in MLsem, since classes are first-class values in Ruby.
We encode classes and instances as recursive records, whose fields contain attributes and methods.
Nominal subtyping is encoded by a special extra field.

The translation of classes is composed of two parts: the RBS declaration is translated to MLsem types
and the Ruby code is translated into an MLsem expression.

Let's take a simple class signature as an example:

// ```ruby
// # Ruby
// class A
//   attr x
//   def initialize(x)
//     @x = x
//   end
//   def get_x()
//     @x
//   end
// end
// ```

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

At the type level, a class generates instance types and a class type.

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
]

The `tyClassIntWrapper` type represents the type of the class singleton.
The fields of the record (except for `__name`) represent the class methods
of the class. In the case of `IntWrapper`, the only one is `new`, whose type was generated
from the signature of `initialize`. The type of `IntWrapper` instances is defined by open
recursion: in `tyIntWrapperRec`, the `'self` type parameter is bound to represent
the `self` type to allow changing when a class inherits from `IntWrapper`.
Finally, the type `tyIntWrapper` closes the recursion, instantiating the self type to `tyIntWrapper`.

We give another example to illustrate how inheritance and nominal typing is encoded:

#figure(caption: [Inheritance example])[
  ```ruby
  class A
    def equal: (self) -> Bool
  end
  class B < A end
  class C < B end
  class D < A end
  ```
] <inherit_ex>

This example produces the following types (omitting the class types):

#figure(caption: [Translation of @inherit_ex])[
  ```ml
  type tyARec('self) =
    { __name : ~Inst__A; eq : 'self -> tyBool .. }
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
The `__name` field encodes nominal typing, ensuring that two different classes with the same
signatures stay distinct for the type checker. However, we want to allow a subclass to be
a subtype of its parent class whenever it is sensible,
so the field must take into account every transtive parents in the inheritance tree (@inherit_tree).
We negate the type to account for variance: we want the `__name` field of a subclass to be 
a subtype of the `__name` of its parent class. Making the `__name` field contravariant with respect
to inheritance mimics the fact that the set of keys in a record is contravariant.

#figure(
  caption: [Inheritance tree of @inherit_ex],
  // https://q.uiver.app/#r=typst&q=WzAsNCxbMSwwLCJcIkFcIiJdLFswLDEsIlwiQlwiIl0sWzAsMiwiXCJDXCIiXSxbMiwxLCJcIkRcIiJdLFswLDFdLFsxLDJdLFswLDNdXQ==
  diagram({
    node((-1, -2), [`A`])
    node((-1.5, -1), [`B`])
    node((-1.5, 0), [`C`])
    node((-0.5, -1), [`D`])
    edge((-1, -2), (-1.5, -1), "->")
    edge((-1.5, -1), (-1.5, 0), "->")
    edge((-1, -2), (-0.5, -1), "->")
  })
) <inherit_tree>

This encoding fixes the issue of subtyping in the presence of inheritance highlighted in @BruEtAl96:
we have
#no-codly[```ml
  tyA = { __name : ~Inst__A; eq : tyA -> tyBool .. }
```]
and
#no-codly[```ml
  tyB = { __name : ~(Inst__A | Inst__B); eq : tyB -> tyBool .. }
```]

Due to `'self` appearing in a contravariant position, `tyB` is not a subtype of `tyA`
despite `B` inheriting from `A`, thus restoring soundness.

=== Encoding classes in MLsem expressions

*Notation.* We note `rec : ('a -> 'a) -> 'a` and `opaque : 'a`.


A class `A` generates a top-level statement of the form (excluding some type coercions for clarity):

```ml
let classA =
  rec (fun (self : tyClassA) ->
    let mut self = self in
    {
      __name = (DummySymbol :> ~Class__A);
      (* class methods *)
    }
  )
```

The `new` class method has a particular translation of the form (again, omitting type coercions):

```ml
new = 
  fun args -> rec (fun (self : tyA) -> 
    let mut self = self in
    self := {
      __name = (DummySymbol :> ~Inst__A); 
      (* instance methods and attributes *)
    };
    (* translation of the initialize method *)
    self
  )
```

In both the class and instance translations, the `name` field is present to reflect
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

*Definition.* We defined an _extract_ operation:
$
  "extract"(("x"_1, ..., "x"_n), #r("E")) := &"match" #trans[#r("E")]""({ "x"_1 = "x"_1; ...; "x"_n = "x"_n }) "with" \
                                             &| mono(V)(v, #r("_")) -> v \
                                             &| mono(R)(r) -> r \
$
The _extract_ operation takes a list of Ruby variables and an expression.

We can then define the translation of a method as:

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

The fact that the monadic state is only managed by the method means that the monadic encoding is transparent
at the type level, so that function types are not polluted with an extra state argument.

RBS allows the programmers to overload methods:

```ruby
def process: (1) -> String
           | (Integer) -> Integer 
           | (Symbol) -> Symbol
```

Contrary to MLsem's intersection types, this overloading mecanism is order-sensitive.
If one passes `1` to `process`, the first overload matches the type of the argument passed and
the second overload is never considered. This type can be rewritten using intersection types:

#no-codly[
  ```mlsem
  (1 -> String) & (Integer \ 1 -> Integer) & (Symbol -> Symbol)
  ```
]

*Notation.* We note this overloading operator with `%`. \
For instance the type of `process` is written as:
$
  #r("((1) -> String) % ((Integer) -> Integer) % ((Symbol) -> Symbol)").
$

*Definition.* We defined _domain_ and _codomain_ functions for RBS types:
$
  "dom"(#r("T")) &:= cases(
    #r("U") &&"if" #r("T") = #r("(U) -> R"),
    "dom"(#r("T")_1) #r("|") "dom"(#r("T")_2) space &&"if" #r("T") = #r("T")_1 #r("%") #r("T")_2,
    "undefined" &&"otherwise"
  ) \
  "cod"(#r("T")) &:= cases(
    #r("R") &&"if" #r("T") = #r("(U) -> R"),
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

#TODO

The full translation can be found in @full_trans.


= Prototype

An implementation of the full translation is available on Github @RbSem.
Several examples can be found in the `test` folder of the repository.
The output can be read (the generated MLsem code should be nicely formatted)
or pasted directly into MLsem @MLsem.

#TODO: give examples of infered types

We give several examples of programs that we are able to type check using
our translation and MLsem:

#columns(2)[
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
  in a type error because `x` is not be defined in case that `b` is falsy,
  but the encoding is precise enough to analyze the branches.
  It can also determine that `z` is defined in all cases after the second `if` expression.
  This sort of flow-based analysis can become very useful if we integrate
  type cases in the future (using `Object#is_a?` @ruby_is_a).
]

#TODO: example for inheritance $arrow.r.double.not$ subtyping

= Conclusion

#TODO: proof of semantic preservation, type variables, f-bounded polymorphism

future work : grad typing

#bibliography("ref.bib", full: true)

#set heading(numbering: "A.1.", supplement: "Appendix")
#counter(heading).update(0)

= Full translation <full_trans>

#TODO: add full translation

= Contexte du stage

