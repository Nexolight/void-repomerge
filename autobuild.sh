#!/bin/bash

# pkgbuild.list
# <branch> <(rel prebuilt hook | none)> <pkgname>
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

SFILE=`readlink -f $0`
export SDIR=`dirname "$SFILE"`

UPSTREAM_REPO="https://github.com/voidlinux/void-packages.git"
CUSTOM_REPO="https://github.com/Nexolight/void-tainted-pkgs.git"

PRIVATEKEY="$HOME/.ssh/repo/repokey.pem"
SIGNER="'nexolight <snow.dream.ch@gmail.com>'"

export REPO_FOLDER="$HOME/git/void-autobuild/repo"
export ARCH=$(uname -m)

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
./xbps-src binary-bootstrap

while read -r pkg; do
	if [ -z "$pkg" ]; then
		continue
	fi

	export BRANCH=$(echo "$pkg" | cut -f 1 -d ' ')
	PREBUILD_HOOK=$(echo "$pkg" | cut -f 2 -d ' ')
	export PACKAGE=$(echo "$pkg" | cut -f 3 -d ' ')
	
	stage "Building $BRANCH > $PACKAGE"
	git checkout -f "custom/$BRANCH"
	
	export U_VERSION=$( grep -oE 'version=[0-9.]+' "./srcpkgs/$PACKAGE/template" | cut -f 2 -d '=')
	export U_REVISION=$( grep -oE 'revision=[0-9]+' "./srcpkgs/$PACKAGE/template" | cut -f 2 -d '=')	

	stage "Checking file: ./hostdir/binpkgs/$BRANCH/$PACKAGE-${U_VERSION}_${U_REVISION}.$ARCH.xbps"
	if [ ! -f "./hostdir/binpkgs/$BRANCH/$PACKAGE-${U_VERSION}_${U_REVISION}.$ARCH.xbps" ]; then
		stage "$PACKAGE got an update > Rebuilding it"

		git branch -D "$BRANCH"
		git checkout -b "$BRANCH" -f "custom/$BRANCH"
		git pull

		if [ "$PREBUILD_HOOK" != "none" ]; then
			stage "Executing prebuild hook: $PREBUILD_HOOK"
			if [ -f "$SDIR/$PREBUILD_HOOK" ]; then
				"$SDIR/$PREBUILD_HOOK"
			else
				warn "The hook specified for the package doesn't exist"
			fi	
		fi

		./xbps-src clean "$PACKAGE" &> /dev/null
		./xbps-src pkg -j $(nproc) "$PACKAGE"
		xbps-rindex -a -f ./hostdir/binpkgs/$BRANCH/*.xbps
		xbps-rindex --sign --signedby "$SIGNER" --privkey "$PRIVATEKEY" "$REPO_FOLDER/hostdir/binpkgs/$BRANCH/"
		xbps-rindex --sign-pkg --signedby "$SIGNER" --privkey "$PRIVATEKEY" "$REPO_FOLDER"/hostdir/binpkgs/"$BRANCH"/*.xbps
	fi
done < "$SDIR/pkgbuild.list"

rm -f "$SDIR/autobuild.lock"
