/+  *wrapper, h=http-builder
=>
|%
++  moat  (keep server-state:h)
::
--
::
~&  %serving
%-  moat
^-  fort:moat
|_  k=server-state:h
::
::  +load: upgrade from previous state
::
++  load
  |=  arg=*
  ^-  [(list *) *]
  !!
::
::  +peek: external inspect
::
++  peek
  |=  =path
  ^-  (unit (unit *))
  !!
::
::  +poke: external apply
::
++  poke
  |=  [eny=@ our=@ux now=@da dat=*]
  ^-  [(list effect:h) server-state:h]
  =/  sof-cau=(unit cause:h)  ((soft cause:h) dat)
  ?~  sof-cau
    ~&  "cause incorrectly formatted!"
    ~&  dat
    !!
  =/  uri=path  (stab uri.u.sof-cau)
  ~&  [method.u.sof-cau uri]
  ?+    uri  (page-not-found:h k u.sof-cau)
    [~]            (root-handler:h k u.sof-cau)
    [%new-post ~]  ~(handle new-handler:h k u.sof-cau now eny)
    [* ~]          (post-handler:h k u.sof-cau i.uri)
  ==
--
