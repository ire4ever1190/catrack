import tmdbAccount
import account
import constants
import utils
import json
import asyncdispatch

type
    RequestToken* = object
        success*: bool
        expires_at*: string
        request_token*: string

proc createToken*(account: TmdbAccount): Future[RequestToken] {.async.} =
    let requestToken = await account.get("/authentication/token/new", RequestToken)
    return requestToken
    
proc getSession*(account: TmdbAccount): Future[string] {.async.} =
    let body = %*{
        "username": account.username,
        "password": account.password,
        "request_token": (await account.createToken()).request_token
    }
    let token = await account.post("/authentication/token/validate_with_login", body, RequestToken)
    assert(token.success)
    let sessionRequest = await account.post("/authentication/session/new", %*{"request_token": token.requestToken})
    return sessionRequest["session_id"].getStr()


proc newTmdbAccount*(apiKey, username, password: string): Future[TmdbAccount] {.async.} =
    ## Creates a new instance of TmdbAccount using the users username and password
    ## Gets all the needed details to make requests to account
    var account = TmdbAccount(
        apiKey: apiKey,
        username: username,
        password: password,
        client: newAsyncHttpClient(headers = tmdbDefaultHeaders)
    )
    let sessionID = await account.getSession()
    account.sessionID = sessionID
    let details = await account.getDetails()
    account.id = details.id
    return account
