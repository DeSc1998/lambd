# lambd
An Implementation of the lambda-calculus in zig

## Quick Start

Run the following:
```shell
$ zig build run -- file
```
and replace `file` with the file you want to evaluate.

NOTE: zig is still in beta. The version used is: `0.11.0`

## Syntax

Any text file can be interpreted and will be as follows:

### Term

any of the following three 

### Symbol

any amout of characters excluding these `()\.`

examples:
```
a
asdf
hello-world
,,,,,:::;;;
{[}{}{]}
#$%^#$%^==++-!@
```

### Application

two whitespace seperated terms enclosed by parenteses

example:
```
(a b)
```

### Lambda

a backslash followed by a symbol then a dot then another term

examples:
```
\x. x
\x. (x x)
\f. \g. (f g)
```

## Basic Stuff

### Bindings

If you have a large enough expression it might be useful to bind said expression to a variable to reuse it in a deeper context.
The way you can do so is by wrapping the deeper context in to a lambda where the argument represents the expression and 
apply your large expression to that lambda. example:

```
(\f. (f 15) \x. ((* ((* ((+ 3) 4)) x))))
```

here `f` is our representation for the expression and `(f x)` is the deeper context.

*TODO: might have to add more stuff here* 
