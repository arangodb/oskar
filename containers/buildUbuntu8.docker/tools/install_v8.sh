#!/bin/bash
mkdir /opt/lib
mkdir /opt/include
mkdir -p /opt/third_party/icu/source

cd /opt/v8/v8

cp -a out.gn/x64.release.sample/obj/*.a /opt/lib
cp -a out.gn/x64.release.sample/obj/v8_libbase /opt/lib/v8_libbase
cp -a out.gn/x64.release.sample/obj/v8_libplatform /opt/lib/v8_libplatform

cp -a out.gn/x64.release.sample/obj/third_party/icu/*.a /opt/lib
cp -a out.gn/x64.release.sample/obj/third_party/icu/icui18n /opt/lib/icui18n
cp -a out.gn/x64.release.sample/obj/third_party/icu/icuuc_private /opt/lib/icuuc_private
cp -a third_party/icu/source/common /opt/third_party/icu/source
cp -a third_party/icu/source/i18n /opt/third_party/icu/source
cp -a third_party/icu/source/io /opt/third_party/icu/source
cp -a third_party/icu/common /opt/third_party/icu

cp -r include/* /opt/include
# rm -rf /opt/v8
