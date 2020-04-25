module Main exposing (main)

import Api exposing (..)
import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (attribute, class, disabled, href, src, target, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as D exposing (Decoder, field, string)
import Json.Encode as E
import Time
import Url
import Url.Builder



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
                    ( model, Nav.pushUrl model.key (pathForGameId homePageModel.gameId) )

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
                                    GamePage { gamePageModel | gameResponse = SuccessfullyRequested newGameResponse }

                                Err e ->
                                    GamePage { gamePageModel | gameResponse = FailedToRequest e }

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

        GotProfile result ->
            let
                newPage =
                    case model.currentPage of
                        ProfilePage profilePageModel ->
                            case result of
                                Ok response ->
                                    ProfilePage
                                        { profilePageModel
                                            | profileResponse = SuccessfullyRequested response
                                            , newNickname = response.human.nickname
                                            , currentlySavingNickname = False
                                            , editingNickname = False
                                        }

                                Err e ->
                                    ProfilePage { profilePageModel | profileResponse = FailedToRequest e }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        MakeNicknameEditable ->
            let
                newPage =
                    case model.currentPage of
                        ProfilePage profilePageModel ->
                            ProfilePage { profilePageModel | editingNickname = True }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        UpdatedNewNickname newNickname ->
            let
                newPage =
                    case model.currentPage of
                        ProfilePage profilePageModel ->
                            ProfilePage { profilePageModel | newNickname = newNickname }

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )

        SaveNewNickname ->
            case model.currentPage of
                ProfilePage profilePageModel ->
                    let
                        newPage =
                            ProfilePage { profilePageModel | currentlySavingNickname = True }

                        newModel =
                            { model | currentPage = newPage }

                        newCmd =
                            put
                                { url = profileUrl model.flags.apiRoot
                                , expect = Http.expectJson GotProfile profileResponseDecoder
                                , uuid = model.flags.humanUuid
                                , body =
                                    Http.jsonBody
                                        (E.object
                                            [ ( "profile"
                                              , E.object
                                                    [ ( "nickname", E.string profilePageModel.newNickname )
                                                    ]
                                              )
                                            ]
                                        )
                                }
                    in
                    ( newModel, newCmd )

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
    | GotProfile (Result Http.Error ProfileResponse)
    | Tick Time.Posix
    | HumanWantsIn
    | MakeNicknameEditable
    | UpdatedNewNickname String
    | SaveNewNickname



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
    | ProfilePage ProfilePageModel
    | NotFound


type WebData response error
    = WaitingForResponse
    | SuccessfullyRequested response
    | FailedToRequest error


type alias HomePageModel =
    { gameId : String
    }


type alias ProfilePageModel =
    { profileResponse : WebData ProfileResponse Http.Error
    , editingNickname : Bool
    , newNickname : String
    , currentlySavingNickname : Bool
    }


type alias GamePageModel =
    { gameResponse : WebData GameResponse Http.Error
    , gameIdFromUrl : String
    }



---- Decoded API responses


type alias GameResponse =
    { gameData : GameData
    , human : HumanGameData
    }


type alias AvailableGameIdResponse =
    { gameId : String
    }


type alias ProfileResponse =
    { human : HumanData
    , games : List GameData
    }


type alias GameData =
    { identifier : String
    , lastActionAt : Time.Posix
    , spectatorCount : Int
    , totalChipsCount : Int
    , status : GameStatus
    }


type GameStatus
    = Pending
    | Playing
    | Complete


type alias HumanGameData =
    { nickname : String
    , heartbeatAt : Time.Posix
    , role : Role
    }


type alias HumanData =
    { nickname : String }


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
    D.map5 GameData
        (D.field "id" D.string)
        (D.field "last_action_at" D.int |> D.andThen posixDecoder)
        (D.field "spectators_count" D.int)
        (D.field "total_chips_count" D.int)
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


