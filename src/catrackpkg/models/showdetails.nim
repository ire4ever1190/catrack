type
    Season* = object
        episode_count*: int
        season_number*: int

    ShowDetails* = object
        name*: string
        id*: int
        in_production*: bool
        seasons*: seq[Season]
        poster_path*: string
