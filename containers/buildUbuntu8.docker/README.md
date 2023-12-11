# What is this?

This directory contains everything to build an Ubuntu based build image.
It is based on Ubuntu 23.10 and patches glibc with Then
  --enable-static-nss=yes
option. Then we can do our "normal" build image.

Furthermore, this image contains a pre-built version of v8 Version
12.1.165 under /opt/v8. This can be used to build devel based branches
which have the option to use an external v8 engine.

Simply run

```
docker build -t arangodb/ubuntubuildarangodb8-x86_64:1 .
```

Note that this currently only works on the x86_64 architecture.
