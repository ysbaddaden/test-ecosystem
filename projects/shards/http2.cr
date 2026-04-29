name: "http2"
source: "https://github.com/ysbaddaden/http2.git"
commands:
  - make bin/server CRFLAGS=$CRYSTAL_FLAGS
  - make test CRFLAGS=$CRYSTAL_FLAGS
formats:
  - crystal tool format
