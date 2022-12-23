#!/bin/sh -x


if [ -z "$CODESIGN_IDENTITY" ]; then
  echo "No CODESIGN_IDENTITY found. Exiting."
  exit 1
fi

URL=$1

if [ -z "$URL" ]; then
  echo "No URL found"
  echo "Usage: ./build.sh URL"
  echo "Example: ./build.sh https://dist.apache.org/repos/dist/dev/couchdb/source/3.3.0/rc.2/apache-couchdb-3.3.0-RC2.tar.gz"
  echo "Exiting"
  exit 2
fi

SM_VERSION=91

# clean &  create builddir
BUILDDIR=/tmp/couchdbx-core
rm -rf $BUILDDIR couchdb-mac-app
mkdir -p $BUILDDIR

ENT_PATH=`pwd`

DESTDIR=./build
rm -rf $DESTDIR
mkdir -p $DESTDIR

# prepare build deps
# brew update
# brew install erlang spidermonkey icu4c md5sha1sum
# brew link -f icu4c


PREFIX=/usr/local

IS_ARM=`uname -a | grep arm64`

if [ -n "$IS_ARM" ]; then
  PREFIX=/opt/homebrew
fi

# get latest couchdb release:
rm -rf apache-couchdb-*
sleep 4

curl -O $URL
tar xzf apache-couchdb-*

COUCHDB_VERSION=`ls apache-couchdb-* | head -n 1 | grep -Eo '(\d+\.\d+\.\d+)' | head -1`

# build couchdb
cd apache-couchdb-*

COUCHDB_MAJOR_VERSION=`echo $COUCHDB_VERSION | cut -b 1`
ERLANG_PREFIX=$PREFIX/opt/couchdbx-erlang
ICU_PREFIX=$PREFIX/opt/icu4c

case $COUCHDB_MAJOR_VERSION in
    3)
  echo "building for 3"
  perl -pi.bak -e 's,\-name\ couchdb\@127\.0\.0\.1,\-name\ couchdb\@localhost,' ./configure # fixme later
  export PATH=$ERLANG_PREFIX=$PREFIX/opt/couchdbx-erlang/bin:$PATH
  export LDFLAGS="-L$ICU_PREFIX/lib"
  export CFLAGS="-I$ICU_PREFIX/include"
  export CPPFLAGS="-I$ICU_PREFIX/include"
  ./configure --spidermonkey-version 91 --erlang-md5
  make -j7
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


# SOURCES="$PREFIX/lib \
#     $PREFIX/bin \
#     $PREFIX/etc \
#     $PREFIX/var \
#     $PREFIX/share"
#
# cp -r $SOURCES $BUILDDIR




ICU_VERSION=`ls $ICU_PREFIX/lib/libicuuc.??.?.dylib | grep -o '\d\d\.\d'`
NSPR_VERSION=`ls $PREFIX/Cellar/nspr/`

# copy icu & ssl && nspr libs to safety
cp $ICU_PREFIX/lib/libicuuc.$ICU_VERSION.dylib \
   $ICU_PREFIX/lib/libicudata.$ICU_VERSION.dylib \
   $ICU_PREFIX/lib/libicui18n.$ICU_VERSION.dylib \
   $PREFIX/opt/openssl@1.1/lib/libcrypto.1.1.dylib \
   $PREFIX/opt/nspr/lib/libplds4.dylib \
   $PREFIX/opt/nspr/lib/libplc4.dylib \
   $PREFIX/opt/nspr/lib/libnspr4.dylib \
   $PREFIX/opt/spidermonkey/lib/libmozjs-$SM_VERSION.dylib \
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
	# adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
	# adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so
	# adjust_name_by_tag libicui18n lib/libicui18n.$ICU_VERSION.dylib lib/couch-*/priv/couch_icu_driver.so

	adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so


        # adjust couch_ejson_compare linking
	adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	adjust_name_by_tag libicui18n lib/libicui18n.$ICU_VERSION.dylib lib/couch-*/priv/couch_ejson_compare.so
	break
    ;;
    1)
        echo "adjusting for 1"
	adjust_name $ICU_PREFIX/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so
	adjust_name $ICU_PREFIX/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so
	adjust_name $ICU_PREFIX/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so

        # adjust couch_ejson_compare linking
	adjust_name $ICU_PREFIX/lib/libicudata.$ICUDATA_VERSION.dylib lib/libicudata.$ICUDATA_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
	adjust_name $ICU_PREFIX/lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/libicuuc.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
	adjust_name $ICU_PREFIX/lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/libicui18n.$ICUUCI18N_VERSION.dylib lib/couchdb/erlang/lib/couch-*/priv/lib/couch_ejson_compare.so
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
adjust_name $PREFIX/opt/openssl@1.1/lib/libcrypto.1.1.dylib lib/libcrypto.1.1.dylib lib/crypto-*/priv/lib/crypto.so

