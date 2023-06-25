# lambd
An Implementation of the lambda-calculus in zig

## Quick Start

Run the following:
```shell
$ zig build run -- file
```
and replace `file` with the file you want to evaluate.

NOTE: zig is still in beta. The version used is: `0.11.0-dev.3747+7b5bd3a93`

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

TODO