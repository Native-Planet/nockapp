::/+  *wrapper
~&  %outermost
=>
|%
::
+$  server-state  (map item=@t done=?)
+$  cause  [@tas item=@t]
+$  effect  [%msg @t]
++  moat  (keep server-state)
--
::
~&  %serving
=<  $
~&  %inside-buc-serving
%-  moat
^-  fort:moat
|_  k=server-state
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
  |=  path=*
  ^-  (unit (unit *))
  ~&  "retrieving state"
  =+  tasks=~(tap by k)
  
  :+  ~  ~ 
  :-  (turn (skim tasks |=(x=[@t ?] =(| +:x))) |=(y=[@t ?] -:y))::  not done
  (turn (skim tasks |=(x=[@t ?] +:x)) |=(y=[@t ?] -:y))  ::  done
::
::  +poke: external apply
::
++  poke
  ~&  %poking
  |=  [eny=@ our=@ux now=@da dat=*]
  ^-  [(list effect) server-state]
  ~&  dat+dat
  =/  sof-cau=(unit cause)  ((soft cause) dat)
  ?~  sof-cau
   ~&  "cause incorrectly formatted!"
    !!
  =/  =cause  u.sof-cau
  ~&  cause+cause
  =.  k  
  ?+  -.cause  ~&  ["invalid request" -.cause]  !!
    %add  (~(put by k) item.cause |)
    %delete  (~(del by k) item.cause)
    %toggle  (~(put by k) item.cause =(| (~(got by k) item.cause)))
  ==
  :_  k
  [%msg 'placeholder']~
--
