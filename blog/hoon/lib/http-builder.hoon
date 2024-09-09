|%
+$  server-state  (map permalink blog-post) 
+$  permalink  @ta
+$  blog-post
  $:  title=@t
      contents=@t
      publish-date=@da
  ==
::
+$  cause
  $:  %req
      uri=@t
      =method
      headers=(list header)
      body=(unit octs)
  ==
::
+$  effect
  $:  %res
      status=@ud
      headers=(list header)
      body=(unit octs)
  ==
::
+$  header  [k=@t v=@t]
+$  octs  [p=@ q=@]
+$  method
  $?  %'GET'
      %'HEAD'
      %'POST'
      %'PUT'
      %'DELETE'
      %'CONNECT'
      %'OPTIONS'
      %'TRACE'
      %'PATCH'
  ==
::
++  to-octs
  |=  bod=@
  ^-  (unit octs)
  =/  len  (met 3 bod)
  ?:  =(len 0)  ~
  `[len bod]
::
++  http-redirect
  |=  [status=@ud location=path]
  ^-  effect
  [%res status ['location' (crip (spud location))]~ (to-octs '<!doctype html><html><pre></pre></html>')]
::
++  html-response
  |=  [status=@ud data=manx]
  ^-  effect
  [%res status ['content-type' 'text/html']~ (to-octs (crip (en-xml data)))]
::
++  method-not-allowed
  |=  [k=server-state c=cause]
  ^-  [(list effect) server-state]
  :_  k
  :~  
    %+  html-response  %405
    ;html
      ;body(style "text-align: center;")
        ;h1: Error 405 Method not allowed
        ;a/"/": Home
      ==
    ==
  ==
::
++  page-not-found
  |=  [k=server-state c=cause]
  ^-  [(list effect) server-state]
  :_  k
  :~  
    %+  html-response  %404
    ;html
      ;body(style "text-align: center;")
        ;h1: Error 404 Page not found
        ;a/"/": Home
      ==
    ==
  ==
::
++  root-handler
  |=  [k=server-state c=cause]
  ^-  [(list effect) server-state]
  ?.  =(method.c %'GET')  (method-not-allowed k c)
  =+  posts=~(tap by k)
  :_  k
  :~
    %+  html-response  %200
    ;html
      ;body(style "text-align: center;")
        ;h1: Hoon Blog
        ;+  ?:  =((lent posts) 0)
              ;div(style "text-align: center;")
                ;h3: No blog posts available
              ==
            ;div(style "margin-bottom:3em")
              ;h3: Blog posts
              ;*  %+  turn  posts  
              |=  [p=permalink b=blog-post]
              ;div
                ;a/"/{(trip p)}": {(trip title.b)}
              ==
            ==
        ;div(style "text-align:center;")
          ;a/"/new-post": New blog post
        ==
      ==
    ==
  ==
::
++  post-handler
  |=  [k=server-state c=cause post=@ta]
  ^-  [(list effect) server-state]
  ?.  =(method.c %'GET')  (method-not-allowed k c)
  =+  p=(~(get by k) post)
  ?~  p  (page-not-found k c)
  =+  p=(need p)
  :_  k
  :~
    %+  html-response  %200
    ;html
      ;body
        ;h1(style "text-align: center; margin-bottom: 1em;"): {(trip title.p)}
        ;code(style "white-space: pre-wrap; display: block;"): {(trip contents.p)}
        ;div(style "margin-top:3em; text-align: center;")
          ;a/"/": Home
        ==
      ==
    ==
  ==
::
++  new-handler
  |_  [k=server-state c=cause now=@da eny=@]
  ++  handle
    ^-  [(list effect) server-state]
    ?+  method.c  (method-not-allowed k c)
        %'GET'
      :_  k  [(html-response %200 get-html)]~
        %'POST'
      ?~  body.c  :_  k  [(html-response %400 post-html-error)]~
      =+  b=(need body.c)
      ?.  =(p.b (met 3 q.b))
        :_  k  [(html-response %400 post-html-error)]~
      (make-blog-post q.b now eny)
    ==
  ++  make-blog-post
    |=  [f=@t now=@da eny=@]
    ^-  [(list effect) server-state]
    =/  in=tape  (weld (decode-url-encoded (trip f)) "&")  ::  split by &
    =|  [title=@t contents=@t =permalink discarded=(list @t)]
    |-
    =+  loc=(find "&" in)
    ?~  loc
      ~&  discarded+discarded
      =/  permalink=@ta  ?.  =(permalink '')  permalink  (scot %p (sham [eny now]))
      =/  k=server-state  (~(put by k) permalink [title contents now])
      :_  k  [(http-redirect %303 /)]~
    =/  nin=tape   (slag +((need loc)) in)
    =/  proc=tape  (scag (need loc) in)
    ?:  (is-eq "title" proc)
      $(in nin, title (prod "title" proc))
    ?:  (is-eq "contents" proc)
      $(in nin, contents (prod "contents" proc))
    ?:  (is-eq "permalink" proc)
      $(in nin, permalink (prod "permalink" proc))
    $(in nin, discarded (into discarded 0 (crip proc)))
  ++  decode-url-encoded
    |=  in=tape
    ^-  tape
    =+  d=(turn in rip-ace)
    =|  o=(list @ud)
    =+  c=0
    =+  l=(lent d)
    |-
    ?:  (gte c l)
      |-
      ?:  (gte 0 (lent o))  d
      =+  cur=(snag 0 o)
      =+  decoded=(decode (swag [cur 3] d))
      ::  weld everything before, current decoded, and everything after
      =+  newd=:(weld (scag cur d) decoded (slag (add 3 cur) d))
      :: replace o with the difference
      =+  newo=(turn (flop (snip (flop o))) |=(x=@ud (sub (add x (lent decoded)) 3)))
      $(o newo, d newd)
    ?.  =('%' (snag c d))
      $(c +(c))
    $(o (flop (into (flop o) 0 c)), c +(c))
  ++  decode
    |=  in=tape
    ^-  tape
    =+  first-char=(snag 1 in)
    %-  trip
    %+  slav  %ux
    %-  crip
    %+  weld  "0x"
    ?:  =('0' first-char)
      (cass (slag 2 in))
    (swag [1 2] in)
  ++  rip-ace
    |=  t=@t
    ?:  =(t '+')  ' '  t
  ++  prod
    |=  [pat=tape in=tape]
    ^-  @t
    (crip (slag +((lent pat)) in))
  ++  is-eq
    |=  [pat=tape in=tape]
    ^-  ?
    =(pat (scag (lent pat) in))
  ++  post-html-error
    ;html
      ;h1: Error 400 Bad Request. You submitted an empty form
      ;a/"/": Home
    ==
  ++  get-html
    ;html
      ;body
        ;h1(style "text-align: center; margin-bottom: 2em;"): New Post
        ;form(action "/new-post", method "POST", style "margin-bottom: 1em;")
          ;div
            ;label(for "title"): Title
            ;input#title(type "text", name "title", style "width: 100%;", required "");
          ==
          ;div
            ;label(for "contents"): Contents
            ;textarea#contents(name "contents", style "width: 100%; height: calc(100vh - 400px);");
          ==
          ;div
            ;label(for "permalink"): Permalink
            ;input#permalink(type "text", name "permalink", placeholder "Auto generated if left blank", style "width: 100%;");
            ;small: Only letters, numbers, underscores, and hyphens allowed
          ==
          ;button(type "submit", style "margin-top: 1em;"): Create Post
        ==
        ;div(style "text-align: center;")
          ;a/"/": Home
        ==
      == 
    ==
  --
::
::
::  copied from zuse.hoon
++  en-xml                                            ::  xml printer
  =<  |=(a=manx `tape`(apex a ~))
  |_  _[unq=`?`| cot=`?`|]
  ::                                                  ::  ++apex:en-xml:html
  ++  apex                                            ::  top level
    |=  [mex=manx rez=tape]
    ^-  tape
    ?:  ?=([%$ [[%$ *] ~]] g.mex)
      (escp v.i.a.g.mex rez)
    =+  man=`mane`n.g.mex
    =.  unq  |(unq =(%script man) =(%style man))
    =+  tam=(name man)
    =+  att=`mart`a.g.mex
    :-  '<'
    %+  welp  tam
    =-  ?~(att rez [' ' (attr att rez)])
    ^-  rez=tape
    ?:  &(?=(~ c.mex) |(cot ?^(man | (clot man))))
      [' ' '/' '>' rez]
    :-  '>'
    (many c.mex :(weld "</" tam ">" rez))
  ::                                                  ::  ++attr:en-xml:html
  ++  attr                                            ::  attributes to tape
    |=  [tat=mart rez=tape]
    ^-  tape
    ?~  tat  rez
    =.  rez  $(tat t.tat)
    ;:  weld
      (name n.i.tat)
      "=\""
      (escp(unq |) v.i.tat '"' ?~(t.tat rez [' ' rez]))
    ==
  ::                                                  ::  ++escp:en-xml:html
  ++  escp                                            ::  escape for xml
    |=  [tex=tape rez=tape]
    ?:  unq
      (weld tex rez)
    =+  xet=`tape`(flop tex)
    !.
    |-  ^-  tape
    ?~  xet  rez
    %=    $
      xet  t.xet
      rez  ?-  i.xet
              %34  ['&' 'q' 'u' 'o' 't' ';' rez]
              %38  ['&' 'a' 'm' 'p' ';' rez]
              %39  ['&' '#' '3' '9' ';' rez]
              %60  ['&' 'l' 't' ';' rez]
              %62  ['&' 'g' 't' ';' rez]
              *    [i.xet rez]
            ==
    ==
  ::                                                  ::  ++many:en-xml:html
  ++  many                                            ::  nodelist to tape
    |=  [lix=(list manx) rez=tape]
    |-  ^-  tape
    ?~  lix  rez
    (apex i.lix $(lix t.lix))
  ::                                                  ::  ++name:en-xml:html
  ++  name                                            ::  name to tape
    |=  man=mane  ^-  tape
    ?@  man  (trip man)
    (weld (trip -.man) `tape`[':' (trip +.man)])
  ::                                                  ::  ++clot:en-xml:html
  ++  clot  ~+                                        ::  self-closing tags
    %~  has  in
    %-  silt  ^-  (list term)  :~
      %area  %base  %br  %col  %command  %embed  %hr  %img  %input
      %keygen  %link  %meta  %param     %source   %track  %wbr
    ==
  --  ::en-xml
--