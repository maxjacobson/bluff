module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (div, form, h1, input, p, text)
import Html.Attributes exposing (attribute)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode as D exposing (Decoder, field, string)
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
    , gameData : Maybe GameData
    }


type alias GameID =
    String


type Page
    = HomePage
    | GamePage GameID
    | NotFound


type alias Flags =
    ()


pageFromUrl : Url.Url -> Page
pageFromUrl url =
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


gameDataDecoder : Decoder GameData
gameDataDecoder =
    D.map3 GameData
        (D.field "id" D.string)
        (D.field "players_count" D.int)
        (D.field "spectators_count" D.int)


cmdWhenLoadingPage : Page -> Cmd Msg
cmdWhenLoadingPage page =
    case page of
        GamePage gameID ->
            Http.get
                { url = "http://localhost:3000/games/" ++ gameID ++ ".json"
                , expect = Http.expectJson GotGameData gameDataDecoder
                }

        HomePage ->
            Cmd.none

        NotFound ->
            Cmd.none


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url

        cmd =
            cmdWhenLoadingPage page
    in
    ( Model key url Nothing page Nothing, cmd )


type Msg
    = UrlRequested Browser.UrlRequest
    | UpdatedGameID String
    | SubmittedGoToGame
    | UrlChanged Url.Url
    | GotGameData (Result Http.Error GameData)


type alias GameData =
    { identifier : String
    , playerCount : Int
    , spectatorCount : Int
    }


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
                    pageFromUrl url

                cmd =
                    cmdWhenLoadingPage newPage
            in
            ( { model | url = url, currentPage = newPage }
            , cmd
            )

        GotGameData result ->
            let
                gameData : Maybe GameData
                gameData =
                    case result of
                        Ok gameAsString ->
                            Just gameAsString

                        Err _ ->
                            Nothing
            in
            ( { model | gameData = gameData }, Cmd.none )


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
                        , case model.gameData of
                            Just gameData ->
                                p [] [ text ("Players count is " ++ String.fromInt gameData.playerCount) ]

                            Nothing ->
                                text "Loading gameData"
                        ]

                NotFound ->
                    div [] [ text "Page not found" ]
            ]
        ]
    }
