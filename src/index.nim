include karax / prelude
import karax/kajax
import jsconsole
import json
import strformat
import algorithm
import times

var loading = true
type Episode = object
    name: kstring
    season: int
    episode: int
    airdate: kstring
    
var episodes: seq[Episode] = @[]

proc createDom(): VNode =
  if loading:
    loading = false
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
    
  result = buildHtml(tdiv):
    for episode in episodes:
        tdiv(class = "row"):
            tdiv(class = "col-md-5 col-sm-12 col-md-offset-5"):
                tdiv(class="card warning"):
                    tdiv(class="section"):
                        h3 text episode.name
                    tdiv(class="section"):
                        text fmt"Season {episode.season} Episode {episode.episode}"
                        br()
                        span(class = "icon-calendar")
                        text " - " & episode.airdate
            
        
setRenderer createDom
