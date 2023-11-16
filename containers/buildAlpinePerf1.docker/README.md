# What is this?

This directory contains everything to build a slightly modified Alpine
build image for ArangoDB. It is based on Alpine 3.18 and patches libmusl
with changes from here:

    https://github.com/bell-sw/glibc-string

These are faster string library functions, basically from glibc.

To achieve this, we need to:

  - rebuild gcc with support for gnu indirect functions (ifunc)
  - build and install `glibc-string`
  - rebuild libmusl using `glibc-string`

Then we can do our "normal" build image.

Simply run

```
docker build -t arangodb/alpineperfbuildimage1-$ARCH:1 .
```

Note that this almost certainly only works on `x86_64`.
