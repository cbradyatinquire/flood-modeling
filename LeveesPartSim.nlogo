extensions [ gis ]

breed [ levee-sites levee-site ]

globals [dem wenvelope 
  gisxmin gisxmax gisymin gisymax gisxrange gisyrange giswidth gisheight 
  elevation-of-last-mouse
  egress-patches
  ingress-patches
  egress-rate
  water-exited
  water-entered
  water-exited-since-last-flood
  last-flood-time
  flood-rains
  movie-setup? 
  max-levee-sites
  levee-site-locations
  run-index
  ]

patches-own [ elevation saved-elevation have-levee? water am-edge? am-partsim-site?  run-data ]

levee-sites-own [ user-id location ]

to setup
  ca
  
  set run-index 0
  set flooding? false
  set calibrating? true
  set egress-rate 1
  ask patches [ set pcolor green - 2]
  set dem gis:load-dataset user-file
  gis:set-world-envelope gis:envelope-of dem
  setup-translation-constants
  setup-patch-variables
  setup-other-vars
  gis:paint dem 170
  setup-partsim-vars
  reset-ticks
end

to setup-partsim-vars
    set max-levee-sites  4
    set levee-site-locations [ [-4 3] [-22 -3] [25 -29] [7 -24] ]
    ask patches [ set am-partsim-site? false ]
    foreach levee-site-locations [ ask patch item 0 ? item 1 ? [ set pcolor red set am-partsim-site? true ] ]
    set-backup-elevations
    hubnet-reset
end

to set-backup-elevations
  ask patches [ 
    set saved-elevation elevation 
    set have-levee? false
    set run-data []
  ]
end


to setup-other-vars
  set egress-rate 1.2
  set water-exited 0
  set flood-rains 0
  set water-exited-since-last-flood 0
  set last-flood-time 0
  set movie-setup? false
end

to setup-patch-variables
  ask patches [ 
    set am-edge? false
    let c gis-col-row-from-world pxcor pycor
    set elevation gis:raster-value dem item 0 c item 1 c
  ]
  let bad-data-patches patches with [ not (elevation > 0) ] ;these are "NaN" values
  ask bad-data-patches [ 
    set elevation [elevation] of one-of neighbors with [not member? self bad-data-patches]  
  ]
  set egress-patches patches with [ pxcor = min-pxcor or pycor = min-pycor or pxcor = max-pxcor or pycor = max-pycor ]
  set ingress-patches patches with [ pycor = min-pycor and -5 < pxcor and pxcor < 25 ]
  set egress-patches egress-patches with [ not member? self ingress-patches ]
  
  ask egress-patches [ set am-edge? true ]
  ;ask egress-patches [ set pcolor yellow ]
end

to-report gis-from-world [ x y ]
  let percx (x - min-pxcor) / (max-pxcor - min-pxcor)
  let percy (y - min-pycor) / (max-pycor - min-pycor)
  report (list (gisxrange * percx + gisxmin) (gisyrange * percy + gisymin))
end
  
to-report gis-col-row-from-world [ x y ] 
  let percx (x - min-pxcor) / (max-pxcor - min-pxcor)
  let percy (y - min-pycor) / (max-pycor - min-pycor)
  let candidatex round ((giswidth  - 1) * percx)
  let candidatey round ((gisheight - 1) * (1 - percy) )
  report (list candidatex candidatey  )
end

to setup-translation-constants
  set elevation-of-last-mouse 0
  set wenvelope gis:world-envelope
  set gisxmin item 0 wenvelope
  set gisxmax item 1 wenvelope
  set gisymin item 2 wenvelope
  set gisymax item 3 wenvelope
  set gisxrange gisxmax - gisxmin
  set gisyrange gisymax - gisymin
  set gisheight gis:height-of dem
  set giswidth gis:width-of dem
end

to-report mouse-gis
  ifelse (mouse-down?) [
  let  c gis-from-world mouse-xcor mouse-ycor
  report (word "(" precision item 0 c 3 ", " precision item 1 c 3 ")" )
  ] [
  report "Hold mouse button down"
  ]
end

to-report mouse-gis-colrow
  ifelse (mouse-down?) [
  let cr gis-col-row-from-world mouse-xcor mouse-ycor
  set elevation-of-last-mouse gis:raster-value dem item 0 cr item 1 cr
  report (word "(" item 0 cr ", " item 1 cr")" )
  ] [
  report "Hold mouse button down"
  ]
end




;;RUNTIME
to go 
 tick 
 
 listen-clients
 
 if (calibrating?) [ set egress-rate water-exited / ticks ]
 
 distribute-water-over ingress-patches egress-rate
 
 if (flooding? = true and random 500 = 0) [ flood ]
 

 flow-water
 show-water
end

