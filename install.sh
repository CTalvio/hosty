#!/bin/sh

set -euf

# check dependences
checkDep() {
  command -v "$1" >/dev/null 2>&1 || {
    echo >&2 "hosty requires '$1' but it's not installed."
    exit 1
  }
}

checkDep curl

# Function to execute commands with or without sudo based on REQUEST_SUDO
# Takes the command and its arguments as parameters
execute_with_privileges() {
  if [ "$REQUEST_SUDO" = 1 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

echo "======== welcome to hosty installer ========"
echo "========        4st.li/hosty        ========"
echo
echo "checking if user has root access..."

if [ "$(id -u)" != 0 ]; then
  echo
  if ! prompt=$(sudo -nv 2>&1); then
    if ! echo "$prompt" | grep -q '^sudo:'; then
      echo "you don't have sudo access, please fix that or run from root."
      exit 1
    fi

    echo "requesting sudo..."
  else
    echo "using already granted sudo access..."
  fi

  REQUEST_SUDO=1
else
  REQUEST_SUDO=0
  echo "OK"
fi

echo
if [ -f /usr/local/bin/hosty ]; then
  echo "Removing existing hosty..."
  execute_with_privileges rm /usr/local/bin/hosty
  echo
fi

echo "Installing hosty..."
execute_with_privileges curl -L --retry 3 -o /usr/local/bin/hosty https://4st.li/hosty/hosty.sh
echo

echo "Fixing permissions..."
execute_with_privileges chmod 755 /usr/local/bin/hosty
echo

if command -v "crontab" >/dev/null 2>&1; then
  echo "Do you want to automatically update your hosts file with the latest ads list? (recommended) y/n"
  read -r answer </dev/tty
  echo

  if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ] || [ "$answer" = "YES" ]; then
    # shellcheck disable=SC2024
    execute_with_privileges /usr/local/bin/hosty -a </dev/tty
    exit 0
  elif [ "$answer" != "n" ] && [ "$answer" != "N" ] && [ "$answer" != "no" ] && [ "$answer" != "NO" ]; then
    echo "Bad answer, exiting..."
    exit 1
  fi
fi

echo "done."
