#!/bin/bash

# Limitations:
#	You may only use this with your own packages.
#	They must be modified by you on the custom repository
#
#
# Variables to pass:
#	UPSTREAM_REPO - The upstream git repository
#	CUSTOM_REPO - Yout own custom repository
#	PRIVATEKEY - Your private key location to sign the packages
#	SIGNER - a.e. 'someone <someone@mail.com>'
#	REPO_FOLDER - The folder where the git repository is stored
#	MAX_JOBS - How many threads are used to build
#
# pkgbuild.list
# <branch> <(rel prebuilt hook | none)> <pkgname> <arch>
#
# Hooks:
# 	exported values:
#		SDIR - Directory of this script
#		REPO_FOLDER - Directory where the git repository resides
# 		BRANCH - branch where the package it is located
#		PACKAGE - package name
#		U_VERSION - package version
#		U_REVISION - package revision
#		ARCH - The host architecture
#		B_ARCH - The architecture which is used to build the package

SFILE=`readlink -f $0`
export SDIR=`dirname "$SFILE"`

if [ -z "$UPSTREAM_REPO" ];then
	UPSTREAM_REPO="https://github.com/voidlinux/void-packages.git"
fi

if [ -z "$CUSTOM_REPO" ];then
	CUSTOM_REPO="https://github.com/Nexolight/void-tainted-pkgs.git"
fi

if [ -z "$PRIVATEKEY" ];then
	PRIVATEKEY="$HOME/.ssh/repo/repokey.pem"
fi

if [ -z "$SIGNER" ];then
	SIGNER="'nexolight <snow.dream.ch@gmail.com>'"
fi

if [ -z "$REPO_FOLDER" ];then
	export REPO_FOLDER="$HOME/git/void-autobuild/repo"
fi

if [ -z "$MAX_JOBS" ];then
	MAX_JOBS=$(nproc)
fi

export ARCH=$(uname -m)

function info(){
echo ">>>> INFO | $1"
}

function stage(){
echo ">>>> STAGE | $1"
}

function warn(){
echo ">>>> WARN  | $1"
}

if [ -f "$SDIR/autobuild.lock" ]; then
	warn "autobuild is already running"
	exit
fi

echo $$ > "$SDIR/autobuild.lock"

mkdir -p "$REPO_FOLDER"
cd "$REPO_FOLDER"

if [ ! -d "$REPO_FOLDER/.git" ]; then
	stage "Cloning repository"
	git clone "$UPSTREAM_REPO" "$REPO_FOLDER"
	git remote add custom "$CUSTOM_REPO"
fi

stage "Updating repository"
git fetch --all
git checkout origin/master

ARCHS=""
NL=$'\n'
while read -r pkg; do
	B_ARCH=$(echo "$pkg" | cut -f 4 -d ' ')
	if [ ! -z "$B_ARCH" ]; then
		ARCHS="${ARCHS}${B_ARCH}${NL}"
	fi
done < "$SDIR/pkgbuild.list"


ARCHS=$(echo "$ARCHS" | sort -u)

for HDIR in $ARCHS; do
	if [ "$ARCH" == "x86_64" ] && [ "$HDIR" == "i686" ] ; then
		./xbps-src -m "masterdir-x86_64" binary-bootstrap
		./xbps-src -m "masterdir-i686" binary-bootstrap i686
	else
		./xbps-src -m "masterdir-$HDIR" binary-bootstrap
	fi
done

