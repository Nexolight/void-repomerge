# void-repomerge
merges, updates and builds custom packages from an own void repo automatically.

Whenever you push something to your custom repository and run this script afterwards
it will build the package. Use a cronjob or something like that. 
You then add the directory where the packages are built as a repository. 

## Limitations:
You may only use this with your own packages.
They must be modified by you on the custom repository

## Config / Variables to pass:

```
UPSTREAM_REPO - The upstream git repository
CUSTOM_REPO - Yout own custom repository
PRIVATEKEY - Your private key location to sign the packages
SIGNER - a.e. someone <someone@mail.com>
REPO_FOLDER - The folder where the git repository is stored
MAX_JOBS - How many threads are used to build
KEEP_DEBUG - Keep the debug packages
```

## Packages `./pkgbuild.list`
This is a list with packages to build:

**Syntax:** `<branch> <(rel prebuilt hook | none)> <pkgname> <arch>`
**Example:** `qubes ./prebuild-hooks/qubes-linux-kernel.sh qubes-vm-meta x86_64`


### branch
The branch of your custom repo where your modifications of a specific package are.

### rel_prebuilt_hook | none
A relative path to a custom prebuild hook you may want to apply before building.
Or set it to "none" to not use any hook.

### pkgname
The name of the package you want to build.
You can use `_LATEST_` which will look for versioned template folders.
The linux Kernel is such a case where the folder is called linux4.14 for example.
this would be `linux_LATEST_` and `linux_LATEST_-headers`. 
If you only build the meta package there it might not build revisions.

## Hooks:
You can modify some things before building packages

### Exported values:
You can use them inside Hooks.

```
SDIR - Directory of this script
REPO_FOLDER - Directory where the git repository resides
BRANCH - branch where the package it is located
PACKAGE - package name
U_VERSION - package version
U_REVISION - package revision
ARCH - The host architecture
B_ARCH - The architecture which is used to build the package
MAX_JOBS - The amount of build jobs
```
