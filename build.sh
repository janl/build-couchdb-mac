#!/bin/sh -ex

# cleanup
# Run build-couchdb to do a fully automated build of the recent CouchDB 

if [ ! -d build-couchdb ]; then
  git clone git://github.com/cloudnode/build-couchdb
fi
cd build-couchdb
  git submodule init
  git submodule update
  rake git="https://git-wip-us.apache.org/repos/asf/couchdb.git tags/1.2.1" install="/Users/jan/build"
cd ..

if [ ! -d couchdbx-app ]; then
  git clone git://github.com/janl/couchdb-mac-app.git couchdb-mac-app
fi

cd couchdb-mac-app
  xcodebuild
cd ..

cp couchdb-mac-app/build/Release/Apache-CouchDB-*.zip* .

echo "All Done"
