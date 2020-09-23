type TVShow* = object
    poster_path*: string
    popularity*: int
    id*: int
    backdrop_path*: string
    vote_average*: float
    overview*: string
    first_air_date*: string
    origin_country*: seq[string]
    genre_ids*: seq[int]
    original_language*: string
    vote_count*: int
    name*: string
    original_name*: string
