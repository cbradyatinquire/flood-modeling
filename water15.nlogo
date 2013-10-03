globals [ max-water-height volume-in-system making-movie? end-tick 
  northeast-levee northwest-levee southeast-levee southwest-levee
   ne-bank
   nw-bank
   se-bank
   sw-bank
  ]

patches-own [ altitude water-height low-neighbor  to-transfer ]


to init-patchsets
  set northeast-levee no-patches 
  set northwest-levee no-patches 
  set southeast-levee no-patches
  set southwest-levee no-patches
  set ne-bank no-patches
  set nw-bank no-patches
  set se-bank no-patches
  set sw-bank no-patches  
end

to setup
  ca
  load-terrain
  set max-water-height 1
  set making-movie? false
 
  
  reset-ticks
end

to import-terrain
  let f user-file 
  ifelse (f != false ) [
    file-open f
    while [not file-at-end?] [
     let plist read-from-string file-read-line 
     ifelse (length plist = 3 ) [ 
       let px item 0 plist
       let py item 1 plist
       let alt item 2 plist 
       ask patch px py [ set altitude alt]
     ]
     [ user-message (word "error in terrain file:  line = " plist) ]
    ]
    file-close-all
  ]
  [ user-message "not a readable file" ]
  impose-alt-variation
end

to load-terrain
  ask patches [ 
    ;;set altitude abs pycor + pxcor 
    set altitude .001 * (pycor * pycor + pxcor * pxcor)
    set water-height 0 
    set low-neighbor min-one-of neighbors [ altitude + water-height ] 
  ]
end

to inundate [ px py amount]
  ask patch px py [
    set water-height water-height + amount
    ask neighbors [ set water-height water-height + amount / 2 ]
  ]  
end


to go

  ask patches with [water-height > 0] 
  [ 
    set low-neighbor min-one-of neighbors [ altitude + water-height ]
    let diff  ( altitude + water-height ) - [altitude + water-height] of low-neighbor
    ifelse  (diff > 0)
    [ set diff min (list diff water-height) set to-transfer .5 * diff ]
    [ set to-transfer  0 ]
  ]
  ask patches with [ to-transfer > 0 and water-height > 0 ] 
  [
   ask low-neighbor [ 
     
       set water-height water-height + [to-transfer] of myself 
     
   ] 
   set water-height water-height - to-transfer
   set to-transfer 0
  ]
   
   
  ; ask patches with [ pxcor mod 10 = 0 and pycor mod 10 = 0 ] [ set plabel (precision water-height 1 ) let capped-val min (list water-height amount)  set pcolor scale-color blue capped-val 0 amount ]
   
  ;  ask patches [ let capped-val min (list water-height max-represented-water-height)  set pcolor scale-color blue capped-val 0 max-represented-water-height ]
  set max-water-height max [ water-height ] of patches  + 1
   
   
   if (normal-flow?) [ normal-flow ]

   ifelse (flood-monitor?) [ flood-monitor ]
   [ask patches [  set pcolor scale-color blue water-height 0 50 ]]

   set volume-in-system sum [ water-height ] of patches
   ask patches with [ water-height < .01 ] [ set water-height 0]
   tick
   if (making-movie? = true) [
     if (ticks mod 100 = 0) [
       movie-grab-view
     ]
     if (ticks > end-tick)
     [
       movie-close
       set making-movie? false
     ]
   ]
end


to inundate-with-mouse
  if (mouse-down?) [
    inundate mouse-xcor mouse-ycor 10
    ;stop
  ]
end

to inundate-whole-region 
  ask patches [ inundate pxcor pycor .6 ]
end

to normal-flow
  ask patches with [pxcor = max-pxcor and abs pycor < 5 ] [ set water-height water-height +  1 + flood-from-upstream ]
  ask patches with [pxcor = min-pxcor ] [ if water-height > 1 [ set water-height water-height - 1 ] ]
end

to flood-monitor
  ask patches with [ water-height < .5 ][ set pcolor black ]
  ask patches with [ water-height > .5 ] [ set pcolor brown ]
  ask patches with [ water-height > 2 ] [ set pcolor orange ]
  ask patches with [ water-height > 5 ] [ set pcolor red ]
end

to impose-alt-variation
  let mina  min [ altitude ] of patches
  let maxa  max [ altitude ] of patches
  let diff  maxa - mina

  ask patches [
   let percent ( altitude - mina ) / diff
   set altitude percent * altitude-variation
  ]
end

to make-movie
  ifelse (making-movie? = true) [ user-message "movie already in progress" ]
  [
   movie-start movie-filename
   set end-tick ticks + movie-tick-length
   set making-movie? true
  ]
end


