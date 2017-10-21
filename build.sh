#!/bin/sh -xe

# clean &  create builddir
BUILDDIR=/tmp/couchdbx-core
rm -rf $BUILDDIR couchdb-mac-app
mkdir -p $BUILDDIR

DESTDIR=./build
rm -rf $DESTDIR
mkdir -p $DESTDIR

# prepare build deps
# brew update
# brew install erlang spidermonkey icu4c md5sha1sum
# brew link -f icu4c

# get latest couchdb release:
rm -rf apache-couchdb-*
wget https://dist.apache.org/repos/dist/release/couchdb/source/2.1.0/apache-couchdb-2.1.0.tar.gz
tar xzf apache-couchdb-*

# build couchdb
cd apache-couchdb-*
./configure
make
make release
cp -r rel/couchdb/ $BUILDDIR
cd ..

COUCHDB_VERSION=`ls apache-couchdb-* | head -n 1 | grep -Eo '(\d+\.\d+\.\d+)' | head -1`

# SOURCES="/usr/local/lib \
#     /usr/local/bin \
#     /usr/local/etc \
#     /usr/local/var \
#     /usr/local/share"
#
# cp -r $SOURCES $BUILDDIR

ICUDATA_VERSION=`ls /usr/local/opt/icu4c/lib/libicuuc.??.?.dylib | grep -o '\d\d\.\d'`
ICUUCI18N_VERSION=`ls /usr/local/opt/icu4c/lib/libicuuc.??.dylib | grep -o '\d\d'`

# copy icu & ssl && nspr libs to safety
cp /usr/local/opt/icu4c/lib/libicuuc.$ICUUCI18N_VERSION.dylib \
   /usr/local/opt/icu4c/lib/libicudata.$ICUDATA_VERSION.dylib \
   /usr/local/opt/icu4c/lib/libicui18n.$ICUUCI18N_VERSION.dylib \
   /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib \
   /usr/local/opt/nspr/lib/libplds4.dylib \
   /usr/local/opt/nspr/lib/libplc4.dylib \
   /usr/local/opt/nspr/lib/libnspr4.dylib \
   /usr/local/opt/spidermonkey/lib/libmozjs185.1.0.dylib \
     $BUILDDIR/lib/


# replace PATHs
cd $BUILDDIR
#
# cat <<EOF >> etc/couchdb/local.ini
# [log]
# file = var/log/couch.log
# EOF

# util fun
adjust_name() {
    FROM=$1;
    TO=$2
    TARGET=$3
    chmod +w $TARGET
    install_name_tool -change $FROM $TO $TARGET
    if [ $? ~ne 0 ]; then
      echo "FAIL $TARGET"
      exit 1
    fi
    chmod -w $TARGET
}

# adjust couch_icu_driver linking
adjust_name /usr/local/opt/icu4c/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
adjust_name /usr/local/opt/icu4c/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
adjust_name /usr/local/opt/icu4c/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
adjust_name @loader_path/libicudata.$ICUUCI18N_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib
adjust_name @loader_path/libicudata.$ICUUCI18N_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib

# adjust couch_ejson_compare linking
adjust_name /usr/local/opt/icu4c/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
adjust_name /usr/local/opt/icu4c/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
adjust_name /usr/local/opt/icu4c/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so

# adjust crypto.so
adjust_name /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib lib/libcrypto.1.0.0.dylib lib/crypto-*/priv/lib/crypto.so

# adjust couchjs
adjust_name /usr/local/opt/spidermonkey/lib/libmozjs185.1.0.dylib lib/libmozjs185.1.0.dylib bin/couchjs

# adjust libmozjs & deps
adjust_name /usr/local/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libmozjs185.1.0.dylib
adjust_name /usr/local/opt/nspr/lib/libplc4.dylib lib/libplc4.dylib lib/libmozjs185.1.0.dylib
adjust_name /usr/local/opt/nspr/lib/libnspr4.dylib lib/libnspr4.dylib lib/libmozjs185.1.0.dylib
adjust_name /usr/local/opt/spidermonkey/lib/libmozjs185.1.0.dylib lib/libmozjs185.1.0.dylib lib/libmozjs185.1.0.dylib


