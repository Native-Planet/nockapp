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
      ;body
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
      ;body
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
      ;body
        ;+  ?:  =((lent posts) 0)
              ;div
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
        ;div
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
        ;h1: {(trip title.p)}
        ;p: {(trip contents.p)}
        ;div(style "margin-top:3em")
          ;a/"/": Home
        ==
      ==
    ==
  ==
::
++  new-handler
  |_  [k=server-state c=cause now=@da]
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
      (make-blog-post q.b now)
    ==
  ++  make-blog-post
    |=  [f=@t now=@da]
    ^-  [(list effect) server-state]
    ::  business logic here
    ~&  form-data+f
    =/  first=blog-post  ['some fake title' 'some random content' (sub now 100.000)]
    =+  k=(~(put by k) ~.some-fake-link first)
    =/  second=blog-post  ['some other article' 'more random content' now]
    =+  k=(~(put by k) ~.another-fake-link second)
    ::  succeeded
    :_  k
    [(http-redirect %303 /)]~
  ++  post-html-error
    ;html
      ;h1: Error 400 Bad Request. You submitted an empty form
      ;a/"/": Home
    ==
  ++  get-html
    ;html
      ;body
        ;h3: New Post
        ;form(action "/new-post", method "POST")
          ;div
            ;label(for "title"): Title
            ;input#title(type "text", name "title", style "width: 100%;");
          ==
          ;div
            ;label(for "contents"): Contents
            ;textarea#contents(name "contents", style "width: 100%; height: 400px;");
          ==
          ;div
            ;label(for "permalink"): Permalink
            ;input#permalink(type "text", placeholder "Auto generated if left blank", style "width: 100%;");
            ;small: Only letters, numbers, underscores, and hyphens allowed
          ==
          ;button(type "submit", style "margin-top: 3em;"): Create Post
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