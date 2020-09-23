import macros
import streams
import strformat
import strutils

macro createGlobals(): untyped =
    result = newStmtList()
    var 
        strm = readFile("config.txt")
        line = ""
    for line in strm.split("\n"):
        if line == "": break
        let 
            values = line.split("=")
            key = values[0]
            value = values[1]
        result.add parseExpr(&"const {key}* = {value}")
createGlobals()
