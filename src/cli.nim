# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

proc main(): int =
  echo "Hello, World!"

  return 0

when isMainModule:
  system.quit(main())
