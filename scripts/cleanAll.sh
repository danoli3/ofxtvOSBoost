#===============================================================================
# Filename:  cleanAll.sh
# Author:    Pete Goodliffe, Daniel Rosser
# Copyright: (c) Copyright 2009 Pete Goodliffe, 2013 Daniel Rosser
# Licence:   Please feel free to use this, with attribution
# Modified version ## for ofxtvOSBoost
#===============================================================================
#
# Cleans the Build Boost framework environment for the iPhone.
#===============================================================================

#!/bin/sh
here="`dirname \"$0\"`"
echo "cd-ing to $here"
cd "$here" || exit 1

CPPSTD=c++11    #c++89, c++99, c++14
STDLIB=libc++   # libstdc++
COMPILER=clang++
PARALLEL_MAKE=16   # how many threads to make boost with

BOOST_V1=1.59.0
BOOST_V2=1_59_0

BITCODE="-fembed-bitcode" 

CURRENTPATH=`pwd`
LOGDIR="$CURRENTPATH/build/logs/"
TVOS_MIN_VERSION=9.0
SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
OSX_SDKVERSION=`xcrun -sdk macosx --show-sdk-version`
DEVELOPER=`xcode-select -print-path`
XCODE_ROOT=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case $DEVELOPER in  
     *\ * )
           echo "Your Xcode path contains whitespaces, which is not supported."
           exit 1
          ;;
esac

case $CURRENTPATH in  
     *\ * )
           echo "Your path contains whitespaces, which is not supported by 'make install'."
           exit 1
          ;;
esac

: ${BOOST_LIBS:="random regex graph random chrono thread signals filesystem system date_time"}
: ${APPLETVOS_SDKVERSION:=`xcrun -sdk appletvos --show-sdk-version`}
: ${EXTRA_CPPFLAGS:="-fPIC -DBOOST_SP_USE_SPINLOCK -std=$CPPSTD -stdlib=$STDLIB -mtvos-version-min=$TVOS_MIN_VERSION $BITCODE -fvisibility=hidden -fvisibility-inlines-hidden"}

: ${TARBALLDIR:=`pwd`/..}
: ${SRCDIR:=`pwd`/../build/src}
: ${TVOSBUILDDIR:=`pwd`/../build/libs/boost/lib}
: ${TVOSINCLUDEDIR:=`pwd`/../build/libs/boost/include/boost}
: ${PREFIXDIR:=`pwd`/../build/tvos/prefix}
: ${COMPILER:="clang++"}
: ${OUTPUT_DIR:=`pwd`/../libs/boost/}
: ${OUTPUT_DIR_LIB:=`pwd`/../libs/boost/tvos/}
: ${OUTPUT_DIR_SRC:=`pwd`/../libs/boost/include/boost}

: ${BOOST_VERSION:=$BOOST_V1}
: ${BOOST_VERSION2:=$BOOST_V2}

BOOST_TARBALL=$TARBALLDIR/boost_$BOOST_VERSION2.tar.bz2
BOOST_SRC=$SRCDIR/boost_${BOOST_VERSION2}
BOOST_INCLUDE=$BOOST_SRC/boost



#===============================================================================
ARM_DEV_CMD="xcrun --sdk appletvos"
SIM_DEV_CMD="xcrun --sdk appletvsimulator"
OSX_DEV_CMD="xcrun --sdk macosx"

#===============================================================================


#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "================================================================="
    echo "Done"
    echo
}

#===============================================================================


cleanEverythingReadyToStart()
{
    echo Cleaning everything before we start to build...

    rm -rf appletv-build appletvsim-build
    rm -rf $TVOSBUILDDIR
    rm -rf $PREFIXDIR
    rm -rf $TVOSINCLUDEDIR
    rm -rf $TARBALLDIR/build
    rm -rf $LOGDIR

    doneSection
}

postcleanEverything()
{
  echo Cleaning everything after the build...

  rm -rf appletv-build appletvsim-build
  rm -rf $PREFIXDIR
  rm -rf $TVOSBUILDDIR/arm64/obj
  rm -rf $TVOSBUILDDIR/x86_64/obj
    rm -rf $TARBALLDIR/build
    rm -rf $LOGDIR
  doneSection
}


cleanBuild() {
    rm -rf `pwd`/../build/
}


cleanEverythingReadyToStart #may want to comment if repeatedly running during dev
postcleanEverything
cleanBuild

echo "Completed Clean successfully"

#===============================================================================
