module Icon exposing (closedEye, piggyBank)

import Html exposing (img)
import Html.Attributes exposing (src)


closedEye : Html.Html m
closedEye =
    img [ src "/icons/closed-eye.svg" ] []


piggyBank : Html.Html m
piggyBank =
    img [ src "/icons/piggy-bank.svg" ] []
