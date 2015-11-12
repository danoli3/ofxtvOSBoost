#===============================================================================
# Filename:  build-libc++.sh
# Author:    Pete Goodliffe, Daniel Rosser
# Copyright: (c) Copyright 2009 Pete Goodliffe, 2013-2015 Daniel Rosser
# Licence:   Please feel free to use this, with attribution
# Modified version ## for ofxtvOSBoost
#===============================================================================
#
# Builds a Boost framework for the iPhone.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator. Then creates a pseudo-framework to make using boost in Xcode
# less painful.
#
# To configure the script, define:
#    BOOST_LIBS:        which libraries to build
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh". Grab a cuppa. And voila.
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

prepare()
{

    mkdir -p $LOGDIR
    mkdir -p $OUTPUT_DIR
    mkdir -p $OUTPUT_DIR_SRC
    mkdir -p $OUTPUT_DIR_LIB

}

#===============================================================================

downloadBoost()
{
    if [ ! -s $TARBALLDIR/boost_${BOOST_VERSION2}.tar.bz2 ]; then
        echo "Downloading boost ${BOOST_VERSION}"
        curl -L -o $TARBALLDIR/boost_${BOOST_VERSION2}.tar.bz2 http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION2}.tar.bz2/download
    fi

    doneSection
}

#===============================================================================

