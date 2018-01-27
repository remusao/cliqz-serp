module Main exposing (..)

import Http exposing (..)
import List
import Json.Decode exposing (..)
import Html exposing (Html, input, div, text, li, ul, h3, h2, a)
import Html.Events exposing (onInput)
import Html.Attributes exposing (..)


main =
    Html.program { init = init, subscriptions = subscriptions, view = view, update = update }


type alias Snippet =
    { description : Maybe String
    , title : String
    }


decodeSnippet : Json.Decode.Decoder Snippet
decodeSnippet =
    Json.Decode.map2 Snippet
        (Json.Decode.maybe (field "description" Json.Decode.string))
        (field "title" Json.Decode.string)


type alias SearchResult =
    { url : String
    , score : Float
    , snippet : Maybe Snippet
    }


decodeResult : Json.Decode.Decoder SearchResult
decodeResult =
    Json.Decode.map3 SearchResult
        (field "url" Json.Decode.string)
        (field "score" Json.Decode.float)
        (Json.Decode.maybe (field "snippet" decodeSnippet))


decodeResults : Decoder (List SearchResult)
decodeResults =
    at [ "results" ] (Json.Decode.list decodeResult)


type alias Model =
    { results : List SearchResult
    , query : String
    , error : Maybe String
    }


type Msg
    = UserInput String
    | SearchResults (Result Http.Error (List SearchResult))


init : ( Model, Cmd Msg )
init =
    ( Model [] "" Nothing, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


urlFromQuery : String -> String
urlFromQuery query =
    "https://api.cliqz.com/api/v2/results?q=" ++ query ++ "&country=fr"


fetchResults : String -> Cmd Msg
fetchResults query =
    let
        request =
            Http.request
                { method = "GET"
                , headers = []
                , url = urlFromQuery query
                , body = Http.emptyBody
                , expect = Http.expectJson decodeResults
                , timeout = Nothing
                , withCredentials = False
                }
    in
        Http.send SearchResults request


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UserInput "" ->
            ( { model | query = "", results = [], error = Nothing }, Cmd.none )

        UserInput q ->
            ( { model | query = q, error = Nothing }, fetchResults q )

        SearchResults (Ok results) ->
            ( { model | results = List.reverse (List.sortBy .score results), error = Nothing }, Cmd.none )

        SearchResults (Err err) ->
            case err of
                Http.Timeout ->
                    ( { model | results = [], error = Just "Timeout" }, Cmd.none )

                Http.NetworkError ->
                    ( { model | results = [], error = Just "NetworkError" }, Cmd.none )

                Http.BadUrl url ->
                    ( { model | results = [], error = Just ("BadUrl: " ++ url) }, Cmd.none )

                Http.BadStatus response ->
                    ( { model
                        | results = []
                        , error =
                            Just
                                ("BadStatus: " ++ toString response.status.code)
                      }
                    , Cmd.none
                    )

                Http.BadPayload str response ->
                    ( { model | results = [], error = Just ("BadPayload: " ++ str) }, Cmd.none )


viewResult : SearchResult -> Html Msg
viewResult result =
    li []
        [ div []
            (case result.snippet of
                Nothing ->
                    [ h2 [ class "result-title" ] [ a [ href result.url ] [ text result.url ] ] ]

                Just snippet ->
                    [ h2 [ class "result-title" ] [ a [ href result.url ] [ text snippet.title ] ]
                    , div [ class "result-url" ] [ text result.url ]
                    , div [ class "result-snippet" ]
                        (case snippet.description of
                            Nothing ->
                                []

                            Just description ->
                                [ text description ]
                        )
                    ]
            )
        ]


viewError : String -> Html Msg
viewError str =
    text str


view : Model -> Html Msg
view model =
    div []
        [ input [ class "input-bar", placeholder "Search Cliqz", onInput UserInput ] []
        , case model.error of
            Nothing ->
                div [ class "results" ] [ ul [] (List.map viewResult model.results) ]

            Just error ->
                div [] [ viewError error ]
        ]
