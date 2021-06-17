# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

import catrackpkg/tmdb
import asyncdispatch
import mike
import json
import std/jsonutils
import models/scrobble
import allographer/schema_builder
import allographer/query_builder
import base64
import strutils
import tables
import std/sha1
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
        let account = getAccount()
        echo "Adding new shows"
        for show in await account.getList(TVShowList):
            try:
                RDB().table("show")
                    .insert(%*{
                        "name": show.name,
                        "id": show.id
                    })
            except:
                continue
        echo("updating shows")
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

proc updateService() {.async.} =
    while true:
        try:
            await updateDB()
            await sleepAsync(60 * 60 * 60 * 4 * 1000)
        except:
            let e = getCurrentException()
            await sleepAsync(10000)
            echo e.msg
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

type
    AuthContext = ref object of Context
        authenticated: bool


# Http Basic Auth Implementation that I'm sure has zero issues
beforeGet("/") do (ctx: AuthContext):
    if ctx.hasHeader("Authorization"):
        let creds = ctx.header("Authorization")
            .replace("Basic ", "")
            .decode()
            .split(":")
        ctx.authenticated = creds[0] == Username and creds[1] == Password
    if not ctx.authenticated:
        ctx.status(401)
        ctx.header("WWW-Authenticate", "Basic realm=\"Who you?\"")

let ApiToken = secureHash(Username & Password)
get("/") do (ctx: AuthContext):
    if ctx.authenticated:
        ctx.response.headers["content-type"] = "text/html"
        ctx.send indexFile.replace("APITOKEN", $ApiToken)

get("/index.js") do ():
    ctx.header("content-type", "text/javascript")
    ctx.send jsFile

get("/shows") do ():
    let dbResult = RDB().table("show").get()
    ctx.send %*dbResult
    
get("/shows/uncollected") do ():
    let dbResult = RDB().table("episode")
        .join("show", "episode.showid", "=", "show.id")
        .select("show.name", "episode.id", "episode.season", "episode.episode", "episode.airdate")
        .where("episode.status", "=", 0)
        .get()
    ctx.send %*dbResult

get("/shows/calendar") do ():
    let episodes = RDB().table("episode")
            .select("show.name", "show.id", "episode.season", "episode.episode", "episode.airdate")
            .where("episode.status", "=", 0)
            .join("show", "episode.showID", "=", "show.id")
            .get()
    result = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Cat Track//NONSGML v1.0//EN\r\n"
    
    for episode in episodes:
        result &= "BEGIN:VEVENT\r\n"
        result &= "CATEGORIES:TV\r\n"
        result &= "UID:" & episode["airdate"].str & $episode["season"].getInt() & $episode["episode"].getInt() & episode["name"].str & "\r\n"
        result &= "METHOD:TV\r\n"
        result &= "DTSTAMP:" & episode["airdate"].str.replace("-", "") & "T000000\r\n"
        result &= "DTSTART:" & episode["airdate"].str.replace("-", "") & "T000000\r\n"
        result &= "SUMMARY:" & episode["name"].str & "\r\n"
        result &= "END:VEVENT\r\n"
    result &= "END:VCALENDAR"
    ctx.response.headers["content-type"] = "text/calendar"

# why
type
    Episode = object
        id: int

put "/episode":
    let token = ctx.header("token").parseSecureHash()
    if token != ApiToken:
        ctx.status(401)
        return "Invalid token"
    let episode = ctx.json(Episode)
    RDB().table("episode")
        .where("id", "=", episode.id)
        .update(%*{"status": 1})

post "/show":
    let token = ctx.header("token").parseSecureHash()
    if token != ApiToken:
        ctx.status(401)
        return "Invalid token"
    let account = getAccount()
    let payload = ctx.json(Show)
    let showID = payload.tmdb_id
    if RDB().table("show").where("id", "=", showID).get() == @[]:
        let showDetails = await account.getShowDetails(showID)
        RDB().table("show")
            .insert(%*{
                "name": showDetails.name,
                "id": showDetails.id
            })
        let lastSeason = showDetails.seasons.len()
        var index = 0
        for season in showDetails.seasons:
            inc index
            if season.season_number == 0: continue
            let seasonDetails = await account.getSeason(showID, season.season_number)
            let status = block:
                if payload.onlyLatestSeason and index != lastSeason:
                    1
                else:
                    0

            for episode in seasonDetails.episodes:
                RDB().table("episode")
                    .insert(%*{
                        "id": episode.id,
                        "showID": showDetails.id,
                        "season": season.season_number,
                        "episode": episode.episode_number,
                        "airdate": episode.airdate,
                        "status": status
                    })

    ctx.send "OK"
    
when isMainModule:
    asyncCheck updateService()
    run(5000)
