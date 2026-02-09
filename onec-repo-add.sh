#!/bin/sh
# This script adds 1C Enterprise repository to your package manager.
# It automatically detects your distribution and adds the repository with GPG key.

REPO_HOST="edu-ks-beringpro.1cit.com"
REPO_PATH="/onec/8.5.1.1150_x86-64"
REPO_URL="ftp://${REPO_HOST}${REPO_PATH}"
PRODUCT_NAME="1C Enterprise Repository"
LISTNAME="onec-enterprise"

if [ "$(id -u)" -ne 0 ]; then
	echo "This script should be run as root, because it updates "
	echo "your package manager configuration"
	exit 1
fi

if [ ! -f "/etc/os-release" ]; then
	echo "/etc/os-release not found. It is either very old or misconfigured distribution" >&2
	exit 1
fi

. /etc/os-release

case "$ID" in
debian|ubuntu|astra)
	PKGMGR=apt
	ARCH="$(dpkg --print-architecture)"
	repofile="/etc/apt/sources.list.d/${LISTNAME}.list"
	;;
*)
	echo "Unsupported distribution '$NAME'" 1>&2
	exit 1
	;;
esac

if [ -f "$repofile" ]; then
	echo "You have already added repository for $PRODUCT_NAME to your system."
	echo "To upgrade your packages use $PKGMGR install or"
	echo "$PKGMGR upgrade command."
	echo "If you are sure that you want to replace repository configuration,"
	echo "remove ${repofile} and run this script again."
	exit 2
fi

# Extract GPG key from this script
# Key is embedded between BEGIN and END markers
KEY_START="-----BEGIN PGP PUBLIC KEY BLOCK-----"
KEY_END="-----END PGP PUBLIC KEY BLOCK-----"

# Find script location (handle symlinks)
SCRIPT_PATH="$0"
if [ -L "$SCRIPT_PATH" ]; then
	SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH" 2>/dev/null || readlink "$SCRIPT_PATH")
fi

# Extract key from script (from BEGIN to END inclusive)
KEY_CONTENT=$(awk "/^${KEY_START}$/,/^${KEY_END}$/" "$SCRIPT_PATH" 2>/dev/null)

# Check if key was found (use case statement to avoid grep issues with strings starting with dashes)
case "$KEY_CONTENT" in
	*"$KEY_START"*)
		# Key found, continue
		;;
	*)
		echo "Error: GPG key not found in script" >&2
		echo "Please ensure the script contains a valid GPG public key block" >&2
		exit 1
		;;
esac

# Save key to temporary file
keyfile=$(mktemp)
echo "$KEY_CONTENT" > "$keyfile"

# Import GPG key
if [ -d /etc/apt/trusted.gpg.d ]; then
	# Modern Debian/Ubuntu
	gpg --dearmor < "$keyfile" > "/etc/apt/trusted.gpg.d/${LISTNAME}.gpg"
	rm -f "$keyfile"
elif command -v apt-key > /dev/null 2>&1; then
	# Older systems with apt-key
	apt-key add "$keyfile" > /dev/null 2>&1
	rm -f "$keyfile"
else
	echo "Error: Cannot import GPG key. apt-key or /etc/apt/trusted.gpg.d not found" >&2
	rm -f "$keyfile"
	exit 1
fi

# Add repository
echo "# Repository for '$PRODUCT_NAME'" > "$repofile"
echo "deb ${REPO_URL} main contrib non-free non-free-firmware" >> "${repofile}"

echo "Repository added successfully!"
echo "Repository file: ${repofile}"
echo ""
echo "Updating package lists..."
apt-get update || exit 2

echo ""
echo "Repository is ready to use!"
echo "You can now install packages from the repository using:"
echo "  apt install <package-name>"

# GPG key will be inserted here by start-ftp.sh during container initialization
-----BEGIN PGP PUBLIC KEY BLOCK-----
(Key will be inserted here automatically)
-----END PGP PUBLIC KEY BLOCK-----
