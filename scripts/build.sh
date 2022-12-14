#!/bin/bash

# Exit immediately if any commands exit with non-zero exit status.
set -e

while (( "$#" )); do
  case "$1" in
    "-v" | "--version")
      version="$2"
      shift 2 ;;
    *)
      echo "error: Unknown argument: $1"
      exit 1 ;;
  esac
done

# Write version.dart file
function writeVersionDart() {
  file='./lib/version.dart'

  printf "// Auto-generated; DO NOT modify\n" > $file
  printf "const rushVersion = '%s';\n" "$version" >> $file
  printf "const rushBuiltOn = '%s';\n" "$(date '+%Y-%m-%d %H:%M:%S')" >> $file

  echo 'Generated lib/version.dart'
}
writeVersionDart

if [ ! -d "build/bin" ]; then
  mkdir -p "build/bin"
fi

if [ "$OS" = "Windows_NT" ]; then
  # Compile swap.exe (needed only for Windows)
  dart compile exe -o build/bin/swap.exe bin/swap.dart
  ext=".exe"
else
  ext=""
fi

# Compile Rush executable
dart compile exe -o build/bin/rush"$ext" bin/rush.dart
chmod +x build/bin/rush
