include karax / prelude
import karax/kajax
import karax/karax
import jsconsole
import json
import strformat
import dom
import algorithm
import times

var loading = true
type Episode = object
    id: int
    name: kstring
    season: int
    episode: int
    airdate: kstring

var token {.importjs.}: cstring
var episodes: seq[Episode] = @[]
let authHeader =  @{"token".cstring: token}
proc addShow(id: int, onlyLatestSeason: bool) =
    let body = cstring $(%* {"tmdbID": id, "onlyLatestSeason": onlyLatestSeason})
    ajaxPost("/show", authHeader, body) do (status: int, data: kstring):
        console.log(status)
        console.log(data)

proc getEpisodes() =
    ajaxGet("/shows/uncollected", @[],proc (_: int, data: kstring) =
        episodes = fromJson[seq[Episode]](data)
        episodes.sort do (x, y: Episode) -> int:
            let
                format = initTimeFormat("yyyy-MM-dd")
                date1 = $(x.airdate)
                date2 = $(y.airdate)
            if date1.parse(format, utc()) > date2.parse(format, utc()):
                1
            else:
                -1
    )

proc watched(id: int) =
    let body = cstring $(%* {
        "id": id
    })
    ajaxPut("/episode", authHeader, body) do (status: int, data: kstring):
        getEpisodes()

proc sendWatched(episode: Episode): proc () =
    result = proc () =
        watched(episode.id)

proc createDom(): VNode =
    once:
        getEpisodes()
    
    result = buildHtml(tdiv):
        tdiv(class = "input-group"):
            label(`for`="showID"):
                text "TMDB ID"
            input(`type`="text", id="showID", onchange = proc () =
                addShow(parseInt(getVNodeById("showID").getInputText()), true)
            )
        for episode in episodes:
            tdiv(class = "row"):
                tdiv(class = "col-md-5 col-sm-12 col-md-offset-5"):
                    tdiv(class="card warning"):
                        tdiv(class="section"):
                            h3 text episode.name
                        tdiv(class="section"):
                            text fmt"Season {episode.season} Episode {episode.episode}"
                            span(class = "icon-search", onclick = sendWatched(episode))
                            br()
                            span(class = "icon-calendar")
                            text " - " & episode.airdate


setRenderer createDom
