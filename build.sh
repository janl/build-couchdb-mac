#!/bin/sh -ex

# clean &  create builddir
BUILDDIR=/tmp/couchdbx-core
rm -rf $BUILDDIR
mkdir -p $BUILDDIR

COUCHDB_VERSION=`couchdb -V | grep -Eo '(\d\.\d\.\d)'`

SOURCES="/usr/local/lib \
    /usr/local/bin \
    /usr/local/etc \
    /usr/local/var \
    /usr/local/share"

cp -r $SOURCES $BUILDDIR

# copy icu & ssl && nspr libs to safety
cp /usr/local/opt/icu4c/lib/libicuuc.56.dylib \
   /usr/local/opt/icu4c/lib/libicudata.56.dylib \
   /usr/local/opt/icu4c/lib/libicudata.56.1.dylib \
   /usr/local/opt/icu4c/lib/libicui18n.56.dylib \
   /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib \
   /usr/local/opt/libplds4.dylib \
   /usr/local/opt/libplc4.dylib \
   /usr/local/opt/libnspr4.dylib \
     $BUILDDIR/lib/


# replace PATHs
cd $BUILDDIR

perl -pi.bak -e 's/\/usr\/local\///g' bin/couchdb etc/couchdb/default.ini
perl -pi.bak2 -e 's/Cellar\/couchdb\/[^\/]*\///g' bin/couchdb etc/couchdb/default.ini
perl -pi.bak3 -e 's/opt\/erlang\///g' bin/couchdb
perl -pi.bak -e 's/\/usr\/local\/Cellar\/erlang\/17\.1_1/`pwd`/' bin/erl

cat <<EOF >> etc/couchdb/local.ini
[log]
file = var/log/couch.log
EOF

# util fun
adjust_name() {
    FROM=$1;
    TO=$2
    TARGET=$3
    chmod +w $TARGET
    install_name_tool -change $FROM $TO $TARGET
    chmod -w $TARGET
}

# adjust couch_icu_driver linking
adjust_name /usr/local/opt/icu4c/lib/libicudata.56.1.dylib lib/libicudata.56.1.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_icu_driver.so
adjust_name /usr/local/opt/icu4c/lib/libicuuc.56.dylib lib/libicuuc.56.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_icu_driver.so
adjust_name /usr/local/opt/icu4c/lib/libicui18n.56.dylib lib/libicui18n.56.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_icu_driver.so
adjust_name @loader_path/libicudata.56.dylib @loader_path/libicudata.56.1.dylib lib/libicui18n.56.dylib 
adjust_name @loader_path/libicudata.56.dylib @loader_path/libicudata.56.1.dylib lib/libicuuc.56.dylib

# adjust couch_ejson_compare linking
adjust_name /usr/local/opt/icu4c/lib/libicudata.56.1.dylib lib/libicudata.56.1.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_ejson_compare.so
adjust_name /usr/local/opt/icu4c/lib/libicuuc.56.dylib lib/libicuuc.56.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_ejson_compare.so
adjust_name /usr/local/opt/icu4c/lib/libicui18n.56.dylib lib/libicui18n.56.dylib lib/couchdb/erlang/lib/couch-$COUCHDB_VERSION/priv/lib/couch_ejson_compare.so

# adjust crypto.so
adjust_name /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib lib/libcrypto.1.0.0.dylib /tmp/couchdbx-core/lib/erlang/lib/crypto-3.6.2/priv/lib/crypto.so


# adjust couchjs
adjust_name /usr/local/lib/libmozjs185.1.0.dylib lib/libmozjs185.1.0.dylib bin/couchjs

# adjust libmozjs & deps
adjust_name /usr/local/opt/libplds4.dylib lib/libplds4.dylib lib/libmozjs185.1.0.dylib
adjust_name /usr/local/opt/libplc4.dylib lib/libplc4.dylib lib/libmozjs185.1.0.dylib
adjust_name /usr/local/opt/libnspr4.dylib lib/libnspr4.dylib lib/libmozjs185.1.0.dylib

adjust_name /usr/local/Cellar/nspr/4.10.6/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplds4.dylib
adjust_name /usr/local/Cellar/nspr/4.10.6/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplc4.dylib



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
  lib/libicudata.56.dylib \
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

if [ ! -d couchdb-mac-app ]; then
  git clone git://github.com/janl/couchdb-mac-app.git couchdb-mac-app
fi

cd couchdb-mac-app
  git pull --rebase
  perl -pi.bak -e "s/\<string\>VERSION\<\/string\>/<string>$COUCHDB_VERSION<\/string>/" Couchbase\ Server/Apache\ CouchDB-Info.plist
  xcodebuild
cd ..

cp couchdb-mac-app/build/Release/Apache-*.zip* .
