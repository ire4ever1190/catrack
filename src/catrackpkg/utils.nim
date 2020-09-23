import httpclient
import tmdbAccount
import asyncdispatch
import constants
import json
import uri

type
    AuthError* = object of HttpRequestError
    ResourceError* = object of HttpRequestError

proc apiUrl(route: string, account: TmdbAccount): string = 
    return baseUrl & route & "?api_key=" & account.apiKey 

proc apiUrl(route: string, params: openarray[(string, string)], account: TmdbAccount): string =
    let urlQuery = encodeQuery(params) & "&api_key=" & account.apiKey
    return baseUrl & route & urlQuery



proc get*(account: TmdbAccount, route: string): Future[JsonNode] {.async.} = 
    return json.parseJson(await (await account.client.request(apiUrl(route, account))).body())

proc get*(account: TmdbAccount, route: string, params: seq[(string, string)]): Future[JsonNode] {.async.} = 
    let url = apiUrl(route, params, account)
    return json.parseJson(await (await account.client.request(url)).body())

proc get*[T](account: TmdbAccount, route: string, params: seq[(string, string)], t: typedesc[T]): Future[T] {.async.} = 
    let url = apiUrl(route, params, account)
    return await (await account.client.request(url)).getResponse(t)

proc get*[T](account: TmdbAccount, route: string, t: typedesc[T]): Future[T] {.gcsafe, async.} = 
    let url = apiUrl(route, account)
    let response = await account.client.request(url)
    return await (response).getResponse(t)

proc post*[T](account: TmdbAccount, route: string, body: JsonNode, t: typedesc[T]): Future[T] {.async.} =
    let response = await account.client.request(apiUrl(route, account), httpMethod = HttpPost, body = $body)
    return await response.getResponse(t)

proc post*(account: TmdbAccount, route: string, body: JsonNode): Future[JsonNode] {.async.} =
    return json.parseJson(await (await account.client.request(apiUrl(route, account), httpMethod = HttpPost, body = $body)).body)

proc getResponse*[T](response: AsyncResponse, t: typedesc[T]): Future[T] {.async.} =
    ## Gets response of request in the form of json 
    ## Checks against normal tmdb errors (401, 404)
    try:
        let jsonData = parseJson(await response.body())
        # echo($jsonData)
        if response.code == Http200 or response.code == Http201:
            return jsonData.to(t)
        else:
            raise newException(HttpRequestError, jsonData["status_message"].getStr())
    except JsonParsingError:
        raise newException(HttpRequestError, $response.code)

proc pageRequest*[T](account: TmdbAccount, route: string, page: int, t: typedesc[T]): Future[seq[T]] {.async.} =
    return await account.get(route, @[("page", $page)], seq[t])    
    
proc pageRequests*[T](account: TmdbAccount, route: string, t: typedesc[T]):  Future[seq[T]] {.async.} =
    let firstPage = await account.get(route)
    let totalPages = firstPage["total_pages"].getInt()
    result &= firstPage["results"].to(seq[t])
    if totalPages > 1:
        for page in 2..totalPages:
            result &= await account.pageRequest(route, page, t)
