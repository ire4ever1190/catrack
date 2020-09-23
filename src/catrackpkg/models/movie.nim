type Movie* = object
    overview*: string
    genre_ids*: seq[int]
    id*: int
    original_title*: string
    original_language*: string
    title*: string
    backdrop_path*: string
    popularity*: float
    vote_count: int
    video: bool
    vote_average: float
    media_type*: string
