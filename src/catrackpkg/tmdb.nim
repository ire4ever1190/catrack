template ixport(package: untyped): untyped =
    import package
    export package

ixport account
ixport tmdbAccount
ixport authentication
ixport tv
ixport seasons
ixport lists
