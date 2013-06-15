#!/bin/sh -ex

# cleanup
# Run build-couchdb to do a fully automated build of the recent CouchDB 

COUCHDB_VERSION=86d756a101eff823a231a78e577b8b0780830123

if [ ! -d build-couchdb ]; then
  git clone git://github.com/iriscouch/build-couchdb
fi
cd build-couchdb
  git submodule init
  git submodule update
  rake git="https://git-wip-us.apache.org/repos/asf/couchdb.git $COUCHDB_VERSION" install="/Users/jan/build"
cd ..

if [ ! -d couchdb-mac-app ]; then
  git clone git://github.com/janl/couchdb-mac-app.git couchdb-mac-app
fi

cd couchdb-mac-app
  xcodebuild
cd ..

cp couchdb-mac-app/build/Release/Apache-CouchDB-*.zip* .

echo "All Done"
