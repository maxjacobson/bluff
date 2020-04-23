module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (div, form, h1, input, p, text)
import Html.Attributes exposing (attribute)
import Html.Events exposing (onInput, onSubmit)
import Url


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , gameID : String
    }


type alias Flags =
    ()


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key url "", Cmd.none )


type Msg
    = UrlRequested Browser.UrlRequest
    | UpdatedGameID String
    | SubmittedGoToGame
    | UrlChanged Url.Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdatedGameID newGameId ->
            ( { model | gameID = newGameId }, Cmd.none )

        SubmittedGoToGame ->
            ( model, Cmd.none )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Model -> Browser.Document Msg
view _ =
    { title = "Bluff"
    , body =
        [ div []
            [ h1 [] [ text "Bluff" ]
            , p []
                [ text "Bluff is a poker game for bluffers. Enter your group's game ID to proceed."
                ]
            , form [ onSubmit SubmittedGoToGame ]
                [ input [ attribute "type" "text", attribute "placeholder" "Your group's game ID", onInput UpdatedGameID ] []
                , input [ attribute "type" "submit", attribute "value" "Go" ] []
                ]
            ]
        ]
    }