to build-city-on-bank [ which ]
  ifelse (which = "northeast") [
    set ne-bank patches with [ pxcor > 0 and pycor > 9 and pycor < 17 ]
    let ave  mean [altitude] of ne-bank
    ask ne-bank [ set altitude ave ]
    ask ne-bank [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
    set northeast-levee patches with [ pxcor > 0 and pycor = 9 ] 
    ask northeast-levee [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
  ]
  [
    if ( which = "northwest" ) [
      set nw-bank patches with [ pxcor <= 0 and pycor > 9 and pycor < 17 ]
      let ave  mean [altitude] of nw-bank
      ask nw-bank [ set altitude ave ]
      ask nw-bank [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
      set northwest-levee patches with [ pxcor <= 0 and pycor = 9 ] 
      ask northwest-levee [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
    ]
  ]
  ifelse (which = "southeast") [
    set se-bank patches with [ pxcor > 0 and pycor < -9 and pycor > -17 ]
    let ave  mean [altitude] of se-bank
    ask se-bank [ set altitude ave ]
    ask se-bank [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
    set southeast-levee patches with [ pxcor > 0 and pycor = -9 ] 
    ask southeast-levee [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
  ]
  [
    if ( which = "southwest" ) [
      set sw-bank patches with [ pxcor <= 0 and pycor < -9 and pycor > -17  ]
      let ave  mean [altitude] of sw-bank
      ask sw-bank [ set altitude ave ]
      ask sw-bank [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
      set southwest-levee patches with [ pxcor <= 0 and pycor = -9 ] 
      ask southwest-levee [ ask patch pxcor 0 [ set water-height water-height + [water-height] of myself ]  set water-height 0 ]
    ]
  ]
  adjust-levee-heights
end

to adjust-levee-heights
  ask northeast-levee [ set altitude mean [altitude] of ne-bank + northeast-levee-height ]
  ask northwest-levee [ set altitude mean [altitude] of nw-bank + northwest-levee-height ]
  ask southeast-levee [ set altitude mean [altitude] of se-bank + southeast-levee-height ]
  ask southwest-levee [ set altitude mean [altitude] of sw-bank + southwest-levee-height ]
end
@#$#@#$#@
GRAPHICS-WINDOW
358
12
974
649
50
50
6.0
1
10
1
1
1
0
0
0
1
-50
50
-50
50
1
1
1
ticks
30.0

BUTTON
170
108
286
141
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
7
107
68
140
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

BUTTON
8
340
174
373
NIL
inundate-with-mouse
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
1013
21
1218
102
volume in system
volume-in-system
3
1
20

MONITOR
11
374
211
419
NIL
max-water-height
17
1
11

SLIDER
17
470
265
503
max-represented-water-height
max-represented-water-height
1
100
29
1
1
NIL
HORIZONTAL

BUTTON
8
305
175
338
NIL
inundate-whole-region
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
70
107
166
140
NIL
import-terrain
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
158
159
297
192
normal-flow?
normal-flow?
0
1
-1000

PLOT
1016
466
1216
616
volume in system
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
"default" 1.0 0 -16777216 true "" "plot volume-in-system"

MONITOR
12
421
208
466
NIL
min [water-height] of patches
17
1
11

SLIDER
14
10
220
43
altitude-variation
altitude-variation
0
400
130
1
1
meters
HORIZONTAL

MONITOR
15
44
104
89
max [altitude]
max [altitude] of patches
2
1
11

BUTTON
192
51
308
84
NIL
impose-alt-variation
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
105
45
187
90
min [altitude]
min [altitude] of patches
2
1
11

PLOT
1019
318
1215
468
flooded area
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
"default" 1.0 0 -6459832 true "" "plotxy ticks count patches with [ water-height > .5 ]"
"pen-1" 1.0 0 -955883 true "" "plotxy ticks count patches with [ water-height > 2 ]"
"pen-2" 1.0 0 -2674135 true "" "plotxy ticks count patches with [ water-height > 5 ]"

SWITCH
6
159
157
192
flood-monitor?
flood-monitor?
1
1
-1000

PLOT
1034
115
1234
265
plot 1
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
"default" 1.0 1 -16777216 true "" "histogram [water-height] of patches"

BUTTON
79
513
187
546
NIL
make-movie
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
24
546
259
606
movie-filename
test-movie2.mov
1
0
String

SLIDER
24
608
257
641
movie-tick-length
movie-tick-length
200
10000
7000
100
1
ticks
HORIZONTAL

MONITOR
190
504
298
549
NIL
making-movie?
17
1
11

MONITOR
223
250
318
295
NIL
[altitude] of patch mouse-xcor mouse-ycor
2
1
11

BUTTON
5
215
124
248
build city on bank...
build-city-on-bank which-bank
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
125
204
217
249
which-bank
which-bank
"northeast" "northwest" "southeast" "southwest"
0

SLIDER
976
152
1013
317
northeast-levee-height
northeast-levee-height
0
70
24
1
1
NIL
VERTICAL

SLIDER
319
132
356
299
northwest-levee-height
northwest-levee-height
0
70
24
1
1
NIL
VERTICAL

SLIDER
975
357
1012
530
southeast-levee-height
southeast-levee-height
0
70
28
1
1
NIL
VERTICAL

SLIDER
322
368
359
543
southwest-levee-height
southwest-levee-height
0
70
11
1
1
NIL
VERTICAL

BUTTON
198
316
359
349
NIL
adjust-levee-heights
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
264
199
297
flood-from-upstream
flood-from-upstream
0
2
0
.1
1
NIL
HORIZONTAL

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
