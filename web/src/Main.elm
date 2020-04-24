module Main exposing (main)

import Api exposing (availableGameIdUrl, gameUrl, get, joinGameUrl, post)
import Browser
import Browser.Navigation as Nav
import Html exposing (a, button, div, footer, form, h1, input, p, span, strong, text)
import Html.Attributes exposing (attribute, disabled, href, target, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as D exposing (Decoder, field, string)
import Time
import Url



---- main: entrypoint function


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



---- update: how things change over time


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
                    cmdWhenLoadingPage newPage model.flags
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
                    pollingCmd model.currentPage model.flags time
            in
            ( model, cmd )

        HumanWantsIn ->
            case model.currentPage of
                GamePage gamePageModel ->
                    ( model, humanJoinsGameCmd gamePageModel model.flags )

                _ ->
                    ( model, Cmd.none )



---- Flags: the data index.js passes in on boot


type alias Flags =
    { apiRoot : String
    , humanUuid : String
    }



---- Msg: the various things that might happen


type Msg
    = UrlRequested Browser.UrlRequest
    | UpdatedGameID String
    | SubmittedGoToGame
    | UrlChanged Url.Url
    | GotGameData (Result Http.Error GameResponse)
    | GotAvailableGameId (Result Http.Error AvailableGameIdResponse)
    | Tick Time.Posix
    | HumanWantsIn



---- Model: the current state of the application


type alias Model =
    { currentUrl : Url.Url
    , currentPage : Page
    , key : Nav.Key
    , flags : Flags
    }



---- Data associated with each page


type Page
    = HomePage HomePageModel
    | GamePage GamePageModel
    | AboutPage
    | NotFound


type alias HomePageModel =
    { gameId : String
    }


type alias GamePageModel =
    { gameResponse : Maybe GameResponse
    , gameIdFromUrl : String
    }



---- Decoded API responses


type alias GameResponse =
    { gameData : GameData
    , human : HumanData
    }


type alias AvailableGameIdResponse =
    { gameId : String
    }


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
    { nickname : String, heartbeatAt : Time.Posix, role : Role }


type Role
    = Viewer
    | Player



---- decoders
---- These let us convert data from the API into elm types


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


roleDecoder : String -> Decoder Role
roleDecoder role =
    if role == "viewer" then
        D.succeed Viewer

    else if role == "player" then
        D.succeed Player

    else
        D.fail ("Unknown role: " ++ role)


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
    D.map3 HumanData
        (D.field "nickname" D.string)
        (D.field "heartbeat_at" D.int |> D.andThen posixDecoder)
        (D.field "role" D.string |> D.andThen roleDecoder)


availableGameIdResponseDecoder : Decoder AvailableGameIdResponse
availableGameIdResponseDecoder =
    D.map AvailableGameIdResponse
        (D.at [ "data", "id" ] D.string)


gameResponseDecoder : Decoder GameResponse
gameResponseDecoder =
    D.map2 GameResponse
        (D.field "data" gameDataDecoder)
        (D.at [ "meta", "human" ] humanDataDecoder)



---- application helpers


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


cmdWhenLoadingPage : Page -> Flags -> Cmd Msg
cmdWhenLoadingPage page flags =
    case page of
        GamePage gamePageModel ->
            get
                { url = gameUrl flags.apiRoot gamePageModel.gameIdFromUrl
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                }

        HomePage _ ->
            get
                { url = availableGameIdUrl flags.apiRoot
                , expect = Http.expectJson GotAvailableGameId availableGameIdResponseDecoder
                , uuid = flags.humanUuid
                }

        NotFound ->
            Cmd.none

        AboutPage ->
            Cmd.none


humanJoinsGameCmd : GamePageModel -> Flags -> Cmd Msg
humanJoinsGameCmd model flags =
    case model.gameResponse of
        Just response ->
            post
                { url = joinGameUrl flags.apiRoot response.gameData.identifier
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                , body = Http.emptyBody
                }

        Nothing ->
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


pollingCmd : Page -> Flags -> Time.Posix -> Cmd Msg
pollingCmd page flags currentTime =
    let
        cmd =
            case page of
                GamePage gamePageModel ->
                    case gamePageModel.gameResponse of
                        Just gameResponse ->
                            if fewerThanMinutesPassedBetween 5 gameResponse.gameData.lastActionAt currentTime then
                                -- Keep polling, because the game is active!
                                cmdWhenLoadingPage page flags

                            else if greaterThanMinutesPassedBetween 2 gameResponse.human.heartbeatAt currentTime then
                                -- Keep polling, because we haven't checked in a while
                                cmdWhenLoadingPage page flags

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
            cmdWhenLoadingPage page flags
    in
    ( { currentUrl = url
      , currentPage = page
      , key = key
      , flags = flags
      }
    , cmd
    )



---- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 5000 Tick



---- VIEW HELPERS


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



---- Main view function


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
                                div []
                                    [ p []
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
                                    , case gameResponse.gameData.status of
                                        Pending ->
                                            p []
                                                [ span [] [ text "The game hasn't started yet." ]
                                                , case gameResponse.human.role of
                                                    Viewer ->
                                                        button [ onClick HumanWantsIn ]
                                                            [ text "Join?"
                                                            ]

                                                    Player ->
                                                        text "You're in :)"
                                                ]

                                        Playing ->
                                            p [] [ text "Game details to come here" ]

                                        Complete ->
                                            p [] [ text "Hope you had fund" ]
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