adjust_name /usr/local/Cellar/nspr/4.11/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplds4.dylib
adjust_name /usr/local/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libplds4.dylib

adjust_name /usr/local/Cellar/nspr/4.11/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplc4.dylib
adjust_name /usr/local/opt/nspr/lib/libplc4.dylib lib/libplc4.dylib lib/libplc4.dylib

adjust_name /usr/local/opt/nspr/lib/libnspr4.dylib lib/libnspr4.dylib lib/libnspr4.dylib

# trim package, lol

TO_PRUNE=" \
  share/doc/ \
  share/locale/ \
  share/info/ \
  share/man/ \
  lib/libwx_* \
  lib/libjpeg* \
  lib/libpng* \
  lib/libtiff* \
  lib/libicudata.dylib \
  lib/libicudata.58.dylib \
  lib/libmozjs185-1.0.a \
  lib/libmozjs185.1.0.0.dylib \
  lib/libmozjs185.dylib \
  lib/erlang/man \
  lib/erlang/lib/appmon-*/ \
  lib/erlang/lib/common_test-*/ \
  lib/erlang/lib/cosEvent-*/ \
  lib/erlang/lib/cosEventDomain-*/ \
  lib/erlang/lib/cosFileTransfer-*/ \
  lib/erlang/lib/cosNotification-*/ \
  lib/erlang/lib/cosProperty-*/ \
  lib/erlang/lib/cosTime-*/ \
  lib/erlang/lib/cosTransactions-*/ \
  lib/erlang/lib/debugger-*/ \
  lib/erlang/lib/dialyzer-*/ \
  lib/erlang/lib/diameter-*/ \
  lib/erlang/lib/docbuilder-*/ \
  lib/erlang/lib/edoc-*/ \
  lib/erlang/lib/erl_docgen-*/ \
  lib/erlang/lib/erl_interface-*/ \
  lib/erlang/lib/erts-*/ \
  lib/erlang/lib/et-*/ \
  lib/erlang/lib/eunit-*/ \
  lib/erlang/lib/gs-*/ \
  lib/erlang/lib/hipe-*/ \
  lib/erlang/lib/ic-*/ \
  lib/erlang/lib/inviso-*/ \
  lib/erlang/lib/jinterface-*/ \
  lib/erlang/lib/megaco-*/ \
  lib/erlang/lib/mnesia-*/ \
  lib/erlang/lib/observer-*/ \
  lib/erlang/lib/odbc-*/ \
  lib/erlang/lib/orber-*/ \
  lib/erlang/lib/otp_mibs-*/ \
  lib/erlang/lib/parsetools-*/ \
  lib/erlang/lib/percept-*/ \
  lib/erlang/lib/pman-*/ \
  lib/erlang/lib/reltool-*/ \
  lib/erlang/lib/runtime_tools-*/ \
  lib/erlang/lib/snmp-*/ \
  lib/erlang/lib/ssh-*/ \
  lib/erlang/lib/test_server-*/ \
  lib/erlang/lib/toolbar-*/ \
  lib/erlang/lib/tools-*/ \
  lib/erlang/lib/tv-*/ \
  lib/erlang/lib/typer-*/ \
  lib/erlang/lib/webtool-*/ \
  lib/erlang/lib/wx-*/ \
  lib/erlang/lib/*/src \
  bin/wx* \
  bin/js \
  bin/*tiff* \
  bin/*png* \
  bin/*jpeg* \
"

rm -rf $TO_PRUNE

# build mac app
cd -

git clone git://github.com/janl/couchdb-mac-app.git couchdb-mac-app

cd couchdb-mac-app
  perl -pi.bak -e "s/\<string\>VERSION\<\/string\>/<string>$COUCHDB_VERSION<\/string>/" CouchDB\ Server/Apache\ CouchDB-Info.plist
  xcodebuild clean
  xcodebuild
cd ..

cp couchdb-mac-app/build/Release/Apache-*.zip $DESTDIR

cd $DESTDIR
ZIPFILE=`ls Apache-*.zip`
shasum -a 256 Apache-*.zip > $ZIPFILE.sha256
shasum -a 512 Apache-*.zip > $ZIPFILE.sha512

echo "now run gpg --armor --detach-sig $DESTDIR/$ZIPFILE > $DESTDIR/$ZIPFILE.asc"
