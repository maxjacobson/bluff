module Icon exposing (arrowRight, closedEye, load, piggyBank, skull)

import Html exposing (img)
import Html.Attributes exposing (class, src, title)


arrowRight : String -> Html.Html m
arrowRight titleText =
    img [ src "/icons/arrow-right.svg", title titleText, class "arrow-right" ] []


closedEye : String -> Html.Html m
closedEye titleText =
    img [ src "/icons/closed-eye.svg", title titleText, class "closed-eye" ] []


skull : String -> Html.Html m
skull titleText =
    img [ src "/icons/skull.svg", title titleText, class "skull" ] []


load : String -> Html.Html m
load titleText =
    img [ src "/icons/load.svg", title titleText, class "load" ] []


piggyBank : String -> Html.Html m
piggyBank titleText =
    img [ src "/icons/piggy-bank.svg", title titleText, class "piggy-bank" ] []
