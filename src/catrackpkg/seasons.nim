import asyncdispatch
import tmdbAccount
import utils
import strformat
import models/season

proc getSeason*(account: TmdbAccount, showID, season: int): Future[Season] {.async.} =
    return await account.get(fmt"/tv/{showID}/season/{season}", Season)


