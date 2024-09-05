::/+  *wrapper
=>
|%
+$  server-state  %stateless
++  moat  (keep server-state)
::
+$  d             (list @ux)
+$  cause         [@tas =d]
+$  effect        [len=@ud octet=@]
+$  header-info   [=d size=@ud type=@tas]
+$  png-data      $:  width=@ud 
                      height=@ud 
                      bit-depth=@ud 
                      color-type=@ud 
                      compression-method=@ud 
                      filter-method=@ud 
                      interlace-method=@ud
                  ==
::
++  make-effect
  |=  [p=png-data status=@t]
  ^-  (list effect)
  =+  s=:(weld (trip '"status":"') (trip status) (trip '",'))
  =+  j=(crip :(weld (trip '{') s (make-png-json p) (trip '}')))
  ~[[(met 3 j) j]]
++  make-png-json
  |=  p=png-data
  ^-  tape
  =+  width=:(weld (trip '"width":') (trip (scot %ud width.p)) ",")
  =+  height=:(weld (trip '"height":') (trip (scot %ud height.p)) ",")
  =+  color-type=:(weld (trip '"colorType":') (trip (scot %ud color-type.p)) ",")
  =+  compression-method=:(weld (trip '"compressionMethod":') (trip (scot %ud compression-method.p)) ",")
  =+  filter-method=:(weld (trip '"filterMethod":') (trip (scot %ud filter-method.p)) ",")
  =+  interlace-method=:(weld (trip '"interlaceMethod":') (trip (scot %ud interlace-method.p)) ",")
  =+  bit-depth=:(weld (trip '"bitDepth":') (trip (scot %ud bit-depth.p)))
  :(weld width height color-type compression-method filter-method interlace-method bit-depth)
++  count-four
  |=  [raw=d]
  ^-  @ud
  %+  roll
  ^-  (list @)
  :~  (mul (snag 0 raw) 0x100.0000)
      (mul (snag 1 raw) 0x1.0000)
      (mul (snag 2 raw) 0x100)
      (snag 3 raw)
  ==
  add
++  check-crc  |=  raw=d  `d`(slag 4 raw)  ::  do nothing for now
++  recurse-data
  |=  [data=d p=png-data]
  ?:  =((lent data) 0)  (make-effect p 'passed')
  =+  res=(retrieve-data (get-header-info data p))
  $(data -.res, p +.res)
++  get-header-info
  |=  [raw=d p=png-data]
  ^-  [header-info png-data]
  [[(slag 8 raw) (count-four (scag 4 raw)) (crip `(list @)`(slag 4 (scag 8 raw)))] p]
++  retrieve-data
  |=  [h=header-info p=png-data]
  ^-  [d png-data]
::   ::
  ~&  [type.h retrieving+'remainder']
  =+  remainder=(check-crc (slag size.h d.h))
  ?+  type.h  ~&  ['invalid type' type.h]  [remainder p]
  ::
    %'IHDR' 
  ~&  [type.h retrieving+'processed']
  =+  processed=(scag size.h d.h)
  =.  width.p               (count-four (scag 4 processed))
  =.  height.p              (count-four (slag 4 (scag 8 processed)))
  =.  bit-depth.p           `@ud`(snag 8 processed)
  =.  color-type.p          `@ud`(snag 9 processed)
  =.  compression-method.p  `@ud`(snag 10 processed)
  =.  filter-method.p       `@ud`(snag 11 processed)
  =.  interlace-method.p    `@ud`(snag 12 processed)
  [remainder p]
  ::
    %'IDAT'
  ~&  'ignoring data for now'
  [remainder p]
  ::
    %'IEND'
  ~&  'EOF'
  [remainder p]
==
::
--
::
~&  %serving
=<  $
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
  !!
::
::  +poke: external apply
::
++  poke
  |=  [eny=@ our=@ux now=@da dat=*]
  ^-  [(list effect) server-state]
  =/  sof-cau=(unit cause)  ((soft cause) dat)
  ?~  sof-cau
    ~&  "cause incorrectly formatted!"
   !!
  :_  k
  =+  cau=(need sof-cau)
  ?+  -.cau  (make-effect *png-data 'invalid-type')
      %png
    ::  check the first 8 bytes of the cause is the png signature
    =/  signature=(list @ux)  ~[0x89 0x50 0x4e 0x47 0xd 0xa 0x1a 0xa]
    ?.  =(signature `(list @ux)`(scag 8 d.cau))  (make-effect *png-data 'invalid-png-signature')
    =+  data=(slag 8 d.cau)
    (recurse-data data *png-data)
      %fake
      (make-effect *png-data 'fake-mime')
  ==
--