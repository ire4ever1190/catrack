import tmdbAccount
import utils
import json
import asyncdispatch
import models/tvshow
import strformat

proc getList*(account: TmdbAccount, listID: int): Future[seq[TVShow]] {.async.} =
    let results = await account.get(fmt"/list/{listID}")
    return results["items"].to(seq[TVShow])

# proc delFromList(account: TmdbAccount, listID, mediaID: int) {.async.} =
    # let body = %*{
        # "media_id": mediaID
    # }
    # await account.post(fmt"/list/{listID}/remove_item", body)
# 
