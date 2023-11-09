# Building the Alpaquita build image

Alpaquita is missing some apk packages which we need.
These can be built on Alpaquita with abuild, but this process is not
yet automatized. For now, you need the folder `apk` in this directory
with these packages. We do not want to commit these to the oskar
repository. Therefore, you need to download an archive with the
needed packages from here:

    https://e.pcloud.link/publink/show?code=XZFnGsZuAQrStCMMHhBrCLEA1RS2VWzUUBk

Open this in a browser and you get a file named `apk_for_alpaquita.tar.gz`.
Extract this file in this directory and then the following Docker build
command will work:

    docker build -t arangodb/alpaquitabuildimage1-x86_64:1 .

should work.
