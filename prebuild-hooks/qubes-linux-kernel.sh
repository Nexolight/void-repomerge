#!/bin/bash

sed 's|# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set|CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y|g' -i "$REPO_FOLDER/srcpkgs/$PACKAGE/files/i386-dotconfig"
sed 's|# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set|CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y|g' -i "$REPO_FOLDER/srcpkgs/$PACKAGE/files/x86_64-dotconfig"

echo ""
echo "----------------------------------------------------------"
echo " Modified $PACKAGE before build"
echo "----------------------------------------------------------"
echo ""