while read -r pkg; do
	if [ -z "$pkg" ]; then
		continue
	fi

	export BRANCH=$(echo "$pkg" | cut -f 1 -d ' ')
	PREBUILD_HOOK=$(echo "$pkg" | cut -f 2 -d ' ')
	export PACKAGE=$(echo "$pkg" | cut -f 3 -d ' ')
	export B_ARCH="$(echo "$pkg" | cut -f 4 -d ' ')"
	
	stage "Building $BRANCH > $PACKAGE"
	git checkout -f "custom/$BRANCH"
	
	export U_VERSION=$( grep -oE 'version=[0-9.]+' "./srcpkgs/$PACKAGE/template" | cut -f 2 -d '=')
	export U_REVISION=$( grep -oE 'revision=[0-9]+' "./srcpkgs/$PACKAGE/template" | cut -f 2 -d '=')	

	BASEPKG_PATH="./hostdir/binpkgs/$BRANCH"
	PKG_LIB=""
	PKG_ARCH=""
	PKG_SUBDIR=""
	PKG_EXTRA_SUBDIR=""

	case "$B_ARCH" in
		*)
			PKG_ARCH="$B_ARCH"
			PKG_EXTRA_SUBDIR="nonfree"
		;;
	esac

	PKG_FILES="
		$BASEPKG_PATH/$PKG_SUBDIR/${PACKAGE}${PKG_LIB}-${U_VERSION}_${U_REVISION}.${PKG_ARCH}.xbps
		$BASEPKG_PATH/$PKG_SUBDIR/${PACKAGE}${PKG_LIB}-${U_VERSION}_${U_REVISION}.noarch.xbps
		$BASEPKG_PATH/$PKG_SUBDIR/${PKG_EXTRA_SUBDIR}/${PACKAGE}${PKG_LIB}-${U_VERSION}_${U_REVISION}.${PKG_ARCH}.xbps
                $BASEPKG_PATH/$PKG_SUBDIR/${PKG_EXTRA_SUBDIR}/${PACKAGE}${PKG_LIB}-${U_VERSION}_${U_REVISION}.noarch.xbps
		"
	
	NEEDS_BUILD=1
	for PKG_FILE in $PKG_FILES; do
		info "Checking for file: $PKG_FILE"
		if [ -f "$PKG_FILE" ]; then
			info "Found: $PKG_FILE"
			NEEDS_BUILD=0
			break
		fi
	done

	IS_CC=1
	if [ "$B_ARCH" == "i686" ] && [ "$ARCH" == "x86_64" ]; then
		IS_CC=0
	fi
	if [ "$ARCH" == "$B_ARCH" ] || [ "$ARCH-musl" == "$B_ARCH" ]; then
		IS_CC=0
	fi 
	
	if [ "$NEEDS_BUILD" == 1 ]; then
		stage "$PACKAGE got an update > Rebuilding it"

		git branch -D "$BRANCH"
		git checkout -b "$BRANCH" -f custom/"$BRANCH"
		git merge -X ours --no-commit --no-ff origin/master		

		if [ "$PREBUILD_HOOK" != "none" ]; then
			stage "Executing prebuild hook: $PREBUILD_HOOK"
			if [ -f "$SDIR/$PREBUILD_HOOK" ]; then
				"$SDIR/$PREBUILD_HOOK"
			else
				warn "The hook specified for the package doesn't exist"
			fi	
		fi
		

		CC_ARCH=""
		if [ "$IS_CC" == 1 ]; then
			CC_ARCH="-a $B_ARCH"
		fi 

		./xbps-src -m "masterdir-$B_ARCH" "$CC_ARCH" clean "$PACKAGE"
		./xbps-src -m "masterdir-$B_ARCH" -j $MAX_JOBS "$CC_ARCH" pkg "$PACKAGE" 
		
		SIGNDIRS="$BRANCH $BRANCH/nonfree $BRANCH/multilib $BRANCH/multilib/nonfree"
		
		for SIGNDIR in $SIGNDIRS; do
			BINDIR="./hostdir/binpkgs/$SIGNDIR"
			xbps-rindex -a -f "$BINDIR"/*.xbps
			xbps-rindex --sign --signedby "$SIGNER" --privkey "$PRIVATEKEY" "$BINDIR"
			xbps-rindex --sign-pkg --signedby "$SIGNER" --privkey "$PRIVATEKEY" "$BINDIR"/*.xbps
		done
	fi
done < "$SDIR/pkgbuild.list"

rm -f "$SDIR/autobuild.lock"
