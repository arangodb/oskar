# Building the Alpaquita build image

Alpaquita is missing some apk packages which we need.

This Dockerfile will simply grab them from the Alpine 3.18 repositories.

To build this image, just do:

    docker build -t arangodb/alpaquitabuildimage1-x86_64:1 .