humanGameDataDecoder : Decoder HumanGameData
humanGameDataDecoder =
    D.map3 HumanGameData
        (D.field "nickname" D.string)
        (D.field "heartbeat_at" D.int |> D.andThen posixDecoder)
        (D.field "role" D.string |> D.andThen roleDecoder)


humanDataDecoder : Decoder HumanData
humanDataDecoder =
    D.map HumanData
        (D.field "nickname" D.string)


availableGameIdResponseDecoder : Decoder AvailableGameIdResponse
availableGameIdResponseDecoder =
    D.map AvailableGameIdResponse
        (D.at [ "data", "id" ] D.string)


gameResponseDecoder : Decoder GameResponse
gameResponseDecoder =
    D.map2 GameResponse
        (D.field "data" gameDataDecoder)
        (D.at [ "meta", "human" ] humanGameDataDecoder)


gamesResponseDecoder : Decoder (List GameData)
gamesResponseDecoder =
    D.list gameDataDecoder


profileResponseDecoder : Decoder ProfileResponse
profileResponseDecoder =
    D.map2 ProfileResponse
        (D.field "data" humanDataDecoder)
        (D.at [ "data", "games" ] gamesResponseDecoder)


pageFromUrl : Url.Url -> Page
pageFromUrl url =
    case url.path of
        "/" ->
            HomePage (HomePageModel "")

        "/about" ->
            AboutPage

        "/profile" ->
            ProfilePage
                { profileResponse = WaitingForResponse
                , newNickname = ""
                , editingNickname = False
                , currentlySavingNickname = False
                }

        _ ->
            case gameIdFromUrl url of
                Just gameId ->
                    GamePage (GamePageModel WaitingForResponse gameId)

                _ ->
                    NotFound


gameIdFromUrl : Url.Url -> Maybe String
gameIdFromUrl url =
    case String.dropLeft 1 url.path of
        "" ->
            Nothing

        anything ->
            Just anything


pathForGameId : String -> String
pathForGameId identifier =
    Url.Builder.absolute [ identifier ] []


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

        ProfilePage _ ->
            get
                { url = profileUrl flags.apiRoot
                , expect = Http.expectJson GotProfile profileResponseDecoder
                , uuid = flags.humanUuid
                }


humanJoinsGameCmd : GamePageModel -> Flags -> Cmd Msg
humanJoinsGameCmd model flags =
    case model.gameResponse of
        SuccessfullyRequested response ->
            post
                { url = joinGameUrl flags.apiRoot response.gameData.identifier
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                , body = Http.emptyBody
                }

        _ ->
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
                        SuccessfullyRequested gameResponse ->
                            if fewerThanMinutesPassedBetween 5 gameResponse.gameData.lastActionAt currentTime then
                                -- Keep polling, because the game is active!
                                cmdWhenLoadingPage page flags

                            else if greaterThanMinutesPassedBetween 2 gameResponse.human.heartbeatAt currentTime then
                                -- Keep polling, because we haven't checked in a while
                                cmdWhenLoadingPage page flags

                            else
                                -- Stop polling
                                Cmd.none

                        _ ->
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

        ProfilePage _ ->
            "Profile - Bluff"


viewHeader : Page -> Html.Html Msg
viewHeader page =
    let
        hyperlink : Bool
        hyperlink =
            case page of
                HomePage _ ->
                    False

                _ ->
                    True

        headerChildren =
            [ img [ src "/icons/closed-eye.svg" ] []
            , h1 []
                [ text "Bluff"
                ]
            ]
    in
    if hyperlink then
        a [ href "/" ]
            [ header [] headerChildren
            ]

    else
        header [] headerChildren


