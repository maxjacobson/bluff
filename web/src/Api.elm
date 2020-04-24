module Api exposing (availableGameIdUrl, gameUrl, get, joinGameUrl, post)

import Http
import Url.Builder


availableGameIdUrl : String -> String
availableGameIdUrl apiRoot =
    Url.Builder.crossOrigin apiRoot [ "available-game-id.json" ] []


gameUrl : String -> String -> String
gameUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId ++ ".json" ] []


joinGameUrl : String -> String -> String
joinGameUrl apiRoot gameId =
    Url.Builder.crossOrigin apiRoot [ "games", gameId, "players" ++ ".json" ] []


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
