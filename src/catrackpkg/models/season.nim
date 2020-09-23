import episode
type Season* = object
    name*: string
    overview*: string
    episodes*: seq[Episode]