;observer procedure
to add-water-at [ px py amount ]
  ask patch px py [ add-water-to-me  amount ]
end

;patch procedure
to add-water-to-me [ amount ]
  set water water + amount
end

;;observer.  
;;cause water to spread according to elevation + depth rules
;;one step.
to flow-water
  shed-from-levees
  ask patches with [ water > 0 and have-levee? = false] [
    let myht water + elevation
    let candidates neighbors with [  water + elevation < myht and have-levee? = false ]
    if any? candidates [ 
      ask one-of candidates [ ifelse (am-edge?) [ set water-exited water-exited + 1 set water-exited-since-last-flood water-exited-since-last-flood + 1 ] [ set water water + 1 ] ]
      set water water - 1 
    ]
  ]
end

to shed-from-levees 
  ask patches with [ have-levee? = true ]
  [
    if (water > 0) 
    [
     let to-shed water
     let recipients  neighbors with [water > 0 and have-levee? = false] 
     if any? recipients [ 
      ask one-of recipients [ set water water + to-shed ] 
      set water 0
     ]
    ]
  ]
end

;;observer
;;provide visual indicator of water presence over threshold of 1
to show-water
  ask patches [
     ifelse ( water >= 1 ) 
     [ 
       ifelse  (water > 3 ) [set pcolor blue + 2 - (water / 4) ][set pcolor sky + 3 - water ]
     ]
     [ set pcolor green - 2 ]
     if (have-levee? = true) [ set pcolor brown ]
     if (am-partsim-site? = true) [ set pcolor red ]
  ]
end

;;flash-rain
to distribute-water-over [patchset  units  ]
  let partial units - floor units
  repeat floor units [
   ask one-of patchset
   [ add-water-to-me 1 ] 
  ]
  if (random-float 1 < partial) [ ask one-of patchset [ add-water-to-me 1 ]]
end

to flood 
  set flood-rains flood-rains + 1
  set water-exited-since-last-flood 0
  set last-flood-time ticks
  ;distribute-water-over patches size-of-flood-rain 
  distribute-water-over deep-patches size-of-flood-rain
end

to-report deep-patches
  report patches with [ water >= 8]
end

to deterministic-flood
  ask patches with [ water >= 8 ] [ set water water + 2 ]
end

;;;

to listen-clients 
  while [ hubnet-message-waiting? ]
  [
   hubnet-fetch-message
   ifelse (hubnet-enter-message?) 
   [ ;enter message handler
     create-new-levee-site
   ]
   [ ;not an enter message
     ifelse (hubnet-exit-message?)
     [ ;exit message handler
       ask levee-sites with [ user-id = hubnet-message-source ] [ die ]
     ]
     [ ;non enter/exit messages
       if (hubnet-message-tag = "zoom-level")
       [ zoom-adjust ]
       if ( hubnet-message-tag = "View" ) 
       [ draw-levee ]
     ]
   ] ;non-enter
  ]; while there are messages
  display
end

to draw-levee 
  let coords hubnet-message
  ask patch item 0 coords item 1 coords [ set have-levee? not have-levee? ifelse (have-levee?) [set pcolor brown][set pcolor green - 2] ]
end

to zoom-adjust
  ask levee-sites with [ user-id = hubnet-message-source ]
  [
   hubnet-send-follow user-id self hubnet-message
  ]
end

to create-new-levee-site
  let index count levee-sites
  if (index < max-levee-sites) [
   create-levee-sites 1
   [
     set size .1
    set user-id hubnet-message-source
    set location item index levee-site-locations
    setxy item 0 location item 1 location
    hubnet-send-follow user-id self 10
   ] 
  ]
end

;;;;I/O


to record-patch-data
  ask patches 
  [ 
    let lst  item run-index run-data
    set lst  lput water lst 
    set run-data replace-item run-index run-data lst
  ] 
end

to movie
  go
  if (ticks mod 50 = 0)
  [
    ifelse (movie-setup? = true) [ 
      display 
      movie-grab-interface 
      record-patch-data
      if ticks mod 100 = 0 
      [
         deterministic-flood
         record-patch-data
      ]
      if ticks mod 1500 = 0 
      [
         movie-close
         set movie-setup? false
         stop
      ]
    ]
    [
      if (not member? "No" movie-status)[ movie-close ]
      ask patches [ set run-data lput [] run-data ]
      ask one-of patches [ set run-index length run-data - 1]
      movie-start (word "levee" date-and-time ".mov")
      set movie-setup? true
    ]
  ]
end

to patches-show-diffs
  ask patches [
    let w1 item diff-time (item run-num1 run-data)
    let w2 item diff-time (item run-num2 run-data)
    let dif w2 - w1
    if (dif > 0) [set pcolor orange]
    if (dif < 0) [set pcolor yellow]
    if (dif = 0) [set pcolor black]
  ]
  display
