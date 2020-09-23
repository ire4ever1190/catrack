import tmdbAccount
import utils
import json
import asyncdispatch
import models/listDetail
import strformat

proc getList*(account: TmdbAccount, listID: int): Future[seq[listDetails]] {.async.} =
    let results = await account.get(fmt"/list/{listID}")
    return results["items"].to(seq[listDetails])

# proc delFromList(account: TmdbAccount, listID, mediaID: int) {.async.} =
    # let body = %*{
        # "media_id": mediaID
    # }
    # await account.post(fmt"/list/{listID}/remove_item", body)
# 
