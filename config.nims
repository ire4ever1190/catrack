import os

# DB Connection
putEnv("DB_DRIVER", "sqlite")
putEnv("DB_CONNECTION", "./db.sqlite3")
putEnv("DB_USER", "")
putEnv("DB_PASSWORD", "")
putEnv("DB_DATABASE", "")

# Logging
putEnv("LOG_IS_DISPLAY", "true")
putEnv("LOG_IS_FILE", "false")
putEnv("LOG_DIR", "/home/jake/Documents/catrack/logs")

switch("d", "ssl")
switch("gc", "orc")
#switch("threads", "on")