viewFooter : Html.Html Msg
viewFooter =
    footer []
        [ ul []
            [ li [] [ a [ href "/profile" ] [ text "Profile" ] ]
            , li [] [ a [ href "/about" ] [ text "About" ] ]
            ]
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
                        [ section []
                            [ h2 [] [ text "Rules" ]
                            , p []
                                [ text "I'm going to add these later, when the game is actually implemented."
                                ]
                            ]
                        , section []
                            [ h2 [] [ text "Source code" ]
                            , p []
                                [ a [ href "https://github.com/maxjacobson/bluff", target "_blank" ] [ text "It's over here if you want to knock yourself out." ]
                                ]
                            ]
                        , section []
                            [ h2 [] [ text "Credits" ]
                            , p []
                                [ text "These icons are from "
                                , a [ href "https://www.toicon.com/about" ] [ strong [] [ text "to [icon]" ] ]
                                , text ":"
                                ]
                            , ul [ class "icons-credits" ]
                                [ li []
                                    [ a [ href "https://www.toicon.com/icons/avocado_save" ] [ img [ src "/icons/piggy-bank.svg" ] [] ]
                                    ]
                                , li []
                                    [ a [ href "https://www.toicon.com/icons/hatch_hide" ] [ img [ src "/icons/closed-eye.svg" ] [] ]
                                    ]
                                ]
                            , p []
                                [ text "This is my first time using "
                                , strong [] [ text "to [icon]" ]
                                , text ". It didn't have what I was looking for (an icon of some poker chips) but I liked what it had, better."
                                ]
                            ]
                        ]

                ProfilePage profilePageModel ->
                    div []
                        [ h2 []
                            [ text "Profile"
                            ]
                        , case profilePageModel.profileResponse of
                            WaitingForResponse ->
                                p [] [ text "Loading.." ]

                            SuccessfullyRequested response ->
                                div []
                                    [ p []
                                        [ text "Bluff profiles are ephemeral." ]
                                    , h3 [] [ text "Your nickname" ]
                                    , p []
                                        [ if profilePageModel.editingNickname then
                                            form [ onSubmit SaveNewNickname ]
                                                [ input
                                                    [ attribute "type" "text"
                                                    , attribute "placeholder" "Your nickname"
                                                    , onInput UpdatedNewNickname
                                                    , value profilePageModel.newNickname
                                                    , disabled profilePageModel.currentlySavingNickname
                                                    ]
                                                    []
                                                , input
                                                    [ attribute "type" "submit"
                                                    , attribute "value" "Save"
                                                    , disabled (String.isEmpty profilePageModel.newNickname || profilePageModel.currentlySavingNickname)
                                                    ]
                                                    []
                                                ]

                                          else
                                            span []
                                                [ strong [] [ text response.human.nickname ]
                                                , text " "
                                                , button [ onClick MakeNicknameEditable ] [ text "Edit" ]
                                                , text "."
                                                ]
                                        ]
                                    , case List.length response.games of
                                        0 ->
                                            text ""

                                        _ ->
                                            div []
                                                [ h3 [] [ text "Your games" ]
                                                , ol []
                                                    (List.map
                                                        (\game ->
                                                            li [] [ a [ href (pathForGameId game.identifier) ] [ text game.identifier ] ]
                                                        )
                                                        response.games
                                                    )
                                                ]
                                    ]

                            FailedToRequest _ ->
                                p [] [ text "Whoops, couldn't load your profile. Look, all I can say is I'm sorry." ]
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
                            SuccessfullyRequested gameResponse ->
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
                                                        div []
                                                            [ p [] [ text "You're in!" ]
                                                            , p []
                                                                [ img [ src "/icons/piggy-bank.svg" ] []
                                                                , text ("Chips on table: " ++ String.fromInt gameResponse.gameData.totalChipsCount ++ " chips")
                                                                ]
                                                            ]
                                                ]

                                        Playing ->
                                            p [] [ text "Game details to come here" ]

                                        Complete ->
                                            p [] [ text "Hope you had fund" ]
                                    ]

                            WaitingForResponse ->
                                text "Loading..."

                            FailedToRequest e ->
                                text "Whoops, failed to load game. Yikes. This looks bad."
                        ]

                NotFound ->
                    div [] [ text "Page not found" ]
            , viewFooter
            ]
        ]
    }
