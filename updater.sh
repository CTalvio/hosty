#!/bin/sh

set -euf

# Global variables for temporary files
astrokeys=""
hosty=""
signature=""
# astrokeys_gpg is derived from astrokeys, will be astrokeys path + .gpg
astrokeys_gpg=""

# Function to clean up temporary files
cleanup_temp_files() {
  echo "Cleaning up temporary files..."
  rm -f "$astrokeys" \
    "$hosty" \
    "$signature" \
    "$astrokeys_gpg"
}

# Trap EXIT, TERM, INT signals to run cleanup function
trap cleanup_temp_files EXIT TERM INT

# check dependences
checkDep() {
  command -v "$1" >/dev/null 2>&1 || {
    echo >&2 "hosty requires '$1' but it's not installed."
    exit 1
  }
}

checkDep curl
checkDep gpg
checkDep mktemp

# creating tmp files
astrokeys=$(mktemp)
hosty=$(mktemp)
signature=$(mktemp)
astrokeys_gpg="${astrokeys}.gpg" # Define derived filename

# download function for a single file
# Arguments: $1 = destination file, $2 = URL
download_single_file() {
  local dest_file="$1"
  local url="$2"
  echo "Downloading $url to $dest_file..."
  if ! curl -sSL --retry 3 -o "$dest_file" "$url"; then
    echo "Error downloading $url"
    # cleanup_temp_files will be called by trap
    exit 1
  fi
}

# download all necessary files
echo "Downloading PGP keys..."
download_single_file "$astrokeys" https://keybase.io/astrolince/pgp_keys.asc
echo "Downloading hosty script..."
download_single_file "$hosty" https://4st.li/hosty/hosty.sh
echo "Downloading signature..."
download_single_file "$signature" https://4st.li/hosty/hosty.sh.sig

# Verify signature
echo "Verifying hosty script signature..."

# Import the downloaded PGP keys into a temporary GPG keyring.
# --dearmor converts the ASCII armored key to the GPG binary format.
# The output is redirected to /dev/null as we only care about the side effect
# of creating/populating the keyring file specified by $astrokeys_gpg (gpg behavior).
echo "Importing PGP keys..."
if ! gpg --yes --dearmor --output "$astrokeys_gpg" "$astrokeys"; then
  echo "Error dearmoring PGP keys."
  # cleanup_temp_files will be called by trap
  exit 1
fi


# Verify the signature of the hosty script.
# --no-default-keyring: Ensures that only the keys from our specified keyring are used.
# --keyring: Specifies the temporary keyring file to use.
# --verify: Command to verify the signature. Takes signature file and signed data file as args.
echo "Checking signature..."
if ! gpg --no-default-keyring --keyring "$astrokeys_gpg" --verify "$signature" "$hosty" >/dev/null 2>&1; then
  echo "Signature verification FAILED. The hosty script may have been compromised."
  echo "No changes were made to your system."
  # cleanup_temp_files will be called by trap
  exit 1
fi
echo "Signature verified successfully."

# PGP keys and signature file are no longer needed after successful verification.
# The main hosty script ($hosty) is kept until it's sourced.
# astrokeys_gpg (the keyring) is also removed.
# rm "$astrokeys" "$signature" "$astrokeys_gpg"
# This explicit rm is now handled by the trap, but we can leave it for clarity or remove it.
# For robustness with trap, let's remove these specific lines and rely on the trap for $astrokeys, $signature, $astrokeys_gpg.
# $hosty will be cleaned up after sourcing by the trap as well.

# Source the verified hosty script to get its functions and variables.
# shellcheck source=/dev/null
. "$hosty"

# The hosty script has been sourced. Its temporary file can now be removed.
# rm "$hosty"
# This explicit rm is also handled by the trap.

echo "Hosty updater finished."
