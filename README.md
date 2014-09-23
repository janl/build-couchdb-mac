# Introduction

This repo is used to help create the OS X releases of Apache CouchDB. It is
assumed that you have already updated the homebrew repo to match the official
release, and generally have strong Couch-Fu. The developer IRC channel
[irc://freenode.net/#couchdb-dev] or mailing list [mailto:dev@couchdb.apache.org]
are both good places to ask for more information about this if you get stuck.

## Pre-requisites

- OSX Mavericks or probably Yosemite. Mountain Lion may also work.
- Vagrant 1.6.5 and VMWare Fusion 5 or higher installed.
- Patience. The box download is over 9GB, you have been warned.

    # Vagrantfile
    VAGRANTFILE_API_VERSION = "2"
    
    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      config.vm.box = "skunkwerks/osx-lion64-xcodetools"
      config.vm.provider :vmware_fusion do |v|
        v.vmx["memsize"] = "1024"
        v.gui  = true
      end
    end

The vagrant base box is not publically available due to the size, you will
need to ask on IRC to gain access. Alternatively you can build your own
basebox, following https://github.com/timsutton/osx-vm-templates/ and
installing XCode 4.6.3 and commandline tools. These are available from
Apple's developer download site.

## Getting started

When `vagrant up` finishes you should have the option of either a normal ssh
shell or a VMWare gui window into Lion. You can use either from here on.

    vagrant up
    # wait quite a long time
    vagrant ssh

If your version of VMware Fusion is newer than 5 you will likely get better
performance by upgrading the VMware tools on startup.

On your first connection to the VM, you'll need to accept the XCode license:

    sudo xcodebuild -license
    # type 'G' then 'agree'

## Building CouchDB

It's really important that at this point your VM is clean -- any further
cruft or files will likely break the build.

    # upgrade brew
    brew update && brew upgrade
    # grab that couch and erlang goodness
    brew install -v couchdb md5sha1sum
    # grab Jan's repo of happiness
    cd /tmp/
    git clone https://github.com/janl/build-couchdb-mac.git
    cd build-couchdb-mac
    ./build.sh

## Updating this script

The most important things to check in future will be build paths, erlang
stdlib version changes, and extra files. No doubt this list will grow in
future.
