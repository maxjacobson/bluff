module Main exposing (main)

import Api
import Browser
import Browser.Navigation as Nav
import DateFormat.Relative
import Html
    exposing
        ( a
        , div
        , footer
        , form
        , h1
        , h2
        , h3
        , header
        , input
        , li
        , ol
        , p
        , section
        , small
        , span
        , strong
        , table
        , tbody
        , td
        , text
        , th
        , thead
        , tr
        , ul
        )
import Html.Attributes exposing (attribute, class, disabled, href, target, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Icon
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
        SubmittedGoToGame ->
            case model.currentPage of
                HomePage gameId ->
                    ( model, Nav.pushUrl model.key (pathForGameId gameId) )

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
                        HomePage _ ->
                            case result of
                                Ok availableGameIdResponse ->
                                    HomePage availableGameIdResponse

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
            ( { model | currentTime = time }, cmd )

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
                                            , newNickname = response.nickname
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
                            Api.put
                                { url = Api.profileUrl model.flags.apiRoot
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

        PlayerWantsToStartGame ->
            case model.currentPage of
                GamePage gamePageModel ->
                    ( model, playerStartsGameCmd gamePageModel model.flags )

                _ ->
                    ( model, Cmd.none )

        PlayerWantsToPlaceBet ->
            case model.currentPage of
                GamePage gamePageModel ->
                    ( model, playerPlacesBet gamePageModel model.flags )

                _ ->
                    ( model, Cmd.none )

        PlayerChangedBetAmount amount ->
            let
                newPage =
                    case model.currentPage of
                        GamePage gamePageModel ->
                            case String.toInt amount of
                                Just amountInt ->
                                    GamePage { gamePageModel | betAmount = Just amountInt }

                                Nothing ->
                                    model.currentPage

                        anything ->
                            anything

                newModel =
                    { model | currentPage = newPage }
            in
            ( newModel, Cmd.none )



---- Flags: the data index.js passes in on boot


type alias Flags =
    { apiRoot : String
    , timeAtBoot : Int
    , humanUuid : String
    }



---- Msg: the various things that might happen


type Msg
    = UrlRequested Browser.UrlRequest
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
    | PlayerWantsToStartGame
    | PlayerWantsToPlaceBet
    | PlayerChangedBetAmount String



---- Model: the current state of the application


type alias Model =
    { currentUrl : Url.Url
    , currentPage : Page
    , currentTime : Time.Posix
    , key : Nav.Key
    , flags : Flags
    }



---- Data associated with each page


type Page
    = HomePage HomePageModel
    | GamePage GamePageModel
    | AboutPage
    | ProfilePage ProfilePageModel
    | HowToPlayPage


type WebData response error
    = WaitingForResponse
    | SuccessfullyRequested response
    | FailedToRequest error


type alias HomePageModel =
    String


type alias ProfilePageModel =
    { profileResponse : WebData ProfileResponse Http.Error
    , editingNickname : Bool
    , newNickname : String
    , currentlySavingNickname : Bool
    }


type alias GamePageModel =
    { gameResponse : WebData GameResponse Http.Error
    , gameIdFromUrl : String
    , betAmount : Maybe Int
    }



---- Decoded API responses


type alias GameResponse =
    { gameData : GameData
    , human : HumanGameData
    }


type alias AvailableGameIdResponse =
    String


type alias ProfileResponse =
    { nickname : String
    , games : List GameData
    }


type alias GameData =
    { identifier : String
    , lastActionAt : Time.Posix
    , status : GameStatus
    , players : List Player
    , actions : List Action
    , nextAction : Maybe NextAction
    , potSize : Int
    }


type alias BetAction =
    { available : Bool
    , minimum : Int
    , maximum : Int
    }


type alias RaiseAction =
    { available : Bool }


type alias CallAction =
    { available : Bool }


type alias CheckAction =
    { available : Bool }


type alias FoldAction =
    { available : Bool }


type alias NextAction =
    { player : HumanGameData
    , bet : BetAction
    , raise : RaiseAction
    , call : CallAction
    , check : CheckAction
    , fold : FoldAction
    }


type alias Action =
    { time : Time.Posix
    , summary : String
    }


type CardSuit
    = Diamonds
    | Clubs
    | Hearts
    | Spades


type CardRank
    = Two
    | Three
    | Four
    | Five
    | Six
    | Seven
    | Eight
    | Nine
    | Ten
    | Jack
    | Queen
    | King
    | Ace


type alias Card =
    { suit : CardSuit
    , rank : CardRank
    }


type alias Player =
    { id : Int
    , nickname : String
    , chipsCount : Int
    , currentCard : Maybe Card
    , inCurrentHand : Bool
    }


type GameStatus
    = Pending
    | Playing
    | Complete


type alias HumanGameData =
    { id : Int
    , nickname : String
    , heartbeatAt : Time.Posix
    , role : Role
    }


type Role
    = ViewerRole
    | PlayerRole



---- decoders
---- These let us convert data from the API into elm types


posixDecoder : Int -> Decoder Time.Posix
posixDecoder millis =
    D.succeed (Time.millisToPosix millis)


cardSuitDecoder : String -> Decoder CardSuit
cardSuitDecoder suit =
    case suit of
        "spades" ->
            D.succeed Spades

        "clubs" ->
            D.succeed Clubs

        "diamonds" ->
            D.succeed Diamonds

        "hearts" ->
            D.succeed Hearts

        _ ->
            D.fail ("Unknown suit: " ++ suit)


cardRankDecoder : String -> Decoder CardRank
cardRankDecoder rank =
    case rank of
        "two" ->
            D.succeed Two

        "three" ->
            D.succeed Three

        "four" ->
            D.succeed Four

        "five" ->
            D.succeed Five

        "six" ->
            D.succeed Six

        "seven" ->
            D.succeed Seven

        "eight" ->
            D.succeed Eight

        "nine" ->
            D.succeed Nine

        "ten" ->
            D.succeed Ten

        "jack" ->
            D.succeed Jack

        "queen" ->
            D.succeed Queen

        "king" ->
            D.succeed King

        "ace" ->
            D.succeed Ace

        _ ->
            D.fail ("Unknown rank: " ++ rank)


cardDecoder : Decoder Card
cardDecoder =
    D.map2 Card
        (D.field "suit" D.string |> D.andThen cardSuitDecoder)
        (D.field "rank" D.string |> D.andThen cardRankDecoder)


currentCardDecoder : Decoder (Maybe Card)
currentCardDecoder =
    D.nullable cardDecoder


playerDecoder : Decoder Player
playerDecoder =
    D.map5 Player
        (D.field "id" D.int)
        (D.field "nickname" D.string)
        (D.field "chips_count" D.int)
        (D.field "current_card" currentCardDecoder)
        (D.field "in_current_hand" D.bool)


actionDecoder : Decoder Action
actionDecoder =
    D.map2 Action
        (D.field "created_at" D.int |> D.andThen posixDecoder)
        (D.field "summary" D.string)


betActionDecoder : Decoder BetAction
betActionDecoder =
    D.map3 BetAction
        (D.field "available" D.bool)
        (D.field "minimum" D.int)
        (D.field "maximum" D.int)


raiseActionDecoder : Decoder RaiseAction
raiseActionDecoder =
    D.map RaiseAction
        (D.field "available" D.bool)


callActionDecoder : Decoder CallAction
callActionDecoder =
    D.map CallAction
        (D.field "available" D.bool)


checkActionDecoder : Decoder CheckAction
checkActionDecoder =
    D.map CheckAction
        (D.field "available" D.bool)


foldActionDecoder : Decoder FoldAction
foldActionDecoder =
    D.map FoldAction
        (D.field "available" D.bool)


nextActionDecoder : Decoder NextAction
nextActionDecoder =
    D.map6 NextAction
        (D.field "player" humanGameDataDecoder)
        (D.field "bet" betActionDecoder)
        (D.field "raise" raiseActionDecoder)
        (D.field "call" callActionDecoder)
        (D.field "check" checkActionDecoder)
        (D.field "fold" foldActionDecoder)


gameDataDecoder : Decoder GameData
gameDataDecoder =
    D.map7 GameData
        (D.field "id" D.string)
        (D.field "last_action_at" D.int |> D.andThen posixDecoder)
        (D.field "status" D.string |> D.andThen gameStatusDecoder)
        (D.field "players" (D.list playerDecoder))
        (D.field "actions" (D.list actionDecoder))
        (D.field "next_action" (D.nullable nextActionDecoder))
        (D.field "pot_size" D.int)


roleDecoder : String -> Decoder Role
roleDecoder role =
    if role == "viewer" then
        D.succeed ViewerRole

    else if role == "player" then
        D.succeed PlayerRole

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
    D.map4 HumanGameData
        (D.field "id" D.int)
        (D.field "nickname" D.string)
        (D.field "heartbeat_at" D.int |> D.andThen posixDecoder)
        (D.field "role" D.string |> D.andThen roleDecoder)


humanDataDecoder : Decoder String
humanDataDecoder =
    D.field "nickname" D.string


availableGameIdResponseDecoder : Decoder AvailableGameIdResponse
availableGameIdResponseDecoder =
    D.at [ "data", "id" ] D.string


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
            HomePage ""

        "/about" ->
            AboutPage

        "/how-to-play" ->
            HowToPlayPage

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
                    GamePage
                        { gameResponse = WaitingForResponse
                        , gameIdFromUrl = gameId
                        , betAmount = Nothing
                        }

                _ ->
                    HomePage ""


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
            Api.get
                { url = Api.gameUrl flags.apiRoot gamePageModel.gameIdFromUrl
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                }

        HomePage _ ->
            Api.get
                { url = Api.availableGameIdUrl flags.apiRoot
                , expect = Http.expectJson GotAvailableGameId availableGameIdResponseDecoder
                , uuid = flags.humanUuid
                }

        AboutPage ->
            Cmd.none

        HowToPlayPage ->
            Cmd.none

        ProfilePage _ ->
            Api.get
                { url = Api.profileUrl flags.apiRoot
                , expect = Http.expectJson GotProfile profileResponseDecoder
                , uuid = flags.humanUuid
                }


humanJoinsGameCmd : GamePageModel -> Flags -> Cmd Msg
humanJoinsGameCmd model flags =
    case model.gameResponse of
        SuccessfullyRequested response ->
            Api.post
                { url = Api.joinGameUrl flags.apiRoot response.gameData.identifier
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                , body = Http.emptyBody
                }

        _ ->
            Cmd.none


playerStartsGameCmd : GamePageModel -> Flags -> Cmd Msg
playerStartsGameCmd model flags =
    case model.gameResponse of
        SuccessfullyRequested response ->
            Api.post
                { url = Api.startGameUrl flags.apiRoot response.gameData.identifier
                , expect = Http.expectJson GotGameData gameResponseDecoder
                , uuid = flags.humanUuid
                , body = Http.emptyBody
                }

        _ ->
            Cmd.none


playerPlacesBet : GamePageModel -> Flags -> Cmd Msg
playerPlacesBet model flags =
    case model.betAmount of
        Just amount ->
            case model.gameResponse of
                SuccessfullyRequested response ->
                    Api.post
                        { url = Api.placeBetUrl flags.apiRoot response.gameData.identifier
                        , expect = Http.expectJson GotGameData gameResponseDecoder
                        , uuid = flags.humanUuid
                        , body =
                            Http.jsonBody
                                (E.object
                                    [ ( "bets"
                                      , E.object
                                            [ ( "amount", E.int amount )
                                            ]
                                      )
                                    ]
                                )
                        }

                _ ->
                    Cmd.none

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
      , currentTime = Time.millisToPosix flags.timeAtBoot
      }
    , cmd
    )



---- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 2000 Tick



---- VIEW HELPERS


titleForPage : Page -> String
titleForPage page =
    case page of
        HomePage _ ->
            "Bluff"

        HowToPlayPage ->
            "How to play - Bluff"

        GamePage _ ->
            "Bluff"

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
            [ Icon.closedEye
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
            [ li [] [ a [ href "/how-to-play" ] [ text "How to play" ] ]
            , li [] [ a [ href "/profile" ] [ text "Profile" ] ]
            , li [] [ a [ href "/about" ] [ text "About bluff" ] ]
            ]
        ]


pageContentClassFor : Page -> String
pageContentClassFor page =
    case page of
        AboutPage ->
            "about-page"

        GamePage _ ->
            "game-page"

        HomePage _ ->
            "home-page"

        HowToPlayPage ->
            "how-to-play-page"

        ProfilePage _ ->
            "profile-page"


viewSuit : CardSuit -> Html.Html msg
viewSuit suit =
    case suit of
        Diamonds ->
            span [ class "suit-diamonds" ] [ text "♦" ]

        Hearts ->
            span [ class "suit-hearts" ] [ text "♥" ]

        Clubs ->
            span [ class "suit-clubs" ] [ text "♣" ]

        Spades ->
            span [ class "suit-spades" ] [ text "♠" ]


