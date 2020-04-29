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
                HomePage homePageModel ->
                    case homePageModel of
                        SuccessfullyRequested gameId ->
                            ( model, Nav.pushUrl model.key (pathForGameId gameId) )

                        _ ->
                            ( model, Cmd.none )

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
                                    HomePage (SuccessfullyRequested availableGameIdResponse)

                                Err e ->
                                    HomePage (FailedToRequest e)

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
    WebData String Http.Error


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
    , currentDealerId : Maybe Int
    , actions : List Action
    , potSize : Int
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
    , inNextHand : Bool
    , allOut : Bool
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
    D.map6 Player
        (D.field "id" D.int)
        (D.field "nickname" D.string)
        (D.field "chips_count" D.int)
        (D.field "current_card" currentCardDecoder)
        (D.field "in_next_hand" D.bool)
        (D.field "all_out" D.bool)


actionDecoder : Decoder Action
actionDecoder =
    D.map2 Action
        (D.field "created_at" D.int |> D.andThen posixDecoder)
        (D.field "summary" D.string)


gameDataDecoder : Decoder GameData
gameDataDecoder =
    D.map7 GameData
        (D.field "id" D.string)
        (D.field "last_action_at" D.int |> D.andThen posixDecoder)
        (D.field "status" D.string |> D.andThen gameStatusDecoder)
        (D.field "players" (D.list playerDecoder))
        (D.field "current_dealer_id" (D.nullable D.int))
        (D.field "actions" (D.list actionDecoder))
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
    case gameIdFromUrl url of
        Just gameId ->
            case gameId of
                "about" ->
                    AboutPage

                "how-to-play" ->
                    HowToPlayPage

                "profile" ->
                    ProfilePage
                        { profileResponse = WaitingForResponse
                        , newNickname = ""
                        , editingNickname = False
                        , currentlySavingNickname = False
                        }

                _ ->
                    GamePage (GamePageModel WaitingForResponse gameId)

        Nothing ->
            HomePage WaitingForResponse


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
            [ Icon.closedEye "Bluff"
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


relativeTimeInPast : Time.Posix -> Time.Posix -> String
relativeTimeInPast currentTime otherTime =
    if Time.posixToMillis currentTime > Time.posixToMillis otherTime then
        DateFormat.Relative.relativeTime currentTime otherTime

    else
        -- because we refresh model.currentTime every two seconds, sometimes it's
        -- two seconds off. This just makes sure that we don't get confused and
        -- say that something happened in the future
        "just now"


pluralizeWord : String -> Int -> String
pluralizeWord word num =
    if num == 1 then
        "1 " ++ word

    else
        String.fromInt num ++ " " ++ word ++ "s"


pluralizeChips : Int -> String
pluralizeChips num =
    pluralizeWord "chip" num



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
                            , li [] [ text "Everyone who wants to play can then join the game (or just watch)" ]
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
                                , a [ href "https://www.toicon.com/about", target "_blank" ] [ strong [] [ text "to [icon]" ] ]
                                , text ":"
                                , ul [ class "icons-credits" ]
                                    [ li []
                                        [ a [ href "https://www.toicon.com/icons/avocado_save", target "_blank" ] [ Icon.piggyBank "A very nice looking piggy bank icon" ]
                                        ]
                                    , li []
                                        [ a [ href "https://www.toicon.com/icons/hatch_hide", target "_blank" ] [ Icon.closedEye "A very nice looking closed eye icon" ]
                                        ]
                                    , li []
                                        [ a [ href "https://www.toicon.com/icons/afiado_go", target "_blank" ] [ Icon.arrowRight "A very nice looking arrow icon" ] ]
                                    , li []
                                        [ a [ href "https://www.toicon.com/icons/avocado_load", target "_blank" ] [ Icon.load "A very nice looking loading icon" ] ]
                                    , li []
                                        [ a [ href "https://www.toicon.com/icons/avocado_die", target "_blank" ] [ Icon.skull "A very nice looking skull icon" ] ]
                                    ]
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
                                                                , td [] [ text (relativeTimeInPast model.currentTime game.lastActionAt) ]
                                                                ]
                                                        )
                                                        response.games
                                                    )
                                                ]
                                            ]
                                ]

                            FailedToRequest _ ->
                                [ p [] [ text "Whoops, couldn't load your profile. Look, all I can say is I'm sorry." ] ]

                    HomePage homePageModel ->
                        let
                            ( isDisabled, buttonText ) =
                                case homePageModel of
                                    SuccessfullyRequested _ ->
                                        ( False, "New game" )

                                    FailedToRequest _ ->
                                        ( True, "Eeep" )

                                    WaitingForResponse ->
                                        ( True, "Wait for it..." )
                        in
                        [ form [ onSubmit SubmittedGoToGame ]
                            [ input
                                [ attribute "type" "submit"
                                , attribute "value" buttonText
                                , disabled isDisabled
                                ]
                                []
                            ]
                        ]

                    GamePage gamePageModel ->
                        [ div [ class "players-table" ]
                            (case gamePageModel.gameResponse of
                                FailedToRequest _ ->
                                    [ text "Whooooops" ]

                                SuccessfullyRequested response ->
                                    [ p []
                                        [ Icon.piggyBank "The pot"
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
                                                    tr []
                                                        [ td []
                                                            [ span []
                                                                (if response.gameData.currentDealerId == Just player.id then
                                                                    [ Icon.arrowRight "This player is the dealer. That just means the player after them bets first." ]

                                                                 else
                                                                    [ text "" ]
                                                                )
                                                            , span []
                                                                (if player.inNextHand then
                                                                    [ Icon.load "This player will be in the next hand." ]

                                                                 else
                                                                    [ text "" ]
                                                                )
                                                            , span []
                                                                (if player.allOut then
                                                                    [ Icon.skull "This player is all out." ]

                                                                 else
                                                                    [ text "" ]
                                                                )
                                                            , text player.nickname
                                                            ]
                                                        , td []
                                                            [ span []
                                                                (if response.human.id == player.id then
                                                                    [ small [] [ text " (you)" ] ]

                                                                 else
                                                                    [ text "" ]
                                                                )
                                                            , span []
                                                                (case player.currentCard of
                                                                    Just card ->
                                                                        [ text " "
                                                                        , viewCard card
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
                                    [ text "Loading..." ]
                            )
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
                                                        [ div [] [ text (relativeTimeInPast model.currentTime action.time) ]
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
                                                                                "Waiting for another player to join..."
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
                                                p [] [ text "Gameplay actions to come here" ]

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
