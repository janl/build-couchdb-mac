#!/bin/sh -x

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
#curl -O https://dist.apache.org/repos/dist/dev/couchdb/source/2.3.1/rc.3/apache-couchdb-3.0.0-RC1.tar.gz
curl -O https://dist.apache.org/repos/dist/dev/couchdb/source/3.0.0/rc.1/apache-couchdb-3.0.0-RC1.tar.gz

tar xzf apache-couchdb-*

COUCHDB_VERSION=`ls apache-couchdb-* | head -n 1 | grep -Eo '(\d+\.\d+\.\d+)' | head -1`

# build couchdb
cd apache-couchdb-*

COUCHDB_MAJOR_VERSION=`echo $COUCHDB_VERSION | cut -b 1`

case $COUCHDB_MAJOR_VERSION in
    3)
  echo "building for 3"
  perl -pi.bak -e 's,\-name\ couchdb\@127\.0\.0\.1,\-name\ couchdb\@localhost,' ./configure # fixme later
  ./configure --spidermonkey-version 60
  make
  make release
  cp -r rel/couchdb/ $BUILDDIR
  break
    ;;
    2)
	echo "building for 2"
	perl -pi.bak -e 's,\-name\ couchdb\@127\.0\.0\.1,\-name\ couchdb\@localhost,' ./configure # fixme later
	./configure
	make
	make release
	cp -r rel/couchdb/ $BUILDDIR
	break
    ;;
    1)
	echo "building for 1"
	./configure --prefix=$BUILDDIR
	make -j5
	make install
	break
    ;;

    *)
	echo "unknown CouchDB Version $COUCHDB_VERSION"
	exit 7
esac

cd ..


# SOURCES="/usr/local/lib \
#     /usr/local/bin \
#     /usr/local/etc \
#     /usr/local/var \
#     /usr/local/share"
#
# cp -r $SOURCES $BUILDDIR

ICU_VERSION=`ls /usr/local/opt/icu4c/lib/libicuuc.??.?.dylib | grep -o '\d\d\.\d'`
NSPR_VERSION=`ls /usr/local/Cellar/nspr/`

# copy icu & ssl && nspr libs to safety
cp /usr/local/opt/icu4c/lib/libicuuc.$ICU_VERSION.dylib \
   /usr/local/opt/icu4c/lib/libicudata.$ICU_VERSION.dylib \
   /usr/local/opt/icu4c/lib/libicui18n.$ICU_VERSION.dylib \
   /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib \
   /usr/local/opt/nspr/lib/libplds4.dylib \
   /usr/local/opt/nspr/lib/libplc4.dylib \
   /usr/local/opt/nspr/lib/libnspr4.dylib \
   /usr/local/opt/spidermonkey60/lib/libmozjs-60.dylib \
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
    if [ $? -ne 0 ]; then # this does not seem to work for some reason
      echo "FAIL $TARGET"
      exit 1
    fi
    chmod -w $TARGET
}
adjust_name_by_tag() {
    FROM_TAG=$1;
    TO=$2
    TARGET=$3
    chmod +w $TARGET
    FROM=`otool -L $TARGET | grep $FROM_TAG | awk '{print $1}'`
    install_name_tool -change $FROM $TO $TARGET
    if [ $? -ne 0 ]; then # this does not seem to work for some reason
      echo "FAIL $TARGET"
      exit 1
    fi
    chmod -w $TARGET
}

# adjust couch_icu_driver linking
case $COUCHDB_MAJOR_VERSION in
    [23])
        echo "adjusting for 2/3"
	adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
	adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
	adjust_name_by_tag libicui18n lib/libicui18n.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so

        # adjust couch_ejson_compare linking
	adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	adjust_nam_by_tage_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	adjust_name_by_tag libicui18n lib/libicui18n.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	break
    ;;
    1)
        echo "adjusting for 1"
	adjust_name /usr/local/opt/icu4c/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so
	adjust_name /usr/local/opt/icu4c/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so
	adjust_name /usr/local/opt/icu4c/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so

        # adjust couch_ejson_compare linking
	adjust_name /usr/local/opt/icu4c/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
	adjust_name /usr/local/opt/icu4c/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
	adjust_name /usr/local/opt/icu4c/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
	break
    ;;

    *)
        echo "unknown CouchDB Version $COUCHDB_VERSION"
        exit 7
esac



adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/libicui18n.$ICU_VERSION.dylib
adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/libicui18n.$ICU_VERSION.dylib
adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/libicuuc.$ICU_VERSION.dylib


# adjust crypto.so
adjust_name /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib lib/libcrypto.1.1.dylib lib/crypto-*/priv/lib/crypto.so

# adjust couchjs
adjust_name /usr/local/opt/spidermonkey60/lib/libmozjs-60.dylib lib/libmozjs-60.dylib bin/couchjs

# adjust libmozjs & deps
adjust_name /usr/local/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libmozjs-60.dylib
adjust_name /usr/local/opt/nspr/lib/libplc4.dylib lib/libplc4.dylib lib/libmozjs-60.dylib
adjust_name /usr/local/opt/nspr/lib/libnspr4.dylib lib/libnspr4.dylib lib/libmozjs-60.dylib
adjust_name /usr/local/opt/spidermonkey60/lib/libmozjs-60.dylib lib/libmozjs-60.dylib lib/libmozjs-60.dylib


adjust_name /usr/local/Cellar/nspr/$NSPR_VERSION/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplds4.dylib
adjust_name /usr/local/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libplds4.dylib

adjust_name /usr/local/Cellar/nspr/$NSPR_VERSION/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplc4.dylib
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
