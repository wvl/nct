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

A simple example
----------------

index.html.nct:
    .extends base
    .body main
    <h1>Posts</h1>
    .if posts
    <ul>
      .each posts
      <li>
        <h3>{title}</h3>
        {body}
      </li>
      /each posts
    </ul>
    .else
    <h2>No posts</h2>
    /if
    /body

base.html.nct:
    <html>
      <header>
        <title>{title}</title>
      </header>
      <body>
        <div id="main">
        .body main
          <h1>This is the base, it will be overwritten</h1>
        /body
        </div>
      </body>
    </html>

Syntax
------

### extends

### body

### each

### if

### stamp
