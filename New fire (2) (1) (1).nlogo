; Declare globals, breeds, and patch/turtle properties
globals [
  initial-trees   
  burned-trees   
  wind-direction
  safe-evacuees  
  base
  max-x          
  max-y
  evacuation-point
  total-evacuated
]

breed [fires fire]    
breed [embers ember]    
breed [firefighters firefighter]
breed [people person]
breed [houses house]
breed [water-sprays water-spray]
breed [intersections intersection]

patches-own [
  burning-duration
  exit?
  fuel
  can-burn?
  water-level-patch
  is-road?
  road-type
]

firefighters-own [
  water-level
  is-spraying?
]

people-own [evacuated?]
houses-own [residents]

; Setup procedure: Initializes the world
to setup
  clear-all
  resize-world 0 90 0 40
  set-patch-size 15
  set max-x 90
  set max-y 40
  setup-landscape
  setup-road-network
  setup-patch-states
  setup-houses
  setup-population
  setup-fire
  setup-firefighter-base
  setup-evacuation-point
  set initial-trees count patches with [pcolor = green]
  set burned-trees 0
  set base patch 0 0
  set total-evacuated 0
  reset-ticks
end

; Road network creation
to setup-road-network
  ; Main roads (black, two-directional)
  ask patches [
    ; Horizontal main roads
    if (pycor = 0) or (pycor = 20) or (pycor = 40) [
      set pcolor black  ; Black color for roads
      set is-road? true
      set road-type "main"
    ]
    ; Vertical main roads
    if (pxcor = 0) or (pxcor = 30) or (pxcor = 60) or (pxcor = 90) [
      set pcolor black
      set is-road? true
      set road-type "main"
    ]
  ]
  
  ; Secondary roads (black, two-directional)
  ask patches [
    ; Horizontal secondary roads
    if (pycor = 10) or (pycor = 30) [
      set pcolor black  ; Black color for roads
      set is-road? true
      set road-type "secondary"
    ]
    ; Vertical secondary roads
    if (pxcor = 15) or (pxcor = 45) or (pxcor = 75) [
      set pcolor black
      set is-road? true
      set road-type "secondary"
    ]
  ]
  
  ; Create intersections at road crossings
  ask patches with [is-road?] [
    if any? neighbors with [is-road?] [
      if not any? intersections-here [
        sprout-intersections 1 [
          set hidden? true
        ]
      ]
    ]
  ]
end

; Landscape creation
to setup-landscape
  ask patches [
    if random-float 2.1 < 2 [ set pcolor green ] 
    if pcolor != green [ set pcolor brown ]
    set exit? false
    set is-road? false
  ]
  ; Set exit area
  ask patches with [pxcor = max-pxcor and pycor > 15 and pycor < 25] [
    set pcolor yellow
    set exit? true
  ]
end

; Set patch states
to setup-patch-states
  ask patches [
    set can-burn? true  ; All patches can burn, including roads
    set water-level-patch 0
    if pxcor = 0 or pxcor = max-x or pycor = 0 or pycor = max-y [
      set can-burn? false  ; Only the edges of the world cannot burn
    ]
  ]
end

; House setup: Create houses on a grid away from roads
to setup-houses
  let house-spacing 1.5  ; Space between houses
  let min-distance-from-road 2  ; Minimum distance from roads

  ask patches [
    if (pxcor mod house-spacing = 0) and (pycor mod house-spacing = 0) [
      if not any? patches in-radius min-distance-from-road with [is-road?] and
         not any? houses-on patches in-radius house-spacing [
        sprout-houses 1 [
          set color gray
          set size 2
          set shape "house"
          set residents random 5 
        ]
      ]
    ]
  ]
end

; Setup population: Create firefighters and people (from houses)
to setup-population
  create-firefighters 25 [
    move-to one-of patches with [is-road?]
    set color red
    set size 2.0
    set shape "truck"
    set water-level 100
    set is-spraying? false
  ]
  ask houses [
    if residents > 0 [
      hatch-people residents [
        set color white
        set size 0.8
        set shape "person"
        set evacuated? false
      ]
    ]
  ]
