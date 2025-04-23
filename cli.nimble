# Package

version          = "0.1.0"
author           = "Isaac Naylor"
description      = "A Command Line Interface for https://github.com/Wraith29/apollo-server"
license          = "MIT"
srcDir           = "src"
bin              = @["main"]
namedBin["main"] = "cli"


# Dependencies

requires "nim >= 2.2.4"
