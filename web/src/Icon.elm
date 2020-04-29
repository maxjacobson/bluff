module Icon exposing (arrowRight, closedEye, load, piggyBank)

import Html exposing (img)
import Html.Attributes exposing (src, title)


arrowRight : String -> Html.Html m
arrowRight titleText =
    img [ src "/icons/arrow-right.svg", title titleText ] []


closedEye : String -> Html.Html m
closedEye titleText =
    img [ src "/icons/closed-eye.svg", title titleText ] []


load : String -> Html.Html m
load titleText =
    img [ src "/icons/load.svg", title titleText ] []


piggyBank : String -> Html.Html m
piggyBank titleText =
    img [ src "/icons/piggy-bank.svg", title titleText ] []
