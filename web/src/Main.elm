module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (a, div, footer, form, h1, input, p, span, strong, text)
import Html.Attributes exposing (attribute, disabled, href, target, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode as D exposing (Decoder, field, string)
import Time
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
    , humanUuid : String
    }


type alias HomePageModel =
    { gameId : String
    }


type alias GamePageModel =
    { gameResponse : Maybe GameResponse
    , gameIdFromUrl : String
    }


type Page
    = HomePage HomePageModel
    | GamePage GamePageModel
    | AboutPage
    | NotFound


type alias Flags =
    { apiRoot : String
    , humanUuid : String
    }


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


posixDecoder : Int -> Decoder Time.Posix
posixDecoder millis =
    D.succeed (Time.millisToPosix millis)


gameDataDecoder : Decoder GameData
gameDataDecoder =
    D.map4 GameData
        (D.field "id" D.string)
        (D.field "last_action_at" D.int |> D.andThen posixDecoder)
        (D.field "spectators_count" D.int)
        (D.field "status" D.string |> D.andThen gameStatusDecoder)


gameStatusDecoder : String -> Decoder GameStatus
gameStatusDecoder status =
    if status == "pending" then
        D.succeed Pending

    else if status == "playing" then
        D.succeed Playing

    else if status == "complete" then
        D.succeed Complete

    else
        D.fail ("Unknown status: " ++ status)


humanDataDecoder : Decoder HumanData
humanDataDecoder =
    D.map2 HumanData
        (D.field "nickname" D.string)
        (D.field "heartbeat_at" D.int |> D.andThen posixDecoder)


type alias GameResponse =
    { gameData : GameData
    , human : HumanData
    }


type alias AvailableGameIdResponse =
    { gameId : String
    }


availableGameIdResponseDecoder : Decoder AvailableGameIdResponse
availableGameIdResponseDecoder =
    D.map AvailableGameIdResponse
        (D.at [ "data", "id" ] D.string)


gameResponseDecoder : Decoder GameResponse
gameResponseDecoder =
    D.map2 GameResponse
        (D.field "data" gameDataDecoder)
        (D.at [ "meta", "human" ] humanDataDecoder)


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


cmdWhenLoadingPage : Page -> String -> String -> Cmd Msg
cmdWhenLoadingPage page apiRoot humanUuid =
    case page of
        GamePage gamePageModel ->
            Http.request
                { url = apiRoot ++ "/games/" ++ gamePageModel.gameIdFromUrl ++ ".json"
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , headers = [ Http.header "X-Human-UUID" humanUuid ]
                , tracker = Nothing
                , timeout = Nothing
                , method = "GET"
                , body = Http.emptyBody
                }

        HomePage _ ->
            Http.request
                { url = apiRoot ++ "/available-game-id.json"
                , expect = Http.expectJson GotAvailableGameId availableGameIdResponseDecoder
                , headers = [ Http.header "X-Human-UUID" humanUuid ]
                , tracker = Nothing
                , timeout = Nothing
                , method = "GET"
                , body = Http.emptyBody
                }

        NotFound ->
            Cmd.none

        AboutPage ->
            Cmd.none


fewerThanMinutesPassedBetween : Int -> Time.Posix -> Time.Posix -> Bool
fewerThanMinutesPassedBetween minutes a b =
    let
        actualDuration =
            abs (Time.posixToMillis a - Time.posixToMillis b)
    in
    actualDuration <= minutes * 60 * 1000


greaterThanMinutesPassedBetween : Int -> Time.Posix -> Time.Posix -> Bool
greaterThanMinutesPassedBetween minutes a b =
    not (fewerThanMinutesPassedBetween minutes a b)


