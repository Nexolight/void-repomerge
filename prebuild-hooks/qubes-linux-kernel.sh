#!/bin/bash

KVER=$(grep -Eo 'version=[0-9.]+' "$REPO_FOLDER/srcpkgs/$PACKAGE/template" | cut -f 2 -d '=')

KERNEL=""

if [ "$PACKAGE" == "linux" ]; then
	KERNEL="linux$KVER"
fi
if [ "$PACKAGE" == "linux-headers" ]; then
	KERNEL="linux$KVER-headers"
fi
if [ "$PACKAGE" == "linux-dbg" ]; then
	KERNEL="linux$KVER-dbg"
fi

if [ -z "$KERNEL" ]; then
	echo "could not find package to patch"
	exit
fi

sed 's|# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set|CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y|g' -i "$REPO_FOLDER/srcpkgs/$KERNEL/files/i386-dotconfig"
sed 's|# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set|CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y|g' -i "$REPO_FOLDER/srcpkgs/$KERNEL/files/x86_64-dotconfig"

echo ""
echo ""
echo "----------------------------------------------------------"
echo " Building $KERNEL package referenced by $PACKAGE"
echo "----------------------------------------------------------"
echo ""
echo ""

./xbps-src clean -m "masterdir-$B_ARCH" "$KERNEL"
./xbps-src pkg -m "masterdir-$B_ARCH" -j "$MAX_JOBS" "$KERNEL"