# adjust couchjs
adjust_name $PREFIX/opt/spidermonkey$SM_VERSION/lib/libmozjs-$SM_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib bin/couchjs

# adjust libmozjs & deps
adjust_name $PREFIX/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name $PREFIX/opt/nspr/lib/libplc4.dylib lib/libplc4.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name $PREFIX/opt/nspr/lib/libnspr4.dylib lib/libnspr4.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name $PREFIX/opt/spidermonkey$SM_VERSION/lib/libmozjs-$SM_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name_by_tag libicudata lib/libicudata.$ICU_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name_by_tag libicuuc lib/libicuuc.$ICU_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib
adjust_name_by_tag libicui18n lib/libicui18n.$ICU_VERSION.dylib lib/libmozjs-$SM_VERSION.dylib


adjust_name $PREFIX/Cellar/nspr/$NSPR_VERSION/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplds4.dylib
adjust_name $PREFIX/opt/nspr/lib/libplds4.dylib lib/libplds4.dylib lib/libplds4.dylib

adjust_name $PREFIX/Cellar/nspr/$NSPR_VERSION/lib/libnspr4.dylib lib/libnspr4.dylib lib/libplc4.dylib
adjust_name $PREFIX/opt/nspr/lib/libplc4.dylib lib/libplc4.dylib lib/libplc4.dylib

adjust_name $PREFIX/opt/nspr/lib/libnspr4.dylib lib/libnspr4.dylib lib/libnspr4.dylib

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
  lib/couch-*/priv/couchjs \
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
PRUNE_O=`find . -name "*.o"`

rm -rf $TO_PRUNE $PRUNE_O


# build mac app
cd -
git clone git@github.com:janl/couchdb-mac-app.git couchdb-mac-app
cd -
SIGN_BIN=`find . -type f -perm +111 -print`
SIGN_SO=`find . -name "*.so"`
SIGN_DYLIB=`find . -name "*.dylib"`
codesign --verbose --force --deep -o runtime --sign $CODESIGN_IDENTITY \
  --entitlements $ENT_PATH/entitlements.plist \
    $SIGN_BIN $SIGN_SO $SIGN_DYLIB
cd -
cd couchdb-mac-app
  perl -pi.bak -e "s/\<string\>VERSION\<\/string\>/<string>$COUCHDB_VERSION<\/string>/" CouchDB\ Server/Apache\ CouchDB-Info.plist
  open Apache\ CouchDB.xcodeproj
  # xcodebuild clean
  # xcodebuild archive
  cd build/Release
  # zip Apache\ CouchDB.app.zip Apache\ CouchDB.app
  # UPLOAD=`xcrun altool --notarize-app -t osx -f Apache\ CouchDB.app.zip \
  #   --primary-bundle-id org.apache.couchdbx-jan \
  #   -u $APPLE_ID_USER \
  #   -p @keychain:APPLE_ID_PASS \
  #   --output-format xml`
  #
  # echo $UPLOAD

  cd ../..
  # CDBX_BASE_DIR=`pwd`
  # CDBX_BUILD_DIR=$CDBX_BASE_DIR/Builds
  # CDBX_ARCHIVE=$CDBX_BASE_DIR/Apache\ CouchDB.xcarchive
  # CDBX_APP=$CDBX_BUILD_DIR/Apache\ CouchDB.app
  # echo "Building App..."
  # echo "Cleaning up old archive & app..."
  # # rm -rf $FOCUS_ARCHIVE $FOCUS_APP
  # echo "Building archive..."
  # xcodebuild -project $CDBX_BASE_DIR/Apache\ CouchDB.xcodeproj -config Release -scheme Apache\ CouchDB -archivePath "$CDBX_ARCHIVE" archive
  # echo "Exporting archive..."
  # xcodebuild -archivePath "$CDBX_ARCHIVE" -exportArchive -exportPath "$CDBX_APP" -exportFormat app
  # echo "Cleaning up archive..."
  # # rm -rf $FOCUS_ARCHIVE
  echo "Done"
cd ..

cp couchdb-mac-app/build/Release/Apache-*.zip $DESTDIR

cd $DESTDIR
ZIPFILE=`ls Apache-*.zip`
shasum -a 256 Apache-*.zip > $ZIPFILE.sha256
shasum -a 512 Apache-*.zip > $ZIPFILE.sha512

echo "now run gpg --armor --detach-sig $DESTDIR/$ZIPFILE > $DESTDIR/$ZIPFILE.asc"
