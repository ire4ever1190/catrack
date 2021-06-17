import os
# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "An open source media tracker to track what you have watched and collected (metadata is retrieved from The Movie Database API)"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["models"]
installExt    = @["nim"]
bin           = @["catrack"]



# Dependencies

requires "nim >= 1.2.0"
# requires "https://github.com/ire4ever1190/mike#head"
requires "mike"
requires "allographer == 0.17.4"
requires "schedules#head"
requires "regex"
requires "karax == 1.2.1"

task buildJs, "Builds the javascript file":
    exec "nim js --out:src/index.js -f -d:release src/index.nim"

task release, "builds release":
    buildJsTask()
    exec("nim c -d:ssl -d:release -d:danger --gc:orc --outdir:build/ src/catrack.nim")

