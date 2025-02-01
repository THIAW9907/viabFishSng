breed [boats boat]
breed [villages village]
undirected-link-breed [communication-links communication-link]

globals [
  ;; GIS Data
  myEnvelope
  lac
  place
  exclusionPeche
  lakeCells
  ;; global init variables
  r ; annual growth rate
  k ; carrying capacity in kg
  kLakeCell ; carrying capacity in kg per lake patch
  diffuseBiomass ; %
  InitHeading ; direction initiale des pirogues
  ;; global output
  sumBiomass ; biomasse du lac
  capital_total_1 ; somme des capitaux des pêcheurs Sénégalais
  capital_total_2 ; somme des capitaux des pêcheurs étrangers
  capital_moyen_1 ; capital moyen d'un pêcheur Sénégalais
  capital_moyen_2 ; capital moyen d'un pêcheur étranger
  capitalTotal
  biomassfished
  t1
  t2
;;; éfficacité de la peche
  fish-stock          ;;;;;;
  fishing-efficiency  ;;éfficacité de la pêche
  total-fish-caught          ; Total des poissons capturés
  average-catch-efficiency   ; Efficacité moyenne de la pêche
  stock-durability           ; Durabilité des stocks
  fishing-pressure           ; Pression locale sur les zones de pêche
  initial-fish-stock


  meanMST         ; mean sojourn time on captial MST for for all boat
  medianMFET      ; median exit time on capital  MFET for all boat

  MSTb
  MSTb_l ; list of ticks
  MSTc
  MSTc_l ; list of ticks

  MFETb
  MFETc
]

patches-own[
 lake ; bol
 excluPeche ; bol
 excluPecheCells ; bol
 biomass ; kg
;;; zone de rotation
  zone-id         ; Identifiant unique de la zone de pêche
  zone-usage      ; Nombre d'agents ayant récemment pêché dans cette zone
  rest-period     ; Temps de repos assigné à la zone
]

villages-own[
  lakeVillage ;; bol
]

boats-own[
 ;myVillage
  team ; bol
  ReleveFilet
  capture
  capture_totale
  capital
  capital_total
  firstExitSatifaction  ;; if 9999  = NA  MFET in mathias et al. 2024
  AST                   ;; mean sojourn time  in Mathias et al. 2024 as list
  ASTc                  ;; a count on MST to have one number per boat

  best-spot ; coordonnées du meilleur endroit de pêche     ;;;;;;;;;;;
  stock-info ; estimation des stocks de poissons            ;;;;;;;;;;
  reproduction-info ; période de reproduction des poissons    ;;;;;;;;;
  group-id ; Identifiant du groupe

]

extensions [gis]

to InitiVar
  set r r_i;;0.015 pour rakya
  set k BiomassInit;;((900000 * 1000) / 2144) ; / 1000 pour les tonnes
  set diffuseBiomass diffB_i ;;0.5
  set InitHeading random 360
  set MSTc_l []
  set MSTb_l []
end

to setup
  clear-all
  reset-ticks
  InitiVar

  set myEnvelope gis:load-dataset "data/envelope.shp"
  set lac gis:load-dataset "data/lac.shp"
  set place gis:load-dataset "data/villages.shp"
  set exclusionPeche gis:load-dataset "data/zoneExclusionPeche.shp"
  setup-world-envelope

  ask patches [
    set pcolor gray
    set lake FALSE
    set excluPecheCells FALSE
  ]

  ask patches gis:intersecting place [
    sprout-villages 1 [
      set shape "circle"
      set color yellow
    ]
  ]

  ask patches gis:intersecting lac [
    set pcolor blue
    set lake TRUE
    set excluPecheCells FALSE
    set excluPeche FALSE
  ]

  ask patches gis:intersecting exclusionPeche [
      set lake TRUE
      set excluPecheCells TRUE
      set excluPeche FALSE
  ]

  if ZonesExclusionPeche [
  ask patches with[excluPecheCells = TRUE][
      set pcolor green
      set excluPeche TRUE
  ]]

  ;; Biomasse par patch

  set lakeCells patches with[lake = TRUE]
  let nblakeCells count lakeCells
  set kLakeCell (k / nblakeCells)
  ask lakeCells [
    set biomass kLakeCell
    set initial-fish-stock sum [biomass] of patches with [lake]          ;;;
  ]
