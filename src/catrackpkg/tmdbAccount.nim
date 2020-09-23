import httpclient
export httpClient

type TmdbAccount* = object
    apiKey*: string
    username*: string
    password*: string
    sessionID*: string
    id*: int
    client*: AsyncHttpClient
    
let tmdbDefaultHeaders* = newHttpHeaders({
    "Content-Type": "application/json"
})

proc newTmdbAccount*(apiKey: string): TmdbAccount = 
    ## Creates a new instance with just the apikey.
    ## Used for just public data
    TmdbAccount(
        apiKey: apiKey,
        client: newAsyncHttpClient(headers = newHttpHeaders({
            "Content-Type": "application/json"
        }))
    )

