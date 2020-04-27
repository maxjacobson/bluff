module Icon exposing (arrowRight, closedEye, piggyBank)

import Html exposing (img)
import Html.Attributes exposing (class, src, title)


arrowRight : String -> Html.Html m
arrowRight titleText =
    img [ src "/icons/arrow-right.svg", title titleText ] []


closedEye : Html.Html m
closedEye =
    img [ src "/icons/closed-eye.svg" ] []


piggyBank : String -> Html.Html m
piggyBank titleText =
    img [ src "/icons/piggy-bank.svg", title titleText, class "piggy-bank" ] []