viewRank : CardRank -> Html.Html msg
viewRank rank =
    case rank of
        Two ->
            text "2"

        Three ->
            text "3"

        Four ->
            text "4"

        Five ->
            text "5"

        Six ->
            text "6"

        Seven ->
            text "7"

        Eight ->
            text "8"

        Nine ->
            text "9"

        Ten ->
            text "10"

        Jack ->
            text "J"

        Queen ->
            text "Q"

        King ->
            text "K"

        Ace ->
            text "A"


viewCard : Card -> Html.Html msg
viewCard card =
    span [ class "compact-card" ]
        [ viewRank card.rank
        , viewSuit card.suit
        ]


pluralizeChips : Int -> String
pluralizeChips num =
    if num == 1 then
        "1 chip"

    else
        String.fromInt num ++ " chips"



---- Main view function


view : Model -> Browser.Document Msg
view model =
    { title = titleForPage model.currentPage
    , body =
        [ div [ class "main-container" ]
            [ viewHeader model.currentPage
            , div [ class "page-content", class (pageContentClassFor model.currentPage) ]
                (case model.currentPage of
                    HowToPlayPage ->
                        [ p [] [ text "Bluff is a fun, simple version of poker. Here's what you do." ]
                        , ol []
                            [ li [] [ text "Gather some friends on a zoom call" ]
                            , li []
                                [ text "Start a new game from "
                                , a [ href "/" ] [ text "the home page" ]
                                ]
                            , li [] [ text "Share the game link with your friends" ]
                            , li [] [ text "Everyone who wants to play can then join the game (or you can just watch)" ]
                            , li [] [ text "You get 100 chips when you join the game (there's no money involved here, this is just for fun)" ]
                            , li [] [ text "Each hand, you'll get just one card, and there's just one round of betting" ]
                            , li [] [ text "High card wins" ]
                            , li [] [ text "You can see everyone's card but your own" ]
                            ]
                        ]

                    AboutPage ->
                        [ section []
                            [ h2 [] [ text "How to play" ]
                            , p []
                                [ text "See "
                                , a [ href "/how-to-play" ] [ text "how to play" ]
                                , text " page."
                                ]
                            ]
                        , section []
                            [ h2 [] [ text "Source code" ]
                            , p []
                                [ text "It's "
                                , a [ href "https://github.com/maxjacobson/bluff", target "_blank" ] [ text "over here" ]
                                , text " if you want to knock yourself out."
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
                                    [ a [ href "https://www.toicon.com/icons/avocado_save", target "_blank" ] [ Icon.piggyBank "A very nice piggy bank icon" ]
                                    ]
                                , li []
                                    [ a [ href "https://www.toicon.com/icons/hatch_hide", target "_blank" ] [ Icon.closedEye ]
                                    ]
                                , li []
                                    [ a [ href "https://www.toicon.com/icons/afiado_go", target "_blank" ] [ Icon.arrowRight "A very nice looking arrow icon" ] ]
                                ]
                            , p []
                                [ text "This is my first time using "
                                , strong [] [ text "to [icon]" ]
                                , text ". It didn't have what I was looking for (an icon of some poker chips) but I liked what it had, better."
                                ]
                            ]
                        ]

                    ProfilePage profilePageModel ->
                        case profilePageModel.profileResponse of
                            WaitingForResponse ->
                                [ p [] [ text "Loading..." ] ]

                            SuccessfullyRequested response ->
                                [ if profilePageModel.editingNickname then
                                    p []
                                        [ form [ onSubmit SaveNewNickname ]
                                            [ strong [] [ text "Nickname: " ]
                                            , input
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
                                        ]

                                  else
                                    p []
                                        [ strong [] [ text "Nickname: " ]
                                        , text response.nickname
                                        , text " "
                                        , input
                                            [ attribute "type" "submit"
                                            , onClick MakeNicknameEditable
                                            , attribute "value" "Edit"
                                            ]
                                            []
                                        ]
                                , case List.length response.games of
                                    0 ->
                                        -- No need to tell people about games until they've joined a game
                                        text ""

                                    _ ->
                                        div []
                                            [ h3 [] [ text "History" ]
                                            , table []
                                                [ thead []
                                                    [ tr []
                                                        [ th [] [ text "Game" ]
                                                        , th [] [ text "Last active" ]
                                                        ]
                                                    ]
                                                , tbody []
                                                    (List.map
                                                        (\game ->
                                                            tr []
                                                                [ td [] [ a [ href (pathForGameId game.identifier) ] [ text game.identifier ] ]
                                                                , td [] [ text (DateFormat.Relative.relativeTime model.currentTime game.lastActionAt) ]
                                                                ]
                                                        )
                                                        response.games
                                                    )
                                                ]
                                            ]
                                ]

                            FailedToRequest _ ->
                                [ p [] [ text "Whoops, couldn't load your profile. Look, all I can say is I'm sorry." ] ]

                    HomePage gameId ->
                        [ form [ onSubmit SubmittedGoToGame ]
                            [ let
                                isDisabled =
                                    String.isEmpty gameId

                                copy =
                                    if isDisabled then
                                        "You're not ready"

                                    else
                                        "New game"
                              in
                              input
                                [ attribute "type" "submit"
                                , attribute "value" copy
                                , disabled isDisabled
                                ]
                                []
                            ]
                        ]

                    GamePage gamePageModel ->
                        [ div [ class "players-table" ]
                            [ case gamePageModel.gameResponse of
                                FailedToRequest _ ->
                                    text "Whooooops"

                                SuccessfullyRequested response ->
                                    div []
                                        [ p []
                                            [ Icon.piggyBank "These chips are at stake in this hand"
                                            , text (" " ++ pluralizeChips response.gameData.potSize)
                                            , text " on the table."
                                            ]
                                        , table []
                                            [ thead []
                                                [ tr []
                                                    [ th [] [ text "Player" ]
                                                    , th [] [ text "" ]
                                                    , th [] [ text "Chips" ]
                                                    ]
                                                ]
                                            , tbody []
                                                (List.map
                                                    (\player ->
                                                        tr
                                                            [ class
                                                                (if player.inCurrentHand then
                                                                    "player in-hand"

                                                                 else
                                                                    "player not-in-hand"
                                                                )
                                                            ]
                                                            [ td []
                                                                [ case response.gameData.nextAction of
                                                                    Just nextAction ->
                                                                        if nextAction.player.id == player.id then
                                                                            Icon.arrowRight "The action is to this player."

                                                                        else
                                                                            text ""

                                                                    _ ->
                                                                        text ""
                                                                , text player.nickname
                                                                ]
                                                            , td []
                                                                [ span []
                                                                    (if response.human.id == player.id then
                                                                        [ small [] [ text "(you)" ] ]

                                                                     else
                                                                        [ text "" ]
                                                                    )
                                                                , span []
                                                                    (case player.currentCard of
                                                                        Just card ->
                                                                            [ viewCard card
                                                                            ]

                                                                        _ ->
                                                                            [ text "" ]
                                                                    )
                                                                ]
                                                            , td [] [ text (String.fromInt player.chipsCount) ]
                                                            ]
                                                    )
                                                    response.gameData.players
                                                )
                                            ]
                                        ]

                                WaitingForResponse ->
                                    text "Loading..."
                            ]
                        , div [ class "game-actions" ]
                            [ div [ class "actions-list" ]
                                (case gamePageModel.gameResponse of
                                    FailedToRequest _ ->
                                        [ text "Yikes! I blew it." ]

                                    WaitingForResponse ->
                                        [ text "Loading..." ]

                                    SuccessfullyRequested gameResponse ->
                                        if List.isEmpty gameResponse.gameData.actions then
                                            [ text "This space intentionally left blank" ]

                                        else
                                            List.map
                                                (\action ->
                                                    div [ class "actions-list-item" ]
                                                        [ div [] [ text (DateFormat.Relative.relativeTime model.currentTime action.time) ]
                                                        , div [] [ text action.summary ]
                                                        ]
                                                )
                                                gameResponse.gameData.actions
                                )
                            , div [ class "action-buttons" ]
                                (case gamePageModel.gameResponse of
                                    FailedToRequest _ ->
                                        [ text "Yuh oh..." ]

                                    WaitingForResponse ->
                                        [ text "Loading.." ]

                                    SuccessfullyRequested gameResponse ->
                                        [ case gameResponse.gameData.status of
                                            Pending ->
                                                p []
                                                    [ span []
                                                        [ case gameResponse.human.role of
                                                            PlayerRole ->
                                                                form [ onSubmit PlayerWantsToStartGame ]
                                                                    [ input
                                                                        [ attribute "type" "submit"
                                                                        , attribute "value"
                                                                            (if List.length gameResponse.gameData.players >= 2 then
                                                                                "Start game"

                                                                             else
                                                                                "Waiting for two players to join..."
                                                                            )
                                                                        , disabled (List.length gameResponse.gameData.players < 2)
                                                                        ]
                                                                        []
                                                                    ]

                                                            ViewerRole ->
                                                                text ""
                                                        ]
                                                    ]

                                            Playing ->
                                                case gameResponse.gameData.nextAction of
                                                    Just nextAction ->
                                                        div []
                                                            (if nextAction.player.id /= gameResponse.human.id then
                                                                [ p [] [ text ("Waiting for " ++ nextAction.player.nickname ++ " to act") ] ]

                                                             else
                                                                [ h1 [] [ text "Your turn to act" ]
                                                                , div []
                                                                    [ if nextAction.bet.available then
                                                                        let
                                                                            currentValue =
                                                                                case gamePageModel.betAmount of
                                                                                    Just value ->
                                                                                        value

                                                                                    Nothing ->
                                                                                        0

                                                                            isDisabled =
                                                                                currentValue < nextAction.bet.minimum || currentValue > nextAction.bet.maximum
                                                                        in
                                                                        form [ disabled isDisabled, onSubmit PlayerWantsToPlaceBet ]
                                                                            [ input
                                                                                [ attribute "type" "number"
                                                                                , attribute "min" (String.fromInt nextAction.bet.minimum)
                                                                                , attribute "max" (String.fromInt nextAction.bet.maximum)
                                                                                , attribute "value" (String.fromInt currentValue)
                                                                                , onInput PlayerChangedBetAmount
                                                                                ]
                                                                                []
                                                                            , input
                                                                                [ attribute "type" "submit"
                                                                                , attribute "value" "Bet"
                                                                                , disabled isDisabled
                                                                                ]
                                                                                []
                                                                            ]

                                                                      else
                                                                        p [] [ text "You can't bet" ]
                                                                    , div []
                                                                        [ if nextAction.raise.available then
                                                                            p [] [ text "You can raise" ]

                                                                          else
                                                                            p [] [ text "You can't raise" ]
                                                                        ]
                                                                    , div []
                                                                        [ if nextAction.call.available then
                                                                            p [] [ text "You can call" ]

                                                                          else
                                                                            p [] [ text "You can't call" ]
                                                                        ]
                                                                    , div []
                                                                        [ if nextAction.check.available then
                                                                            p [] [ text "You can check" ]

                                                                          else
                                                                            p [] [ text "You can't check" ]
                                                                        ]
                                                                    , div []
                                                                        [ if nextAction.fold.available then
                                                                            p [] [ text "You can fold" ]

                                                                          else
                                                                            p [] [ text "You can't fold" ]
                                                                        ]
                                                                    ]
                                                                ]
                                                            )

                                                    Nothing ->
                                                        text ""

                                            Complete ->
                                                p [] [ text "Hope you had fun" ]
                                        , case gameResponse.human.role of
                                            ViewerRole ->
                                                input [ attribute "type" "submit", attribute "value" "Join!", onClick HumanWantsIn ]
                                                    []

                                            PlayerRole ->
                                                text ""
                                        ]
                                )
                            ]
                        ]
                )
            , viewFooter
            ]
        ]
    }
