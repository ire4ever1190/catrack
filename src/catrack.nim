# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

import catrackpkg/tmdb
import asyncdispatch
import mike
import json
import models/scrobble
import allographer/schema_builder
import allographer/query_builder
import strutils
import tables
import regex
import config

schema([
    table("show", [
        Column().integer("id").unique(),
        Column().string("name"),
    ]),
    table("episode", [
        Column().increments("id").unique(),
        Column().foreign("showID").reference("id").on("show"),
        Column().integer("season"),
        Column().integer("episode"),
        Column().integer("status"),
        Column().string("airdate")
    ]),
    table("movie", [
        Column().integer("id").unique(),
        Column().string("name"),
        Column().integer("status")
    ])
])

proc getAccount(): TmdbAccount {.gcsafe.} = newTmdbAccount(apiKey)

proc updateDB() {.async.} =
        echo("updating shows")
        let account = getAccount()
        for show in RDB().table("show").select("id").get():
            let showID = show["id"].getInt()
            # Get all previous episodes for the show
            var episodes = newSeq[int]()
            for episode in RDB().table("episode").select("id").where("showID", "=", showID).get():
                episodes.add(episode["id"].getInt())
            # If the show isn't in production then don't update
            let showDetails = await account.getShowDetails(showID)
            if not showDetails.in_production:
                continue
            
            for season in showDetails.seasons:
                if season.season_number == 0: continue # Ignore specials
                let seasonDetails = await account.getSeason(showID, season.season_number)
                var episodesToAdd = newSeq[JsonNode]() # Holds list of episodes for mass inserting
                for episode in seasonDetails.episodes:
                    if not episodes.contains(episode.id):
                        episodesToAdd.add(%*{
                                "showID": showDetails.id,
                                "season": season.season_number,
                                "episode": episode.episode_number,
                                "id": episode.id,
                                "airdate": episode.airdate,
                                "status": 0
                            })
                    else:
                        RDB().table("episode")
                            .where("showID", "=", showID)
                            .where("season", "=", season.season_number)
                            .where("episode", "=", episode.episode_number)
                            .update(%*{
                                "airdate": episode.airdate
                            })
                if len(episodesToAdd) > 0:
                    RDB().table("episode")
                        .insert(episodesToAdd)
        echo("Shows updated")
        
        echo("Updating movies")
        for movie in await account.getList(145676):
            try:
                RDB().table("movie")
                        .insert(%*{
                            "id": movie.id,
                            "name": movie.title,
                            "status": 0
                        })
            except:
                continue
            
        echo("Movies updated")

proc updateService() {.async.} =
    while true:
        try:
            await updateDB()
            await sleepAsync(60 * 60 * 60 * 4 * 1000)
        except:
            asyncCheck updateService()
            return
        
type
    UncollectedShows = object
        name: string
        episodes: seq[minEpisode]
        
    minEpisode = object
        season: int
        episode: int

const 
    indexFile = readFile("src/index.html")
    jsFile = readFile("src/index.js")

status 404:
    "<h1>404 you dummy</h1>"

get "/":
    addHeader("content-type", "text/html")
    send indexFile

get "/index.js":
    addHeader("content-type", "text/javascript")
    send jsFile

get "/shows":
    let dbResult = RDB().table("show").get()
    echo(len($dbResult))
    send dbResult
    
get "/shows/uncollected":
    let dbResult = RDB().table("episode")
        .select("show.name", "show.id", "episode.season", "episode.episode", "episode.airdate")
        .where("episode.status", "=", "0")
        .join("show", "episode.showID", "=", "show.id")
        .get()
    send dbResult

get "/shows/calendar":
    let episodes = RDB().table("episode")
            .select("show.name", "show.id", "episode.season", "episode.episode", "episode.airdate")
            .where("episode.status", "=", "0")
            .join("show", "episode.showID", "=", "show.id")
            .get()
    var body = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Cat Track//NONSGML v1.0//EN\r\n"
    
    for episode in episodes:
        body &= "BEGIN:VEVENT\r\n"
        body &= "CATEGORIES:TV\r\n"
        body &= "UID:" & episode["airdate"].str & $episode["season"].getInt() & $episode["episode"].getInt() & episode["name"].str & "\r\n"
        body &= "METHOD:TV\r\n"
        body &= "DTSTAMP:" & episode["airdate"].str.replace("-", "") & "T000000\r\n"
        body &= "DTSTART:" & episode["airdate"].str.replace("-", "") & "T000000\r\n"
        body &= "SUMMARY:" & episode["name"].str & "\r\n"
        body &= "END:VEVENT\r\n"
    body &= "END:VCALENDAR"
    addHeader("content-type", "text/calendar")
    send(body)
             

get "/movies/uncollected":
    let dbResult = RDB().table("movie")
        .select("id", "name")
        .where("status", "=", "0")
        .get()
    send dbResult

post "/scrobble/movie":
    let body = request.body
    let payload = parseJson(body)
    let movieID = payload["id"].getInt()
    let status = payload["status"].getInt()
    RDB().table("movie")
        .where("id", "=", movieID)
        .update(%*{
            "status": status
        })
    
post "/scrobble/show":
    let account = getAccount()
    let payload = json(Show)
    let showID = payload.tmdb_id
    if RDB().table("show").where("id", "=", showID).get() == @[]:
        let showDetails = await account.getShowDetails(payload.tmdb_id.parseInt())
        RDB().table("show")
            .insert(%*{
                "name": showDetails.name,
                "id": showDetails.id
            })
        for season in showDetails.seasons:
            if season.season_number == 0: continue
            let seasonDetails = await account.getSeason(showID.parseInt(), season.season_number)
            for episode in seasonDetails.episodes:
                RDB().table("episode")
                    .insert(%*{
                        "id": episode.id,
                        "showID": showDetails.id,
                        "season": season.season_number,
                        "episode": episode.episode_number,
                        "airdate": episode.airdate,
                        "status": 0
                    })
        
        
    for episode in payload.episodes:
        try:
            RDB().table("episode")
                .where("showID", "=", showID)
                .where("season", "=", episode.season)
                .where("episode", "=", episode.episode)
                .update(%*{
                    "status": episode.status                    
                })
        except:
            continue
    send "OK"
    
when isMainModule:
    asyncCheck updateService()
    startServer(5000)