end


to capture-this-diff-movie
  if (not member? "No" movie-status)[ movie-close ]
  movie-start (word "DIFFS" date-and-time ".mov")
  set diff-time 0
  while [ diff-time <= 30 ]
  [
    patches-show-diffs
    display
    movie-grab-interface
    set diff-time diff-time + 1
  ]
  movie-close
end




to export-current-water-levels
  file-open "water-levels3.csv"
  ask patches [
   file-print (word "[" pxcor " " pycor " " elevation " " saved-elevation " " water " " am-edge? " " have-levee? "]")
  ]
  file-close-all
end


to import-water-levels
  let f user-file
  if (f != false) [
    file-open f
    while [not file-at-end? ] [
     let line read-from-string file-read-line
     let px item 0 line
     let py item 1 line
     let pelevation item 2 line
     let psavedelev item 3 line
     let pwater item 4 line
     let pam-edge item 5 line 
     let plevee item 6 line
     ask patch px py [ 
       set water pwater 
       set am-edge? pam-edge
       set have-levee? plevee 
     ]
    ] 
    file-close-all
    go
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
184
10
589
526
39
48
5.0
1
10
1
1
1
0
0
0
1
-39
39
-48
48
1
1
1
ticks
30.0

BUTTON
11
10
101
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
877
16
1077
61
GIS Coordinates of Mouse
mouse-gis
2
1
11

MONITOR
878
108
1043
153
NIL
elevation-of-last-mouse
2
1
11

MONITOR
878
63
1076
108
GIS Col-Row Coords of Mouse
mouse-gis-colrow
1
1
11

BUTTON
10
118
102
151
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
15
311
160
356
NIL
sum [water] of patches
17
1
11

MONITOR
15
359
158
404
NIL
max [water] of patches
17
1
11

SLIDER
13
222
173
255
size-of-flood-rain
size-of-flood-rain
1000
10000
1000
1000
1
NIL
HORIZONTAL

MONITOR
15
263
107
308
NIL
water-exited
17
1
11

MONITOR
623
128
706
173
NIL
flood-rains
17
1
11

SWITCH
621
10
735
43
flooding?
flooding?
1
1
-1000

SWITCH
621
45
736
78
calibrating?
calibrating?
1
1
-1000

BUTTON
12
185
136
218
Manually Flood
flood
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
622
81
825
126
Assumed "Normal" Egress Rate
egress-rate
2
1
11

PLOT
881
167
1071
287
Water in System
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks sum [ water] of patches"

PLOT
619
182
871
332
flood-plot
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-y-range 10 30\nset-plot-x-range (ticks - time-window) ticks"
PENS
"default" 1.0 0 -16777216 true "" "let w [water] of patches\nif (not empty? w )\n[ plotxy ticks max w ]"
"pen-1" 1.0 0 -7500403 true "" "let w [water] of patches\nif (not empty? w )\n[ plotxy ticks mean w ]"

PLOT
621
334
872
484
Patches with water > 1
NIL
NIL
0.0
10.0
0.0
10.0
false
false
"" "set-plot-x-range (ticks - time-window) ticks\nset-plot-y-range min-to-plot max-to-plot"
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks count patches with [ water > 1 ]"

SLIDER
880
333
913
483
min-to-plot
min-to-plot
0
3000
900
100
1
NIL
VERTICAL

SLIDER
919
333
952
483
max-to-plot
max-to-plot
min-to-plot
4000
2900
100
1
NIL
VERTICAL

SLIDER
621
485
873
518
time-window
time-window
0
2000
1781
1
1
ticks
HORIZONTAL

BUTTON
718
557
990
590
add water to deep areas (bathtub)
deterministic-flood
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
24
463
158
496
movie-with-data
movie
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
9
48
164
81
NIL
import-water-levels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
83
123
116
listen-clients
every .1 [ listen-clients ]\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
47
540
124
585
NIL
run-index
17
1
11

SLIDER
189
530
586
563
diff-time
diff-time
0
30
31
1
1
NIL
HORIZONTAL

BUTTON
310
570
460
603
Show Diffs
every .1 [ patches-show-diffs ]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
191
568
306
601
run-num1
run-num1
0
run-index
0
1
1
NIL
HORIZONTAL

SLIDER
466
570
586
603
run-num2
run-num2
0
run-index
1
1
1
NIL
HORIZONTAL

BUTTON
304
618
484
651
NIL
capture-this-diff-movie
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
10
10
405
495
0
0
0
1
1
1
1
1
0
1
1
1
-39
39
-48
48

BUTTON
337
501
400
534
test
NIL
NIL
1
T
OBSERVER
NIL
NIL

SLIDER
12
502
184
535
zoom-level
zoom-level
4
20
10
0.2
1
NIL
HORIZONTAL

@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
