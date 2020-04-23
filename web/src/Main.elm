module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (a, div, footer, form, h1, input, p, text)
import Html.Attributes exposing (attribute, href, target)
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
    { currentUrl : Url.Url
    , currentPage : Page
    , key : Nav.Key
    , apiRoot : String
    }


type alias HomePageModel =
    { gameId : String
    }


type alias GamePageModel =
    { gameData : Maybe GameData
    , gameIdFromUrl : String
    }


type Page
    = HomePage HomePageModel
    | GamePage GamePageModel
    | AboutPage
    | NotFound


type alias Flags =
    { apiRoot : String }


pageFromUrl : Url.Url -> Page
pageFromUrl url =
    case url.path of
        "/" ->
            HomePage (HomePageModel "")

        "/about" ->
            AboutPage

        _ ->
            case gameIdFromUrl url of
                Just gameId ->
                    GamePage (GamePageModel Nothing gameId)

                _ ->
                    NotFound


gameIdFromUrl : Url.Url -> Maybe String
gameIdFromUrl url =
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


titleForPage : Page -> String
titleForPage page =
    case page of
        HomePage _ ->
            "Bluff"

        GamePage model ->
            model.gameIdFromUrl ++ " - Bluff"

        NotFound ->
            "Not Found - Bluff"

        AboutPage ->
            "About - Bluff"


cmdWhenLoadingPage : Page -> String -> Cmd Msg
cmdWhenLoadingPage page apiRoot =
    case page of
        GamePage gamePageModel ->
            Http.get
                { url = apiRoot ++ "/games/" ++ gamePageModel.gameIdFromUrl ++ ".json"
                , expect = Http.expectJson GotGameData gameDataDecoder
                }

        HomePage _ ->
            Cmd.none

        NotFound ->
            Cmd.none

        AboutPage ->
            Cmd.none


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        page =
            pageFromUrl url

        cmd =
            cmdWhenLoadingPage page flags.apiRoot
    in
    ( { currentUrl = url
      , currentPage = page
      , key = key
      , apiRoot = flags.apiRoot
      }
    , cmd
    )


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
            let
                newPage =
                    case model.currentPage of
                        HomePage homePageModel ->
                            HomePage { homePageModel | gameId = newGameId }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        SubmittedGoToGame ->
            case model.currentPage of
                HomePage homePageModel ->
                    ( model, Nav.pushUrl model.key ("/" ++ homePageModel.gameId) )

                _ ->
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
                    cmdWhenLoadingPage newPage model.apiRoot
            in
            ( { model | currentUrl = url, currentPage = newPage }
            , cmd
            )

        GotGameData result ->
            let
                newPage =
                    case model.currentPage of
                        GamePage gamePageModel ->
                            case result of
                                Ok newGameData ->
                                    GamePage { gamePageModel | gameData = Just newGameData }

                                Err _ ->
                                    GamePage { gamePageModel | gameData = Nothing }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


viewHeader : Page -> Html.Html Msg
viewHeader page =
    case page of
        HomePage _ ->
            h1 [] [ text "Bluff" ]

        anything ->
            h1 [] [ a [ href "/ " ] [ text "Bluff" ] ]


viewFooter : Html.Html Msg
viewFooter =
    footer []
        [ p [] [ a [ href "/about" ] [ text "About" ] ]
        ]


view : Model -> Browser.Document Msg
view model =
    { title = titleForPage model.currentPage
    , body =
        [ div []
            [ viewHeader model.currentPage
            , case model.currentPage of
                AboutPage ->
                    div []
                        [ p []
                            [ text "It's a game."
                            ]
                        , p []
                            [ a [ href "https://github.com/maxjacobson/bluff", target "_blank" ] [ text "Source code." ]
                            ]
                        ]

                HomePage _ ->
                    div []
                        [ p [] [ text "Bluff is a poker game for bluffers. Enter your group's game ID to proceed." ]
                        , form [ onSubmit SubmittedGoToGame ]
                            [ input [ attribute "type" "text", attribute "placeholder" "Your group's game ID", onInput UpdatedGameID ] []
                            , input [ attribute "type" "submit", attribute "value" "Go" ] []
                            ]
                        ]

                GamePage gamePageModel ->
                    div []
                        [ p []
                            [ text ("You are on the game page for game ID: " ++ gamePageModel.gameIdFromUrl)
                            ]
                        , case gamePageModel.gameData of
                            Just gameData ->
                                p [] [ text ("Players count is " ++ String.fromInt gameData.playerCount) ]

                            Nothing ->
                                text "Loading gameData"
                        ]

                NotFound ->
                    div [] [ text "Page not found" ]
            , viewFooter
            ]
        ]
    }
