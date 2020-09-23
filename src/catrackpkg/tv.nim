import asyncdispatch
import models/showdetails
import tmdbAccount
import utils
import strformat

proc getShowDetails*(account: TmdbAccount, showID: int): Future[ShowDetails] {.async.} =
    return await account.get(fmt"/tv/{showID}", ShowDetails)


