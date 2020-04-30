module Api exposing
    ( availableGameIdUrl
    , checkUrl
    , foldUrl
    , gameUrl
    , get
    , joinGameUrl
    , placeBetUrl
    , post
    , profileUrl
    , put
    , startGameUrl
    )

import Http
import Url.Builder


availableGameIdUrl : String -> String
availableGameIdUrl apiRoot =
    Url.Builder.crossOrigin apiRoot [ "available-game-id.json" ] []


checkUrl : String -> String -> String
checkUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "checks" ++ ".json" ] []


foldUrl : String -> String -> String
foldUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "folds" ++ ".json" ] []


gameUrl : String -> String -> String
gameUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId ++ ".json" ] []


joinGameUrl : String -> String -> String
joinGameUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "players" ++ ".json" ] []


placeBetUrl : String -> String -> String
placeBetUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "bets" ++ ".json" ] []


profileUrl : String -> String
profileUrl apiRoot =
    Url.Builder.crossOrigin apiRoot [ "profile" ++ ".json" ] []


startGameUrl : String -> String -> String
startGameUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "start" ++ ".json" ] []


type alias GetRequest m =
    { url : String
    , uuid : String
    , expect : Http.Expect m
    }


get : GetRequest m -> Cmd m
get request =
    Http.request
        { url = request.url
        , expect = request.expect
        , headers = humanityRecognitionHeaders request.uuid
        , tracker = Nothing
        , timeout = Nothing
        , method = "GET"
        , body = Http.emptyBody
        }


type alias PutRequest m =
    { url : String
    , uuid : String
    , expect : Http.Expect m
    , body : Http.Body
    }


put : PutRequest m -> Cmd m
put request =
    Http.request
        { url = request.url
        , expect = request.expect
        , headers = humanityRecognitionHeaders request.uuid
        , tracker = Nothing
        , timeout = Nothing
        , method = "PUT"
        , body = request.body
        }


type alias PostRequest m =
    { url : String
    , uuid : String
    , expect : Http.Expect m
    , body : Http.Body
    }


post : PostRequest m -> Cmd m
post request =
    Http.request
        { url = request.url
        , expect = request.expect
        , headers = humanityRecognitionHeaders request.uuid
        , tracker = Nothing
        , timeout = Nothing
        , method = "POST"
        , body = request.body
        }


humanityRecognitionHeaders : String -> List Http.Header
humanityRecognitionHeaders uuid =
    [ Http.header "X-Human-UUID" uuid ]