pollingCmd : Page -> String -> String -> Time.Posix -> Cmd Msg
pollingCmd page apiRoot humanUuid currentTime =
    let
        cmd =
            case page of
                GamePage gamePageModel ->
                    case gamePageModel.gameResponse of
                        Just gameResponse ->
                            if fewerThanMinutesPassedBetween 5 gameResponse.gameData.lastActionAt currentTime then
                                -- Keep polling, because the game is active!
                                cmdWhenLoadingPage page
                                    apiRoot
                                    humanUuid

                            else if greaterThanMinutesPassedBetween 2 gameResponse.human.heartbeatAt currentTime then
                                -- Keep polling, because we haven't checked in a while
                                cmdWhenLoadingPage page
                                    apiRoot
                                    humanUuid

                            else
                                -- Stop polling
                                Cmd.none

                        Nothing ->
                            Cmd.none

                _ ->
                    Cmd.none
    in
    cmd


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        page =
            pageFromUrl url

        cmd =
            cmdWhenLoadingPage page flags.apiRoot flags.humanUuid
    in
    ( { currentUrl = url
      , currentPage = page
      , key = key
      , apiRoot = flags.apiRoot
      , humanUuid = flags.humanUuid
      }
    , cmd
    )


type Msg
    = UrlRequested Browser.UrlRequest
    | UpdatedGameID String
    | SubmittedGoToGame
    | UrlChanged Url.Url
    | GotGameData (Result Http.Error GameResponse)
    | GotAvailableGameId (Result Http.Error AvailableGameIdResponse)
    | Tick Time.Posix


type alias GameData =
    { identifier : String
    , lastActionAt : Time.Posix
    , spectatorCount : Int
    , status : GameStatus
    }


type GameStatus
    = Pending
    | Playing
    | Complete


type alias HumanData =
    { nickname : String, heartbeatAt : Time.Posix }


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
                    cmdWhenLoadingPage newPage model.apiRoot model.humanUuid
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
                                Ok newGameResponse ->
                                    GamePage { gamePageModel | gameResponse = Just newGameResponse }

                                Err _ ->
                                    GamePage { gamePageModel | gameResponse = Nothing }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        GotAvailableGameId result ->
            let
                newPage =
                    case model.currentPage of
                        HomePage homePageModel ->
                            case result of
                                Ok availableGameIdResponse ->
                                    if homePageModel.gameId == "" then
                                        HomePage { homePageModel | gameId = availableGameIdResponse.gameId }

                                    else
                                        model.currentPage

                                _ ->
                                    model.currentPage

                        _ ->
                            model.currentPage

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        Tick time ->
            let
                cmd =
                    pollingCmd model.currentPage model.apiRoot model.humanUuid time
            in
            ( model, cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 5000 Tick


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


viewStatus : GameStatus -> Html.Html Msg
viewStatus status =
    case status of
        Pending ->
            text "Pending"

        Playing ->
            text "Playing"

        Complete ->
            text "Complete"


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

                HomePage homePageModel ->
                    div []
                        [ p [] [ text "Bluff is a poker game for bluffers. Enter your group's game ID to proceed." ]
                        , form [ onSubmit SubmittedGoToGame ]
                            [ input [ attribute "type" "text", attribute "placeholder" "Your group's game ID", onInput UpdatedGameID, value homePageModel.gameId ] []
                            , input [ attribute "type" "submit", attribute "value" "Go", disabled (String.isEmpty homePageModel.gameId) ] []
                            ]
                        ]

                GamePage gamePageModel ->
                    div []
                        [ p []
                            [ text "You are on the game page for game ID: "
                            , strong [] [ text gamePageModel.gameIdFromUrl ]
                            , text "."
                            ]
                        , case gamePageModel.gameResponse of
                            Just gameResponse ->
                                p []
                                    [ span []
                                        [ text "Welcome, "
                                        ]
                                    , span []
                                        [ strong []
                                            [ text gameResponse.human.nickname
                                            ]
                                        ]
                                    , text ("! Spectators count is " ++ String.fromInt gameResponse.gameData.spectatorCount ++ ".")
                                    , span []
                                        [ text "Game is currently "
                                        , viewStatus gameResponse.gameData.status
                                        , text "."
                                        ]
                                    ]

                            Nothing ->
                                text "Loading gameData"
                        ]

                NotFound ->
                    div [] [ text "Page not found" ]
            , viewFooter
            ]
        ]
    }
