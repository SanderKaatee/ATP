;;; Newly added coded is identified with 3 semi-columns (;;;)

turtles-own [
  price                     ; How much each store charges for its product
  area-count                ; The area (market share) that a store held at the end of the last tick
  assets                    ;;; The amount of assets a store has
  age                       ;;; age of store
]

patches-own [
  preferred-store           ; The store currently preferred by the consumer
  customer-utility          ;;; utility of individual customer
  funds                     ;;; funds that the customer is willing to pay for a shop
  travel                    ;;; distance that the customer is willing to travel
]

globals [
  consumers                 ; The patches that will act as consumers, either a vertical line or all patches
  global-customer-utility   ;;; The sum of all the utilities of the patches
  total-global-customer-utility ;;; The sum of global-customer-utility over all ticks combined
  number-of-stores          ;;; number of stores
  store-id                  ;;; store-id
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-consumers
  set total-global-customer-utility 0
  setup-stores
  recalculate-area
  reset-ticks
end

to setup-consumers
  ; Store the agentset of patches that are going to be our
  ; consumers in a global variable for easy reference.
  set consumers ifelse-value layout = "line"
    [ patches with [ pxcor = 0 ] ]
    [ patches ]
    ask consumers [
    ;;; intialize the funds among all consumers with a pareto distribution
      set funds random-pareto pareto-alpha-consumers min-funds
    ;;; intialize the willing distance to travel to a store among all consumers
    ;;; with a normal distrubion
      set travel random-normal  mean-distance std-dev-distance
  ]

end

to setup-stores
  ;;; give the stores id, which we tie to the color of the store
  set store-id 0
  let i 0
  while [ i < initial-number-of-stores ] [
    create-a-store
    set i i + 1
  ]
end

  ;;; funtionality of the add-a-store button
to add-a-store
  create-a-store
end

to go
  ; We accumulate location and price changes as lists of tasks to be run later
  ; in order to simulate simultaneous decision making on the part of the stores

  let location-changes ifelse-value rules = "pricing-only"
    [ (list) ] ; if we are doing "pricing-only", the list of moves is empty
    [ [ new-location-task ] of turtles ]

  let price-changes ifelse-value rules = "moving-only"
    [ (list) ] ; if we are doing "moving-only", the list of price changes is empty
    [ [ new-price-task ] of turtles ]

  foreach location-changes run
  foreach price-changes run
  recalculate-area
  ask turtles [
    balance-budget
  ]
  ;;; create a store randombly based on the start-up-probability
  if ((random 100 < start-up-probability) and (number-of-stores <=  max-stores)) [
    create-a-store
  ]
  set total-global-customer-utility total-global-customer-utility + global-customer-utility ;;; count total-global-customer utility
  tick
end

to recalculate-area
  ; Have each consumer (patch) indicate its preference by
  ; taking on the color of the store it chooses
  ask consumers [
    ;;; if a customer has no preferred-store change the color to white
    set preferred-store choose-store
    ifelse preferred-store = NOBODY
    [set pcolor white]
    ;;; calculate the customer ustility for each customer
    [set customer-utility (1 / ([ price ] of preferred-store)) + (1 / ( distance preferred-store + 1) )
     set pcolor ([ color ] of preferred-store + 2)]

  ]
  ask turtles [
    set area-count count consumers with [ preferred-store = myself ]
  ]
  set global-customer-utility sum [customer-utility] of consumers

end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; turtle procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

; Have the store consider the benefits of taking a unit step in each of the four cardinal directions
; and report a task that will allow the chosen location change to be enacted later
to-report new-location-task

  ; Use `[ self ] of` to turn the `neighbors4` agentset into a shuffled list
  let possible-moves [ self ] of neighbors4 with [ member? self consumers ]

  if area-count > 0 [
    ; Only consider the status quo if we already have a market share, but if we consider it,
    ; put it at the front of the list so it is favored in case of ties in sort-by
    set possible-moves fput patch-here possible-moves
  ]

  ; pair the potential moves with their market shares, and sort these pairs by market share
  let moves-with-market-shares
    sort-by [ [a b] -> last a > last b ]
    map [ move -> list move (market-share-if-move-to move) ] possible-moves

  ; report the first item of the first pair, i.e., the move with the best market share
  let chosen-location first first moves-with-market-shares

  let store self ; put self in a local variable so that it can be "captured" by the task
  report [ ->
    ask store [
      move-to chosen-location
    ]
  ]
end

; report the market share area the store would have if it moved to destination
to-report market-share-if-move-to [ destination ] ; turtle procedure
  let current-position patch-here
  move-to destination
  let market-share-at-destination potential-market-share
  move-to current-position
  report market-share-at-destination
end

to-report potential-market-share
  report count consumers with [ choose-store = myself ]
end

; Have the store consider the revenue from hypothetically increasing or decreasing its price by one unit
; and report a task that will allow the chosen price change to be enacted later
to-report new-price-task

  ; We build a list of candidate prices, keeping the status quo in first, but having -1 and +1 in random
  ; order after that. This order is going to be preserved by the `sort-by` primitive in case of ties,
  ; and we always want the status quo to win in this case, but -1 and +1 to have equal chances
  ;;; added to ability of the shops to adjust their price up to a magnitute of 3. Also the price will
  ;;; never go below 0
  let possible-prices fput price shuffle (list (price - 1) (price + 1) (price + 2) (price - 2) (price + 3) (price - 3))
  foreach possible-prices [pr -> if pr <= 0 [set possible-prices remove pr possible-prices]]

  ; pair each potential price change with its potential revenue
  ; and sort them in decreasing order of revenue
  let prices-with-revenues
    sort-by [ [a b] -> last a > last b ]
    map [ the-price -> list the-price (potential-revenue the-price) ] possible-prices

  let all-zeros? (not member? false map [ pair -> last pair = 0 ] prices-with-revenues)
  let chosen-price ifelse-value all-zeros? and price > 4
    [ price - 3 ] ; if all potential revenues are zero, the store lowers its price as an emergency procedure if it can
    [ first first prices-with-revenues ] ; in any other case, we pick the price with the best potential revenues

  let store self ; put self in a local variable so that it can be "captured" by the task
  report [ ->
    ask store [
      set price chosen-price
    ]
  ]
end

to-report potential-revenue [ target-price ]
  let current-price price
  set price target-price
  let new-revenue (potential-market-share * target-price)
  set price current-price
  report new-revenue
end
;;; calculate the assets of a store based on the assets, area-count, price and cost of living
;;; also change the age of the store
;;; also if the store has less than 0 assets it disappear
to balance-budget
  ; assets = previous assests - bills + revenue
  set assets ( assets + ( area-count * price ) - cost-of-living )
  set age age + 1
  if assets < 0
    [
      set number-of-stores number-of-stores - 1
      die
  ]
end
;;; creates a store, gives it proper id and color based on the id. Gives it assets based on a pareto
;;; distribution
;;; creates pens for plotting the prices, ares, assets and revenues for the stores, for each new store
;;; that appears
;;; adjusts the number of stores variable
to create-a-store
  ask one-of consumers [
    sprout 1 [
      set store-id store-id + 1
      set color store-id * 2 + blue; use the color from the list that we are looping through
      set shape "Circle (2)"
      set size 2
      ifelse number-of-stores > 0 [ set price mean [ price ] of turtles ] [ set price 10 ]
      set assets random-pareto pareto-alpha-stores min-starting-assets

      set-current-plot "prices"
      create-temporary-plot-pen (word who)
      set-plot-pen-color color

      set-current-plot "areas"
      create-temporary-plot-pen (word who)
      set-plot-pen-color color


      set-current-plot "assets"
      create-temporary-plot-pen (word who)
      set-plot-pen-color color

      set-current-plot "revenues"
      create-temporary-plot-pen (word who)
      set-plot-pen-color color
      set number-of-stores number-of-stores + 1

    ]
   ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; patch procedure ;;;
;;;;;;;;;;;;;;;;;;;;;;;

; report the store with the best deal, defined as the smallest sum of price and distance
;;; we changed this function  so the customer choose the store that is the closest and the cheapest or
;;; not to choose any store. In other words can return a store or a NOBODY

to-report choose-store
  let best-store NOBODY
  let potential-stores sort turtles

  foreach potential-stores
  [ current-store ->
    if ( [ price ] of current-store < funds and distance current-store < travel )
    [
     if (best-store = NOBODY)
      [ set best-store current-store]
      if ( [ price ] of current-store < [ price ] of best-store and distance current-store < distance best-store )
      [set best-store current-store] ]
  ]

  report best-store
end

;;; random pareto distribution that takes the pareto index alha and the minimum value in
;;; the distribution
to-report random-pareto [alpha mm]
  report mm / ( 0.000001 + random-float 0.999999 ^ (1 / alpha) )
end

; Copyright 2009 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
500
10
1041
552
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
180
20
280
53
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
180
70
280
103
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
295
70
395
103
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
1405
10
1740
205
revenues
time
revenue
0.0
100.0
0.0
10.0
true
false
"" "ask turtles [\n  set-current-plot-pen (word who)\n  plotxy ticks ( area-count * price )\n]\nif ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS

PLOT
1070
10
1405
205
prices
time
price
0.0
100.0
0.0
10.0
true
false
"" "ask turtles [\n  set-current-plot-pen (word who)\n  plotxy ticks price\n]\nif ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS

PLOT
1070
205
1405
400
areas
time
area
0.0
100.0
0.0
10.0
true
false
"" "ask turtles [\n  set-current-plot-pen (word who)\n  plotxy ticks area-count\n]\nif ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS

CHOOSER
5
67
160
112
rules
rules
"normal" "moving-only" "pricing-only"
0

CHOOSER
5
17
160
62
layout
layout
"plane" "line"
0

PLOT
1275
410
1475
560
Customer utility
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS
"default" 1.0 0 -16777216 true "" "plot global-customer-utility"

PLOT
1070
560
1270
710
Number of  stores
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS
"default" 1.0 0 -16777216 true "" "plot number-of-stores"

PLOT
1480
410
1680
560
Oldest store
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
"default" 1.0 0 -16777216 true "" "plot max [age] of turtles"

SLIDER
5
170
222
203
start-up-probability
start-up-probability
0
100
0.0
1
1
%
HORIZONTAL

SLIDER
5
205
177
238
cost-of-living
cost-of-living
0
20000
1800.0
200
1
NIL
HORIZONTAL

SLIDER
5
240
182
273
initial-number-of-stores
initial-number-of-stores
0
100
0.0
1
1
NIL
HORIZONTAL

BUTTON
300
20
392
53
add a store
add-a-store
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
260
165
432
198
mean-distance
mean-distance
0
40
6.9
0.1
1
NIL
HORIZONTAL

SLIDER
260
230
432
263
min-funds
min-funds
-10
100
17.0
1
1
NIL
HORIZONTAL

SLIDER
10
350
185
383
min-starting-assets
min-starting-assets
0
10000
500.0
100
1
NIL
HORIZONTAL

PLOT
1070
410
1270
560
Free customers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS
"default" 1.0 0 -16777216 true "" "plot count patches with [preferred-store = NOBODY]"

PLOT
1405
205
1740
400
assets
assets
time
0.0
100.0
0.0
10.0
true
false
"" "ask turtles [\n  set-current-plot-pen (word who)\n  plotxy ticks assets\n]\nif ticks > 100                            \n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 100) ticks                                       \n]"
PENS

SLIDER
260
198
437
231
std-dev-distance
std-dev-distance
0
10
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
5
155
155
173
Model Variables:
12
0.0
1

TEXTBOX
260
150
410
168
Consumer Variables:
12
0.0
1

SLIDER
260
265
497
298
pareto-alpha-consumers
pareto-alpha-consumers
0
2
1.09132916932
0.01
1
NIL
HORIZONTAL

TEXTBOX
10
330
160
348
Store Variables:\n
12
0.0
1

SLIDER
10
385
207
418
pareto-alpha-stores
pareto-alpha-stores
0
2
1.09132916932
0.01
1
NIL
HORIZONTAL

SLIDER
6
276
179
309
max-stores
max-stores
0
30
15.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model is a representation of Hotelling's law (1929), which examines the optimal placement of stores and pricing of their goods in order to maximize profit. In Hotelling's original paper, the stores were confined to a single dimension.  This model replicates and extends Hotelling's law, by allowing the stores to move freely on a plane.

In this model, several stores attempt to maximize their profits by moving and changing their prices.  Each consumer chooses their store of preference based on the distance to the store and the price of the goods it offers.

## HOW IT WORKS

Each consumer adds up the price and distance from each store, and then chooses to go to the store that offers the lowest sum. In the event of a tie, the consumer chooses randomly. The stores can either be constrained to one dimension, in which case all stores operate on a line, or they can be placed on a plane. Under the normal rule, each store tries to move randomly in the four cardinal directions to see if it can gain a larger market share; if not, it does not move. Then each store checks if it can earn a greater profit by increasing or decreasing the price of their goods; if not, it does not change the price. This decision is made without any knowledge of their competitors' strategies. There are two other conditions under which one can run this model: stores can either only change prices, or only move their location.

## HOW TO USE IT

Press SETUP to create the stores and a visualization of their starting market share areas.
Press GO to have the model run continuously.
Press GO-ONCE to have the model run once.
The NUMBER-OF-STORES slider decides how many stores are in the world.

If the LAYOUT chooser is on LINE, then the stores will operate only on one dimension. If it is on PLANE, then the stores will operate in a two dimensional space.

If the RULES chooser is on PRICING-ONLY, then stores can only change their price.  If it is on MOVING-ONLY, then the stores can only move.  If it is on NORMAL, all stores can change their prices and move.

## THINGS TO NOTICE

On the default settings, notice that the two stores end up in very close contact and with minimal prices. This is because each store tries to cut into their competitor's fringe consumers by moving closer and reducing their prices.

Also notice how the shapes of the boundaries end up as perpendicular bisectors or hyperbolic arcs. The distance between the stores and their difference in prices determines the eccentricity of these arcs.

Try increasing the store number to three or more, and notice how the store with the most area is not necessarily the most profitable.

Plots show the prices, areas, and revenues of all stores.

## THINGS TO TRY

Try to see how stores behave differently when they are either prohibited from moving or changing their prices.

Try increasing the number of stores. Examine how they behave differently and watch which ones are the most successful.  What patterns emerge?

## EXTENDING THE MODEL

In this model, information is free, but this is not a realistic assumption. Can you think of a way to add a price when stores try to gain information?

In this model, the stores always seek to increase their profits immediately instead of showing any capacity to plan. They are also incapable of predicting what the competitors might do. Making the stores more intelligent would make this model more realistic.

Maybe one way to make the stores more intelligent would be to have them consider their moving and pricing options in conjunction. Right now, they consider the question "would it be good for me to move North" and "would it be good for me to increase my price" completely separately. But what if they asked "would it be good for me to move North AND increase my price"? Would it make a difference in their decision making?

As of now, the consumers are very static. Is there a way to make the consumers move as well or react in some manner to the competition amongst the stores?

Is there a way to include consumer limitations in their spending power or ability to travel? That is, if all stores charge too much or are too far, the consumer could refuse to go to any store.

In this model, if two or more stores are identical from a consumer's point of view, the consumer will choose to go to one of those at random. If the stores are only slightly different for the consumer, is it possible to have the consumer go to either one?

One can extend this model further by introducing a different layout. How would the patterns change, for example, if the layout of the world were circular? What if we just enable world wrapping?

## NETLOGO FEATURES

* Each store can move up to four times each tick, as each store takes test steps in cardinal directions when deciding on its moving strategy. However, as this model is tick based, the user only sees one step per store.

* Notice, also, how the plot pens are dynamically created in the setup code of each plot. There has to be one pen for each store, but we don't know in advance how many there will be, so we use the `create-temporary-plot-pen` primitive to create the pens we need and assign them the right color upon setup.

* In the procedures where a store chooses a new price or location, we make use of a subtle property of the `sort-by` primitive: the fact that the order of items in the initial list is preserved in case of ties during sorting. What we do is that we put the "status quo" option at the front of the list possible moves, but shuffle all other possible moves. Because of that, when we sort the moves by potential revenues, the status quo is always preferred in case of equal revenues.

* What if want to know if all members of a list have a certain property? (This is the equivalent of the "for all" universal quantifier (???) in predicate logic.) NetLogo doesn't have a primitive to do that directly, but we can easily write it ourselves using the `member?` and `map` primitives. The trick is to first [map](http://ccl.northwestern.edu/netlogo/docs/dictionary.html#map) the list to the predicate we want to test. Let's say we want to test if all members of a list are zeros: `map [? = 0] [1 0 0]` will report `[false true true]`, and `map [? = 0] [ 0 0 0 ]` will report `[true true true]`. All we have to is to test the "for all" condition is to make sure that `false` is not a [member](http://ccl.northwestern.edu/netlogo/docs/dictionary.html#member) of that new list: `not member? false map [? = 0] [1 0 0]` will report `false`, and `not member? false map [? = 0] [0 0 0]` will report `true`. We use a variant of this in the `new-price-task` reporter.

* The procedures for choosing new prices and locations do not actually perform these changes right away. Instead, they report `task`s that will be run later in the `go` procedure. Notice how we put `self` in a local variable before creating our task: this is because NetLogo tasks "capture" local variables, but not agent context. See [the "Tasks" section in the NetLogo Programming guide](http://ccl.northwestern.edu/netlogo/docs/programming.html#tasks) for more details about this.

## RELATED MODELS

* Voronoi
* Voronoi - Emergent

## CREDITS AND REFERENCES

Hotelling, Harold. (1929). "Stability in Competition." The Economic Journal 39.153: 41 -57. (Stable URL: https://www.jstor.org/stable/2224214).

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Ottino, B., Stonedahl, F. and Wilensky, U. (2009).  NetLogo Hotelling's Law model.  http://ccl.northwestern.edu/netlogo/models/Hotelling'sLaw.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2009 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2009 Cite: Ottino, B., Stonedahl, F. -->
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
Polygon -7500403 true true 165 285 300 225 300 75 300 225
Polygon -7500403 true true 150 135 15 75 150 135 285 75
Polygon -7500403 true true 0 90 0 240 135 300 0 240
Polygon -7500403 true true 240 150 210 150 210 105 180 180 210 225 210 195 240 195 225 150 240 150 240 195 225 195 225 150 210 195 210 165 210 150

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

circle (2)
false
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 15 15 270

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
set number-of-stores 6
setup
repeat 5 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>total-global-customer-utility / ticks</metric>
    <enumeratedValueSet variable="pareto-alpha-consumers">
      <value value="1.09132916932"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-funds">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="start-up-probability" first="0" step="5" last="100"/>
    <enumeratedValueSet variable="pareto-alpha-stores">
      <value value="1.09132916932"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-distance">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout">
      <value value="&quot;plane&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-starting-assets">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rules">
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cost-of-living" first="0" step="500" last="10000"/>
    <enumeratedValueSet variable="std-dev-distance">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-of-stores">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-stores">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="750"/>
    <metric>total-global-customer-utility / ticks</metric>
    <enumeratedValueSet variable="pareto-alpha-consumers">
      <value value="1.09132916932"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-funds">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="start-up-probability" first="0" step="4" last="100"/>
    <enumeratedValueSet variable="pareto-alpha-stores">
      <value value="1.09132916932"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-distance">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout">
      <value value="&quot;plane&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-starting-assets">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rules">
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cost-of-living" first="0" step="400" last="10000"/>
    <enumeratedValueSet variable="std-dev-distance">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-of-stores">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-stores">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180


0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