set communication-enabled communication-enabled  ;; Initialisez la variable avec la valeur du switch ;;;;;;;
  ask patches with[lake = FALSE][set biomass 0]


  ;; Nombre de pirogue par village
  ;; Dans chaque village en bord de lac, il y a une même proportion de pêcheurs Sénégalais et étrangers
  ;; Création des nouvelles tortues / pirogues sur les patch sélectionnés / là où se situent les villages de bord de lac

  ask villages [
    ifelse any? patches with[pcolor = blue or pcolor = green] in-radius 5 [
      set lakeVillage TRUE
    ][
     set lakeVillage FALSE
    ]
  ]

  let _nbBoatVillage ((nbBoats / count villages with[lakeVillage = TRUE]))
  ;show _nbBoatVillage ;; pour vérifier si l'arrondi tombe juste

  ask villages with[lakeVillage = TRUE][
    let _nearestPatch min-one-of (patches with [pcolor = blue or pcolor = green])[distance myself]
    move-to _nearestPatch ;; on déplace les villages près de l'eau
    ;; Team = 1 : Sénégalais
    if nbBoats > 0 [
      ask patch-here[
        sprout-boats precision(_nbBoatVillage * (ProportionSenegalais / 100)) 0  [
          set color red
          set shape "fisherboat"
          set team 1
          set heading InitHeading
          set capital_total capital_totalI
          set firstExitSatifaction 0
          set AST []
        ]
        ;; Team = 2 : étrangers
        sprout-boats precision((_nbBoatVillage * (1 - (ProportionSenegalais / 100)))) 0 [
          set color green
          set shape "fisherboat"
          set team 2
          set heading InitHeading
          set capital_total capital_totalI
          set firstExitSatifaction 0
          set AST []
        ]
      ]
    ]
  ]
 ;;; form-groups
  let group-counter 0
  ask boats [
    if group-id = 0 [ ; Si l'agent n'a pas encore de groupe
      set group-counter group-counter + 1
      set group-id group-counter
      ;; Ajouter les voisins proches au même groupe
      ask boats in-radius 2 [
        if group-id = 0 [ set group-id group-counter ]
      ]
    ]
  ]                      

 statSummary

end

to setup-world-envelope
gis:set-world-envelope (gis:envelope-of myEnvelope)
end

