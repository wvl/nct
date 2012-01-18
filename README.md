nct
---

nct is a nodejs (written in coffeescript) reformulation of my template 
system ideas for nc23, that is:

  * fully asynchronous
  * composable (through Django style parent/blocks)
  * compiled to source for straightforward use in the browser
  * lightweight markup -- the appearance should avoid heavy amounts of
    braces
  * logic free -- push any view logic into the context.
  * track dependencies -- for fast, incremental building in nc23
  * `stamp`: a unique template command for rendering multiple targets


Syntax
------

### extends

### body

### each

### if

### stamp