end

; Initialize fires on green patches that are not roads
to setup-fire
  ask n-of 3 patches with [pcolor = green and not is-road?] [ ignite ]
  set wind-direction one-of [0 90 180 270]
end

; Setup firefighter base: Place a house as the base on a road patch
to setup-firefighter-base
  create-houses 1 [
    move-to one-of patches with [is-road?]
    set color red
    set size 2.5
    set shape "house"
    set residents 0
  ]
end

; Setup evacuation point: Use an exit area
to setup-evacuation-point
  set evacuation-point one-of patches with [pxcor = max-pxcor and pycor > 15 and pycor < 25]
  ask evacuation-point [
    set pcolor yellow
    set exit? true
  ]
end

; Ensure agents remain in bounds
to stay-in-bounds
  if xcor < 0 [ set xcor 0 ]
  if xcor > max-x [ set xcor max-x ]
  if ycor < 0 [ set ycor 0 ]
  if ycor > max-y [ set ycor max-y ]
end

; Main go procedure: Agents act concurrently using separate ask commands.
to go
  if not any? turtles [ stop ]
  
  ; Each agent type acts in parallel (the built-in ask ensures that)
  ask fires [ spread-fire ]
  ask embers [ fade-embers ]
  ask firefighters [ manage-firefighters ]
  ask people [ evacuate-people ]
  ask patches [ update-water-effects ]
  
  if ticks mod 100 = 0 [
    set wind-direction one-of [0 90 180 270]
  ]
  
  tick
end

; --- Agent procedures ---

; Fire spread: Each fire agent spreads to its valid neighbors.
to spread-fire
  let valid-neighbors neighbors4 with [
    (pcolor = green or is-road?) and  ; Fire can spread on green patches and roads
    can-burn? and
    not any? fires-here and
    water-level-patch < 0.5
  ]
  
  ask valid-neighbors [
    let spread-chance 5 - (water-level-patch * 2)
    if spread-chance > 0 and random-float 9 < spread-chance [
      ignite
    ]
  ]
  
  ; Convert self into an ember after spreading
  set breed embers
end

; Ignite: Create a fire on the patch if conditions allow.
to ignite
  if can-burn? and water-level-patch < 1 [
    sprout-fires 1 [
      set color red
      set shape "fire"
    ]
    set pcolor orange
    set burned-trees burned-trees + 1
  ]
end

; Fade embers: Slowly reduce ember color and remove them when faded.
to fade-embers
  set color color - 0.005
  if color < red - 3.5 [
    set pcolor color
    die
  ]
end

; Manage firefighter behavior
to manage-firefighters
  if water-level <= 20 [
    move-to-base
    set is-spraying? false
  ]
  let target-patch min-one-of (patches with [any? fires-here]) [distance myself]
  if target-patch != nobody [
    let nearest-road-to-fire min-one-of patches with [is-road?] [distance target-patch]
    if nearest-road-to-fire != nobody [
      face nearest-road-to-fire
      move-along-road
      if distance target-patch < 3 [
        set is-spraying? true
        spray-water
        set color blue
      ]
    ]
  ]
end

; Spray water to extinguish fires
to spray-water
  if water-level > 0 [
    repeat 1 [
      hatch-water-sprays 1 [
        set color blue
        set shape "dot"
        set size 1
        set heading ([heading] of myself + random 45 - 22.5)
        repeat 3 [
          fd 0.5
          ask patches in-radius 1 [
            set water-level-patch water-level-patch + 0.5
            if water-level-patch > 5 [ set water-level-patch 5 ]
            if pcolor != blue [
              set pcolor scale-color blue water-level-patch 0 5
            ]
            ask fires-here [
              die
              set burned-trees burned-trees - 1
            ]
          ]
        ]
        die
      ]
    ]
    set water-level water-level - 0.5
  ]
