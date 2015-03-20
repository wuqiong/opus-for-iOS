#!/bin/sh
echo "*********************************************"
echo "*********************************************"
echo "***********                       ***********"
echo "***********      戴维营教育专用   ***********"
echo "***********           反馈        ***********"
echo "***********         大茶园丁      ***********"
echo "*********************************************"
echo "*********************************************"


OPUS_GIT_URL=git://git.opus-codec.org/opus.git
OPUS_DIR=.opus

#rm -rf $OPUS_DIR;

#check homebrew
brew -v > /dev/null 2>&1;
if [ $? != 0 ];then
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)";
fi

#fix me? will fail.
brew unlink autoconf automake libtool shtool
brew reinstall autoconf automake libtool shtool > /dev/null 3>&1 ;

if ! [ -d $OPUS_DIR ];then
	echo "downloading $OPUS_GIT_URL ..."
	git clone $OPUS_GIT_URL  $OPUS_DIR
	if [ $? != 0 ];then
		echo "downloading $OPUS_GIT_URL error ...";
		exit -1;
	else
		echo "downloading $OPUS_GIT_URL done ...";
		cd $OPUS_DIR;
		autoupdate ./configure.ac > /dev/null 2>&1;
		./autogen.sh;
		cd -;
	fi
else
	pushd $OPUS_DIR && git pull;
	autoupdate ./configure.ac > /dev/null 2>&1;
	popd;
fi



CONFIGURE_FLAGS="--disable-shared --disable-doc --disable-extra-programs --enable-intrinsics --enable-fuzzing --enable-custom-modes --disable-rtcd --enable-asm"

ARCHS="x86_64 i386 armv7 armv7s arm64"

# directories
SOURCE=$OPUS_DIR
FAT=".fat-opus"

SCRATCH=".scratch-opus"
# must be an absolute path
THIN=`pwd`/".thin-opus"

COMPILE="y"
LIPO="y"
FRAMEWORK="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=7.0"
                        HOST=x86_64-apple-darwin
		    else
		    	SIMULATOR="-mios-simulator-version-min=5.0"
                        HOST=i386-apple-darwin
		    fi
		else
		    PLATFORM="iPhoneOS"
		    SIMULATOR=
                    HOST=arm-apple-darwin
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
		#AS=""
		CFLAGS="-arch $ARCH $SIMULATOR -D__OPTIMIZE__"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
                    --host=$HOST \
		    --prefix="$THIN/$ARCH" \
                    CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" 

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

if [ "$FRAMEWORK" ]
then
	rm -rf opus.framework
	echo "building opus.framework..."
	mkdir -p opus.framework/Headers/
	cp -rf $FAT/include/opus/* opus.framework/Headers/
	cp -f $FAT/lib/libopus.a opus.framework/opus
fi

#   clean tmp directories
rm -rf $FAT $SCRATCH $THIN