unpackBoost()
{
    [ -f "$BOOST_TARBALL" ] || abort "Source tarball missing."

    echo Unpacking boost into $SRCDIR...

    [ -d $SRCDIR ]    || mkdir -p $SRCDIR
    [ -d $BOOST_SRC ] || ( cd $SRCDIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo "    ...unpacked as $BOOST_SRC"

    doneSection
}

#===============================================================================

restoreBoost()
{
    cp $BOOST_SRC/tools/build/example/user-config.jam-bk $BOOST_SRC/tools/build/example/user-config.jam
}

#===============================================================================

updateBoost()
{
    echo Updating boost into $BOOST_SRC...
    local CROSS_TOP_IOS="${DEVELOPER}/Platforms/AppleTVOS.platform/Developer"
    local CROSS_SDK_IOS="AppleTVOS${SDKVERSION}.sdk"
    local CROSS_TOP_SIM="${DEVELOPER}/Platforms/AppleTVSimulator.platform/Developer"
    local CROSS_SDK_SIM="AppleTVSimulator${SDKVERSION}.sdk"
    local BUILD_TOOLS="${DEVELOPER}"

    cp $BOOST_SRC/tools/build/example/user-config.jam $BOOST_SRC/tools/build/example/user-config.jam.bk

    cat >> $BOOST_SRC/tools/build/example/user-config.jam <<EOF
using darwin : ${APPLETVOS_SDKVERSION}~appletv
: $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch arm64 $EXTRA_CPPFLAGS "-isysroot ${CROSS_TOP_IOS}/SDKs/${CROSS_SDK_IOS}" -I${CROSS_TOP_IOS}/SDKs/${CROSS_SDK_IOS}/usr/include/
: <striper> <root>$XCODE_ROOT/Platforms/AppleTVOS.platform/Developer
: <architecture>arm <target-os>iphone
;
using darwin : ${APPLETVOS_SDKVERSION}~appletvsim
: $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch x86_64 $EXTRA_CPPFLAGS "-isysroot ${CROSS_TOP_SIM}/SDKs/${CROSS_SDK_SIM}" -I${CROSS_TOP_SIM}/SDKs/${CROSS_SDK_SIM}/usr/include/
: <striper> <root>$XCODE_ROOT/Platforms/AppleTVSimulator.platform/Developer
: <architecture>x86 <target-os>iphone
;
EOF

    doneSection
}

#===============================================================================

inventMissingHeaders()
{
    # These files are missing in the ARM iPhoneOS SDK, but they are in the simulator.
    # They are supported on the device, so we copy them from x86 SDK to a staging area
    # to use them on ARM, too.
    echo Invent missing headers

    cp $XCODE_ROOT/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator${APPLETVOS_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BOOST_SRC
}

#===============================================================================

bootstrapBoost()
{
    cd $BOOST_SRC

    BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
    echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
    ./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA

    doneSection
}

#===============================================================================

buildBoostFortvOS()
{
    cd $BOOST_SRC

    # Install this one so we can copy the includes for the frameworks...

    
    set +e    
    echo "------------------"
    LOG="$LOGDIR/build-appletv-stage.log"
    echo "Running bjam for appletv-build stage"
    echo "To see status in realtime check:"
    echo " ${LOG}"
    echo "Please stand by..."
    MIN_TVOS_VERSION=TVOS_MIN_VERSION
    MIN_TYPE_TVOS=-mtvos-version-min=
    MIN_TYPE_TVOS_SIM=-mtvos-simulator-version-min=
    ./bjam -j${PARALLEL_MAKE} --build-dir=appletv-build -sBOOST_BUILD_USER_CONFIG=$BOOST_SRC/tools/build/example/user-config.jam --stagedir=appletv-build/stage --prefix=$PREFIXDIR --toolset=darwin-${APPLETVOS_SDKVERSION}~appletv cxxflags="$MIN_TYPE_TVOS$TVOS_MIN_VERSION -stdlib=$STDLIB $BITCODE" variant=release linkflags="-stdlib=$STDLIB" architecture=arm target-os=iphone define=_LITTLE_ENDIAN link=static stage > "${LOG}" 2>&1
    if [ $? != 0 ]; then 
        tail -n 100 "${LOG}"
        echo "Problem while Building appletv-build stage - Please check ${LOG}"
        exit 1
    else 
        echo "appletv-build stage successful"
    fi

    echo "------------------"
    LOG="$LOGDIR/build-appletv-install.log"
    echo "Running bjam for appletv-build install"
    echo "To see status in realtime check:"
    echo " ${LOG}"
    echo "Please stand by..."
    ./bjam -j${PARALLEL_MAKE} --build-dir=appletv-build -sBOOST_BUILD_USER_CONFIG=$BOOST_SRC/tools/build/example/user-config.jam --stagedir=appletv-build/stage --prefix=$PREFIXDIR --toolset=darwin-${APPLETVOS_SDKVERSION}~appletv cxxflags="$MIN_TYPE_TVOS$TVOS_MIN_VERSION -stdlib=$STDLIB $BITCODE" variant=release linkflags="-stdlib=$STDLIB" architecture=arm target-os=iphone define=_LITTLE_ENDIAN link=static install > "${LOG}" 2>&1
    if [ $? != 0 ]; then 
        tail -n 100 "${LOG}"
        echo "Problem while Building appletv-build install - Please check ${LOG}"
        exit 1
    else 
        echo "appletv-build install successful"
    fi
    doneSection

    echo "------------------"
    LOG="$LOGDIR/build-appletv-simulator-build.log"
    echo "Running bjam for appletv-sim-build "
    echo "To see status in realtime check:"
    echo " ${LOG}"
    echo "Please stand by..."
    ./bjam -j${PARALLEL_MAKE} --build-dir=appletvsim-build -sBOOST_BUILD_USER_CONFIG=$BOOST_SRC/tools/build/example/user-config.jam --stagedir=appletvsim-build/stage --toolset=darwin-${APPLETVOS_SDKVERSION}~appletvsim architecture=x86 target-os=iphone variant=release cxxflags="$MIN_TYPE_TVOS_SIM$TVOS_MIN_VERSION -stdlib=$STDLIB $BITCODE" link=static stage > "${LOG}" 2>&1
    if [ $? != 0 ]; then 
        tail -n 100 "${LOG}"
        echo "Problem while Building appletv-simulator build - Please check ${LOG}"
        exit 1
    else 
        echo "appletv-simulator build successful"
    fi

    doneSection
}

#===============================================================================

scrunchAllLibsTogetherInOneLibPerPlatform()
{
    cd $BOOST_SRC

	mkdir -p $TVOSBUILDDIR/arm64/obj
	mkdir -p $TVOSBUILDDIR/x86_64/obj

    ALL_LIBS=""

    echo Splitting all existing fat binaries...

    for NAME in $BOOST_LIBS; do
        ALL_LIBS="$ALL_LIBS libboost_$NAME.a"

        $ARM_DEV_CMD lipo "appletv-build/stage/lib/libboost_$NAME.a" -thin arm64 -o $TVOSBUILDDIR/arm64/libboost_$NAME.a
        $ARM_DEV_CMD lipo "appletvsim-build/stage/lib/libboost_$NAME.a" -thin x86_64 -o $TVOSBUILDDIR/x86_64/libboost_$NAME.a
  
    done

    echo "Decomposing each architecture's .a files"

    for NAME in $ALL_LIBS; do
        echo Decomposing $NAME...
		(cd $TVOSBUILDDIR/arm64/obj; ar -x ../$NAME );
		(cd $TVOSBUILDDIR/x86_64/obj; ar -x ../$NAME );
    done

    echo "Linking each architecture into an uberlib ($ALL_LIBS => libboost.a )"

    rm $TVOSBUILDDIR/*/libboost.a
    
    echo ...arm64
    (cd $TVOSBUILDDIR/arm64; $ARM_DEV_CMD ar crus libboost.a obj/*.o; )
    echo ...x86_64
    (cd $TVOSBUILDDIR/x86_64;  $SIM_DEV_CMD ar crus libboost.a obj/*.o; )

    echo "Making fat lib for tvOS Boost $BOOST_VERSION"
    lipo -c $TVOSBUILDDIR/arm64/libboost.a \
            $TVOSBUILDDIR/x86_64/libboost.a \
            -output $OUTPUT_DIR_LIB/libboost.a

    echo "Completed Fat Lib"
    echo "------------------"

}

#===============================================================================
buildIncludes()
{
    
    mkdir -p $TVOSINCLUDEDIR
    echo "------------------"
    echo "Copying Includes to Final Dir $OUTPUT_DIR_SRC"
    LOG="$LOGDIR/buildIncludes.log"
    set +e

    cp -r $PREFIXDIR/include/boost/*  $OUTPUT_DIR_SRC/ > "${LOG}" 2>&1
    if [ $? != 0 ]; then 
        tail -n 100 "${LOG}"
        echo "Problem while copying includes - Please check ${LOG}"
        exit 1
    else 
        echo "Copy of Includes successful"
    fi
    echo "------------------"

    doneSection
}

#===============================================================================
# Execution starts here
#===============================================================================

mkdir -p $TVOSBUILDDIR

cleanEverythingReadyToStart #may want to comment if repeatedly running during dev
restoreBoost

echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "BOOST_SRC:         $BOOST_SRC"
echo "TVOSBUILDDIR:       $TVOSBUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "OSXFRAMEWORKDIR:   $OSXFRAMEWORKDIR"
echo "APPLETVOS_SDKVERSION: $APPLETVOS_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo "COMPILER:          $COMPILER"
echo

downloadBoost
unpackBoost
inventMissingHeaders
prepare
bootstrapBoost
updateBoost
buildBoostFortvOS
scrunchAllLibsTogetherInOneLibPerPlatform
buildIncludes

restoreBoost

postcleanEverything

echo "Completed successfully"

#===============================================================================