end

; Update water effects on patches (e.g., drying out)
to update-water-effects
  if water-level-patch > 0 [
    ifelse water-level-patch > 0.5 [
      set pcolor scale-color blue water-level-patch 0 5
    ] [
      if pcolor = blue [ set pcolor brown ]
    ]
    set water-level-patch water-level-patch - 0.02
    if water-level-patch < 0.1 [
      set water-level-patch 0
      if pcolor = blue [ set pcolor brown ]
    ]
  ]
end

; Move firefighter to base when low on water
to move-to-base
  face base
  move-along-road
  if patch-here = base [
    set water-level 100
    set heading 0
  ]
end

; Move along roads: Ensures firefighters follow roads
to move-along-road
  if not [is-road?] of patch-here [
    let nearest-road min-one-of patches with [is-road?] [distance myself]
    if nearest-road != nobody [
      move-to nearest-road
    ]
  ]
  
  if [is-road?] of patch-ahead 1 [
    fd 1
  ]
  
  if any? intersections-here [
    let valid-directions []
    foreach [0 90 180 270] [ [dir] ->  
      let target-patch patch-at-heading-and-distance dir 1
      if target-patch != nobody and [is-road?] of target-patch [
        set valid-directions lput dir valid-directions
      ]
    ]
    if not empty? valid-directions [
      set heading one-of valid-directions
    ]
  ]
  
  stay-in-bounds
end

; Evacuate people: Agents head for an exit via safe roads.
to evacuate-people
  ifelse [is-road?] of patch-here [
    ; On road: move towards exit while avoiding fires
    let nearest-exit min-one-of patches with [exit?] [distance myself]
    if nearest-exit != nobody [
      let safe-roads neighbors with [
        is-road? and 
        not any? fires in-radius 3 and
        not any? embers in-radius 2
      ]
      if any? safe-roads [
        let next-road min-one-of safe-roads [distance nearest-exit]
        if next-road != nobody [
          face next-road
          fd 0.5
        ]
      ]
      ; If no safe roads available, try to retreat away from fire
      if any? fires in-radius 3 [
        let nearest-fire min-one-of fires [distance myself]
        if nearest-fire != nobody [
          face nearest-fire
          rt 180
          fd 1
        ]
      ]
    ]
  ] [
    ; Not on road: move towards the nearest safe road
    let safe-roads patches with [
      is-road? and 
      not any? fires in-radius 3 and
      not any? embers in-radius 2
    ]
    if any? safe-roads [
      let nearest-safe-road min-one-of safe-roads [distance myself]
      if nearest-safe-road != nobody [
        face nearest-safe-road
        fd 0.5
      ]
    ]
    if any? fires in-radius 3 [
      let nearest-fire min-one-of fires [distance myself]
      if nearest-fire != nobody [
        face nearest-fire
        rt 180
        fd 1
      ]
    ]
  ]
  
  stay-in-bounds
  
  ; Avoid houses and fires by random turns
  if any? houses-on patch-ahead 1 [ rt random 90 - 45 ]
  if any? fires in-radius 2 [ rt (180 + random 90) - 45 ]
  
  ; Check for exit: If reached, count evacuation and remove the person
  if [exit?] of patch-here [
    set total-evacuated total-evacuated + 1
    die
  ]
end

; Update the evacuation monitor
to check-evacuation
  set safe-evacuees total-evacuated
end

@#$#@#$#@
GRAPHICS-WINDOW
260
35
1633
659
-1
-1
15
1
10
1
1
1
0
1
1
1
0
90
0
40
1
1
1
ticks
30

BUTTON
0
0
180
60
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
0
65
180
125
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
1

MONITOR
5
130
175
189
total-evacuated
total-evacuated
17
1
18
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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0
-0.2 0 0 1
0 1 1 0
0.2 0 0 1
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@

@#$#@#$#@