to go

    ifelse ZonesExclusionPeche [
    ask lakeCells with[excluPecheCells = TRUE] [set excluPeche TRUE]
    ask lakeCells with[excluPeche = TRUE][
      set pcolor scale-color green biomass 0 kLakeCell
  ]
  ask lakeCells with[excluPeche = FALSE][
      set pcolor scale-color blue biomass 0 kLakeCell
  ]][
    ask lakeCells with[excluPecheCells = TRUE] [set excluPeche FALSE]
    ask lakeCells with[excluPeche = FALSE][
      set pcolor scale-color blue biomass 0 kLakeCell
  ]]

  ;print sumBiomass
  ;print sumtest

  ;diffuse biomass diffuseBiomass

  ask lakeCells [
    diffuse_biomass
  ]

  ;statSummary
  ;print sumBiomass
  ;print sumtest

  ask lakeCells [
    grow-biomass
    ;set pcolor scale-color blue biomass 0 (k / count lakeCells) ; quand c'est blanc c'est qu'il y a beaucoup de poisson vs noir plus de poisson
  ]
 ask boats [             
    ;; Partager les informations avant de pêcher
    share-information-group-priority

    ;; Comportement pour choisir le meilleur endroit basé sur les informations reçues
    ifelse any? patches in-radius 5 with [fish-stock > 0] [
      let target-patch max-one-of patches in-radius 5 [fish-stock]
      move-to target-patch
    ] [
      ;; Si aucun stock élevé, déplacer aléatoirement
      rt random 360
      fd 1
    ]
  ]                                                       
  
  if ticks mod 10 = 0 [ update-groups ] ; Mettre à jour les groupes tous les 10 ticks
  share-information-group-priority
  tick       ;;;

  ;statSummary
  ;print sumBiomass
  ;print sumtest


  ; hypothese que mbanais et maliens ne posent pas leurs filets aux mêmes endroits
  ; et ne pechent pas autant de poisson par jour
  ask boats [
  ifelse team = 1
    [
      set ReleveFilet 0 ; 1 relève de filet correspond à une relève de filet sur 1 patch (donc 12 relèves de filet = 1 filet de 3 km)
    set capture_totale 0 ; chaque jour capture initialement 0
    set capital_total capital_total - CoutMaintenance ; cout de sortie par jour
    set capital_total_1 0
    ;set capture 0
    ;set capital 0

    ; 1 tick = 1 journée

    ; pour la mise en place d'une réserve intégrale
    ; si reserve integrale = 4 mois, on peut pêcher 8 mois = 8 * 30 jours
    ifelse ticks mod 360 < ((12 - ReserveIntegrale) * 30)[
      move

    ; pirogue sur un seul patch alors que peche sur 3km de filet donc on fait une boucle pour que la pirogue aille sur plusieurs patch en 1 journée
    ; slider pour le nombre de patch sachant que 1 patch = 250 mètres = 0.25 km donc 12 patch = 3000 mètres = 3 km
    ; tant que les pêcheurs n'ont pas pêcher 1 filet de 3km = tant que relève filet inférieur à 12,
    ; ils continuent de pêcher
     while [ReleveFilet < (LongueurFilet / 250)][
      ;if ReleveFilet < (LongueurFilet / 250)[
      fishingSenegalais
      set capture_totale min (list (capture_totale + capture) QtéMaxPoissonPirogue)
      ;if capture_totale < QtéMaxPoissonPirogue [
      ;while [capture_totale < QtéMaxPoissonPirogue][

      ;set capture_totale capture_totale + capture
      ;set capital_total capital_total + capital
      set capital_total capital_total + capture_totale * PrixPoisson
      ;print capture_totale
      ;print capital_total
      ; 0.8 kg / biomass du patch pour avoir une capture en kg sur 250m (10 kg sur 3000 m donc 0.8 kg sur 250m)
      set ReleveFilet ReleveFilet + 1
      moveForward
      ]

    ][
      set capture 0
      set capture_totale capture_totale + capture
      set capital_total capital_total + capital
    ]
    calculSatisfaction
    set capital_total_1 capital_total_1 + capital_total
    ] ;; fin du if team = 1
    [ ;; debut du if team = 2
      set ReleveFilet 0
    set capture_totale 0
    set capital_total capital_total - CoutMaintenance
    set capital_total_2 0
    ;set capture 0
    ;set capital 0
    ;set capital 0

    ; 1 tick = 1 journée

    ; pour la mise en place de la réserve intégrale
    ; si reserve integrale = 4 mois, peche autorisee pendant 8 mois = 8*30 jours
      ifelse ticks mod 360 < ((12 - ReserveIntegrale) * 30)[
        move

        ; pirogue sur un seul patch alors que peche sur 3km de filet donc on fait une boucle pour que la pirogue aille sur plusieurs patch en 1 journée
        ; slider pour le nombre de patch sachant que 1 patch = 250 mètres = 0.25 km donc 12 patch = 3000 mètres = 3 km
        ; maliens pechent plus donc 1.5 * filet
        while [ReleveFilet < (LongueurFiletEtrangers / 250)][
          fishingEtrangers
          set capture_totale min (list (capture_totale + capture) QtéMaxPoissonPirogueEtrangers)
          set capital_total capital_total + capture_totale * PrixPoisson
          ;let _fishAvalableHere [biomass] of patch-here
          set ReleveFilet ReleveFilet + 1
          moveForward
          ;set capital capital + max list (PrixPoisson *  ((CaptureEtrangers / 12) * _fishAvalableHere) - CoutMaintenance) 0
        ]
      ][
        set capture 0
        set capture_totale capture_totale + capture
        set capital_total capital_total + capital
      ]
    set capital_total_2 capital_total_2 + capital_total
    calculSatisfaction
    ]

  ]
; calculate-statistics
  set sumBiomass sum [biomass] of patches
  set stock-durability (sumBiomass / initial-fish-stock) * 100
 

  if initial-fish-stock > 0 [
    set fishing-pressure (biomassfished / initial-fish-stock) * 100
  ]
 ;;calculate-fishing-efficiency
  if count boats > 0 [
    set fishing-efficiency (biomassfished / count boats)
  ]
 ;;fish
   ask boats [
    if communication-enabled [
      set best-spot max-one-of patches with [lake = 1] [ fish-stock ]
      if best-spot != nobody [
        if [lake] of best-spot = 1 [ move-to best-spot ]
      ]
      set biomassfished biomassfished * 1.2  ;; Augmente l'efficacité avec communication
    ]
    set biomassfished biomassfished + biomassfished
  ]
 ;; Ajout au plot
  if communication-enabled [
    plotxy ticks biomassfished  ;; Trace la biomasse pêchée avec communication
  ]

  caluclG
  if sumBiomass <= 0[stop]
  statSummary

  ;print sumtest

  tick
end

to move
  move-to one-of lakeCells with[excluPeche = FALSE]
end

;; les pecheurs avancent dans une même direction : modelise lorsqu'ils relevent leurs filets
to moveForward
  ;pour dessiner les pecheurs
  ;pen-down

  set heading heading + (random 45 - random 45 + 1)

  let patch_ahead patch-at-heading-and-distance heading 1
  ;show is_fishable? patch_ahead

  ifelse is_fishable? patch_ahead = FALSE [
    set heading random -180
    let patch_ahead_turn patch-at-heading-and-distance heading 1
    if is_fishable? patch_ahead_turn = TRUE[ forward 1]
  ][
    forward 1]

  ;show is_fishable? patch_ahead

  ;pen-up
end

to-report is_fishable? [patch_ahead]
  let fishable? FALSE

  ask patch_ahead [
    if excluPeche = FALSE
  [set fishable? TRUE]
  ]

  report fishable?
end


to fishingSenegalais
  let _fishAvalableHere [biomass] of patch-here

  ; Proportion de poisson capturée par le filet sur le patch
  let PropCaptureSenegalais (PropBiomassPecheSenegalais / 100) * [biomass] of patch-here

  ask patch-here[
    set biomass (_fishAvalableHere - PropCaptureSenegalais) ; biomass en kg ??????
  ]

  set capture PropCaptureSenegalais
  ;set capital (PrixPoisson * capture)

  ; captureSenegalais est en kg par filet donc on divisait par 12 pour l'avoir par patch
  ;ifelse _fishAvalableHere > (captureSenegalais / 12 ) [
    ;ask patch-here [
      ;set biomass (_fishAvalableHere - (captureSenegalais / 12 )) ; 3000m/250m = 12
  ;]
  ;set capture (captureSenegalais / 12)
  ;set capital (PrixPoisson * capture) - CoutMaintenance
  ;]
  ;[ ask patch-here [
  ;  set biomass max list (_fishAvalableHere - (captureSenegalais / 12 )) 0
  ;  ]
  ;  set capture max list(_fishAvalableHere) 0
  ;  set capital (PrixPoisson * capture) - CoutMaintenance
  ;]

end

to fishingEtrangers
  let _fishAvalableHere [biomass] of patch-here

  ; Proportion de poisson capturée par le filet sur le patch
  let PropCaptureEtrangers (PropBiomassPecheEtrangers / 100) * [biomass] of patch-here

  ask patch-here[
    set biomass (_fishAvalableHere - PropCaptureEtrangers) ; biomass en kg ??????
  ]

  set capture PropCaptureEtrangers
  ;set capital (PrixPoisson * capture)
  ;ifelse _fishAvalableHere > (captureEtrangers / 12 ) [
  ;  ask patch-here [
  ;    set biomass (_fishAvalableHere - (captureEtrangers / 12 )) ; 3000m/250m = 12
  ;]
  ;set capture (captureEtrangers / 12)
  ;]
  ;[ ask patch-here [
  ;  set biomass max list (_fishAvalableHere - (captureEtrangers / 12 )) 0
  ;  ]
  ;  set capture max list(_fishAvalableHere) 0
  ;]

end

to diffuse_biomass ; patch procedure
  let _previousBiomass biomass
  let _neighbourTerre count neighbors with[lake = FALSE]

  let _previousBiomassNeighboursLake sum [(1 / 8 * diffuseBiomass * biomass)] of neighbors with[lake = TRUE]
  ;print _previousBiomassNeighboursLake

  set biomass (1 - diffuseBiomass) * _previousBiomass + (1 / 8 * _neighbourTerre * diffuseBiomass * biomass) + _previousBiomassNeighboursLake
  ;print biomass
  ;print kLakeCell
end

to grow-biomass  ; patch procedure
  if biomass > 0 [
    let _previousBiomass biomass
    ;show word "premier terme" (r * _previousBiomass)
    ; show word "sec terme" (1 - (_previousBiomass / k))
    set biomass _previousBiomass + (r * _previousBiomass * (1 - (_previousBiomass / kLakeCell))) ; effort pecheurs de l'equation de Rakya est inclu dans la previousBiomass
  ]
end

to calculSatisfaction
  if capital_total > SatisfactionCapital AND firstExitSatifaction = 0 [
    set firstExitSatifaction ticks
  ]

  ;; mean sojourn time calculation
  if capital_total > SatisfactionCapital [
    set AST lput ticks AST
    set ASTc length AST
  ]


end

to caluclG
  ;;MST et MFET a l'échelle de la simu
  ;; ces indicateurs sont compatible avec le papier de Mathias et al 2024
  set satifsactionCapitalG SatisfactionCapital * nbBoats

  if sumBiomass < satisfactionBiomassG AND MFETb = 0 [
    set MFETb ticks
  ]
  if sumBiomass < satisfactionBiomassG AND ticks > 0 [
    ;  MSTb
    set MSTb_l lput ticks MSTb_l
    set MSTb (length MSTb_l) / ticks
  ]


  if sum [capital_total] of boats > satifsactionCapitalG AND MFETc = 0 [
    set MFETc ticks
  ]

  if sum [capital_total] of boats > satifsactionCapitalG  AND ticks > 0[
    ;  MSTc
    set MSTc_l lput ticks MSTc_l
    set MSTc (length MSTc_l) / ticks
  ]

end

to statSummary
  set sumBiomass sum [biomass] of lakeCells
  ;set sumtest sum [biomass] of patches with[lake = FALSE]
  if any? boats with [team = 1] [
    set capital_moyen_1 mean[capital_total] of boats with [team = 1]
  ]
  ;print capital_moyen_1
  ;set capital_moyen_2 (capital_total_2 / count boats with [team = 2])
  if any? boats with [team = 2] [
    set capital_moyen_2 mean[capital_total] of boats with [team = 2]
  ]
  ;print capital_moyen_2
  set biomassfished sum[capture] of boats
  set capitalTotal capital_moyen_1 + capital_moyen_2
  if any? boats AND ticks > 0 [
    set meanMST mean[ASTc] of boats / ticks
    set medianMFET median[firstExitSatifaction] of boats
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
119
33
553
468
-1
-1
3.025
1
10
1
1
1
0
1
1
1
-70
70
-70
70
0
0
1
ticks
30.0

BUTTON
31
38
98
71
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
32
78
98
111
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

PLOT
590
38
790
188
Lake Biomass Kg
Jour
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sumBiomass"
"pen-1" 1.0 0 -7500403 true "" "plot satisfactionBiomassG"

MONITOR
590
221
675
266
NIL
count boats
17
1
11

BUTTON
32
113
95
146
NIL
go
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
590
263
762
296
nbBoats
nbBoats
0
500
274.0
1
1
NIL
HORIZONTAL

SLIDER
527
500
699
533
PrixPoisson
PrixPoisson
0
10000
1900.0
100
1
CFA/kg
HORIZONTAL

SLIDER
526
544
735
577
CoutMaintenance
CoutMaintenance
0
10000
3000.0
100
1
CFA/Jour
HORIZONTAL

SLIDER
590
378
762
411
LongueurFilet
LongueurFilet
0
10000
2000.0
250
1
Mètres
HORIZONTAL

PLOT
806
38
1097
190
Capital moyen d'un pêcheur Sénégalais par jour
Jour
Capital CFA
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot capital_moyen_1"
"pen-1" 1.0 0 -7500403 true "" "plot SatisfactionCapital"

SLIDER
1074
339
1247
372
ReserveIntegrale
ReserveIntegrale
0
12
0.0
1
1
mois
HORIZONTAL

SWITCH
1281
320
1445
353
ZonesExclusionPeche
ZonesExclusionPeche
1
1
-1000

TEXTBOX
591
336
741
375
La longueur des filets controle le nombre de sorties par jour (3km = 1 sortie)
10
0.0
1

TEXTBOX
1077
250
1263
333
Une réserve intégrale de 8 mois par exemple signifie qu'il y a une interdiction de pêche pendant 8 mois, et sur les 4 restants les autres restrictions peuvent etre mises en place
10
0.0
1

TEXTBOX
1283
277
1433
316
Les zones d'exclusion de pêche correspondent à celles de l'atelier de Mbane de novembre
10
0.0
1

SLIDER
827
378
1046
411
PropBiomassPecheSenegalais
PropBiomassPecheSenegalais
0
100
1.0
0.5
1
%
HORIZONTAL

SLIDER
1077
378
1267
411
QtéMaxPoissonPirogue
QtéMaxPoissonPirogue
0
1000
34.0
1
1
Kg
HORIZONTAL

SLIDER
819
265
994
298
ProportionSenegalais
ProportionSenegalais
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
827
424
1040
457
PropBiomassPecheEtrangers
PropBiomassPecheEtrangers
0
100
3.0
0.5
1
%
HORIZONTAL

SLIDER
590
424
813
457
LongueurFiletEtrangers
LongueurFiletEtrangers
0
10000
3000.0
250
1
Mètres
HORIZONTAL

TEXTBOX
1087
226
1237
246
RESERVES
16
0.0
1

SLIDER
1077
425
1318
458
QtéMaxPoissonPirogueEtrangers
QtéMaxPoissonPirogueEtrangers
0
1000
31.0
1
1
Kg
HORIZONTAL

TEXTBOX
528
478
678
498
CAPITAL
16
0.0
1

TEXTBOX
590
318
740
338
PECHE
16
0.0
1

TEXTBOX
588
203
738
223
POPULATION
16
0.0
1

PLOT
1120
40
1406
190
Capital moyen d'un pêcheur Etranger par jour
Jour
Capital CFA
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot capital_moyen_2"

SLIDER
827
322
999
355
SortieSemaine
SortieSemaine
0
7
6.0
1
1
Jours
HORIZONTAL

INPUTBOX
371
481
494
541
SatisfactionCapital
5000000.0
1
0
Number

INPUTBOX
1170
544
1331
604
satifsactionCapitalG
1.37E9
1
0
Number

INPUTBOX
998
544
1159
604
satisfactionBiomassG
100000.0
1
0
Number

MONITOR
870
505
927
550
NIL
MSTc
2
1
11

MONITOR
870
556
927
601
NIL
MFETc
2
1
11

INPUTBOX
819
196
980
256
capital_totalI
100000.0
1
0
Number

INPUTBOX
993
197
1090
257
BiomassInit
420000.0
1
0
Number

TEXTBOX
1005
606
1155
634
Sans pêche Biomass Max = 462 000
10
0.0
1

MONITOR
932
506
989
551
NIL
MSTb
2
1
11

MONITOR
933
555
990
600
NIL
MFETb
2
1
11

TEXTBOX
860
486
1010
504
A l'échelle de la simu
12
0.0
1

TEXTBOX
837
558
872
597
First Exit Time
9
0.0
1

TEXTBOX
836
514
874
541
Sejour Time
9
0.0
1

TEXTBOX
1016
521
1280
555
Seuil de satisfaction à l'échelle du système 
12
0.0
1

TEXTBOX
832
471
1381
493
---------------------------------------------------------------------------------------------------------------------------------------
12
0.0
1

TEXTBOX
830
630
1372
651
---------------------------------------------------------------------------------------------------------------------------------------
12
0.0
1

TEXTBOX
821
508
836
610
|\n|\n|\n|\n|\n|
12
0.0
1

TEXTBOX
1367
506
1382
608
|\n|\n|\n|\n|\n|
12
0.0
1

TEXTBOX
1224
483
1374
506
Indic Mathias et al.
16
0.0
1

INPUTBOX
38
519
110
579
r_i
0.015
1
0
Number

INPUTBOX
38
580
108
640
diffB_i
0.0
1
0
Number

@#$#@#$#@
## TODO

- les pirogues se déplace au hazard, est-ce qu'on garde un truc comme ça ?
- Pas de réserve, a ajouter
- typha

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

fisherboat
true
0
Polygon -7500403 true true 60 120 75 135 225 135 240 120 240 135 225 150 75 150 60 135
Line -7500403 true 225 120 255 165
Circle -7500403 true true 240 150 30

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
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3650"/>
    <metric>sumBiomass</metric>
    <metric>capital_moyen_1</metric>
    <metric>capital_moyen_2</metric>
    <metric>meanMST</metric>
    <metric>medianMFET</metric>
    <metric>MFETb</metric>
    <metric>MFETc</metric>
    <metric>MSTb</metric>
    <metric>MSTc</metric>
    <steppedValueSet variable="LongueurFilet" first="2000" step="1000" last="3000"/>
    <steppedValueSet variable="LongueurFiletEtrangers" first="2000" step="1000" last="3000"/>
    <steppedValueSet variable="SortieSemaine" first="2" step="1" last="7"/>
    <enumeratedValueSet variable="ZonesExclusionPeche">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheSenegalais">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheEtrangers">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogueEtrangers">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogue">
      <value value="250"/>
    </enumeratedValueSet>
    <steppedValueSet variable="PrixPoisson" first="1000" step="500" last="3000"/>
    <enumeratedValueSet variable="nbBoats">
      <value value="490"/>
    </enumeratedValueSet>
    <steppedValueSet variable="ReserveIntegrale" first="0" step="1" last="6"/>
    <enumeratedValueSet variable="CoutMaintenance">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProportionSenegalais">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mathias_et_al" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3650"/>
    <metric>sumBiomass</metric>
    <metric>biomassfished</metric>
    <metric>capital_moyen_1</metric>
    <metric>capital_moyen_2</metric>
    <metric>meanMST</metric>
    <metric>medianMFET</metric>
    <metric>MFETb</metric>
    <metric>MFETc</metric>
    <metric>MSTb</metric>
    <metric>MSTc</metric>
    <enumeratedValueSet variable="LongueurFilet">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheSenegalais">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogueEtrangers">
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PrixPoisson">
      <value value="1900"/>
    </enumeratedValueSet>
    <steppedValueSet variable="BiomassInit" first="0" step="40000" last="200000"/>
    <steppedValueSet variable="nbBoats" first="50" step="50" last="400"/>
    <enumeratedValueSet variable="LongueurFiletEtrangers">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ReserveIntegrale">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="satifsactionCapitalG">
      <value value="1085000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SatisfactionCapital">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="satisfactionBiomassG">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ZonesExclusionPeche">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SortieSemaine">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capital_totalI">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheEtrangers">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogue">
      <value value="34"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CoutMaintenance">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProportionSenegalais">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mathias_et_al_reserve_integreal" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3650"/>
    <metric>sumBiomass</metric>
    <metric>biomassfished</metric>
    <metric>capital_moyen_1</metric>
    <metric>capital_moyen_2</metric>
    <metric>meanMST</metric>
    <metric>medianMFET</metric>
    <metric>MFETb</metric>
    <metric>MFETc</metric>
    <metric>MSTb</metric>
    <metric>MSTc</metric>
    <enumeratedValueSet variable="LongueurFilet">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheSenegalais">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogueEtrangers">
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PrixPoisson">
      <value value="1900"/>
    </enumeratedValueSet>
    <steppedValueSet variable="BiomassInit" first="0" step="40000" last="200000"/>
    <steppedValueSet variable="nbBoats" first="50" step="50" last="400"/>
    <enumeratedValueSet variable="LongueurFiletEtrangers">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ReserveIntegrale">
      <value value="0"/>
      <value value="2"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="satifsactionCapitalG">
      <value value="1085000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SatisfactionCapital">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="satisfactionBiomassG">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ZonesExclusionPeche">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SortieSemaine">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capital_totalI">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PropBiomassPecheEtrangers">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QtéMaxPoissonPirogue">
      <value value="34"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CoutMaintenance">
      <value value="3000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProportionSenegalais">
      <value value="50"/>
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
@#$#@#$#@
1
@#$#@#$#@
