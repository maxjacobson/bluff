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
    , gameID : Maybe GameID
    , currentPage : Page
    }


type alias GameID =
    String


type Page
    = HomePage
    | GamePage GameID
    | NotFound


type alias Flags =
    ()


pageFromURL : Url.Url -> Page
pageFromURL url =
    case url.path of
        "/" ->
            HomePage

        _ ->
            case gameIDFromUrl url of
                Just gameID ->
                    GamePage gameID

                _ ->
                    NotFound


gameIDFromUrl : Url.Url -> Maybe GameID
gameIDFromUrl url =
    case String.dropLeft 1 url.path of
        "" ->
            Nothing

        anything ->
            Just anything


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key url (gameIDFromUrl url) (pageFromURL url), Cmd.none )


type Msg
    = UrlRequested Browser.UrlRequest
    | UpdatedGameID String
    | SubmittedGoToGame
    | UrlChanged Url.Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdatedGameID newGameId ->
            ( { model | gameID = Just newGameId }, Cmd.none )

        SubmittedGoToGame ->
            case model.gameID of
                Just gameID ->
                    ( model, Nav.pushUrl model.key ("/" ++ gameID) )

                Nothing ->
                    ( model, Cmd.none )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                newPage =
                    pageFromURL url
            in
            ( { model | url = url, currentPage = newPage }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Model -> Browser.Document Msg
view model =
    { title = "Bluff"
    , body =
        [ div []
            [ h1 [] [ text "Bluff" ]
            , case model.currentPage of
                HomePage ->
                    div []
                        [ p [] [ text "Bluff is a poker game for bluffers. Enter your group's game ID to proceed." ]
                        , form [ onSubmit SubmittedGoToGame ]
                            [ input [ attribute "type" "text", attribute "placeholder" "Your group's game ID", onInput UpdatedGameID ] []
                            , input [ attribute "type" "submit", attribute "value" "Go" ] []
                            ]
                        ]

                GamePage gameID ->
                    div []
                        [ p []
                            [ text ("You are on the game page for game ID: " ++ gameID)
                            ]
                        ]

                NotFound ->
                    div [] [ text "Page not found" ]
            ]
        ]
    }
