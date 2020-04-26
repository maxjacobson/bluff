module Icon exposing (arrowRight, closedEye, piggyBank)

import Html exposing (img)
import Html.Attributes exposing (src, title)


arrowRight : String -> Html.Html m
arrowRight altText =
    img [ src "/icons/arrow-right.svg", title altText ] []


closedEye : Html.Html m
closedEye =
    img [ src "/icons/closed-eye.svg" ] []


piggyBank : Html.Html m
piggyBank =
    img [ src "/icons/piggy-bank.svg" ] []
