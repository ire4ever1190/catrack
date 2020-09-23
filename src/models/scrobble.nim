type
    Episode* = object
        season*: int
        episode*: int
        status*: int # 0 not collected, 1 collected, 2 watched

    Show* = object
        tmdb_id*: string
        episodes*: seq[Episode]
