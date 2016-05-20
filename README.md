thx.json
========

A small library of algebraic data types and utilities for manipulating JSON
values in Haxe.

Building
========

A Dockerfile is provided that can be used to create a functioning development
environment.

```
docker build .
docker run --rm -v "$(pwd)":/tmp/hx -w /tmp/hx imsky/haxe 
> hmm install
> haxe build.hxml
```
