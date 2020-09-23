import tmdbAccount
import constants
import utils
import json
import asyncdispatch
import models/movie
import models/tvshow
import strformat

type 
    Gravatar* = object
        hash*: string
 
    Avatar* = object
        gravatar*: Gravatar

    AccountDetails* = object
        avatar*: Avatar
        id*: int
        iso_639_1*: string
        iso_3166_1*: string
        name*: string
        include_adult*: bool
        username*: string    

proc getDetails*(account: TmdbAccount): Future[AccountDetails] {.async.} =
    return await account.get("/account", AccountDetails)

proc getMoviesWatchlist*(account: TmdbAccount): Future[seq[Movie]] {.async.} =
    return await account.pageRequests(fmt"/account/{account.id}/watchlist/movies", Movie)

proc getTVWatchlist*(account: TmdbAccount): Future[seq[TVShow]] {.async.} =
    return await account.pageRequests(fmt"/account/{account.id}/watchlist/tv", TVShow)
