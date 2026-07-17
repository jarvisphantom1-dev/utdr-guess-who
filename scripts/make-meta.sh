#!/bin/bash

# Constants
CHARSET_META_FILENAME=charset-meta.json
CHAR_META_FILENAME=char-meta.json
CONFIG_FILENAME=config.json

# Get the directory for all character sets
ROOT_DIR=$(dirname -- $(readlink -f $BASH_SOURCE))/..

# If doing a Tauri build, we need to correct for a bug where Tauri doesn't support file/dir names with spaces in them,
# so we copy everything into a build directory and rename the files and directories there so there are no spaces
if [ ! -z $TAURI ]; then

  cd $ROOT_DIR
  rm -rf build
  mkdir build
  cp -r public build/

  CHARSET_DIR=$ROOT_DIR/build/public/character-sets
  cd $CHARSET_DIR

  # Rename all files and directories recursively, replacing spaces with _
  find . -depth -name "* *" | while read FILE; do
    NEWFILE=$(echo -n "$FILE" | sed -e 's/ /_/g')

    if [[ "$FILE" != "$NEWFILE" ]]; then
      mv "$FILE" "$NEWFILE"
    fi
  done

else # Non-Tauri build

  CHARSET_DIR=$ROOT_DIR/public/character-sets
  cd $CHARSET_DIR

fi

# Start creating the character set meta file
echo -n '{"sets":[' > $CHARSET_META_FILENAME

# Loop over character set folders. For each, add its entry to the character set meta file and make its character meta
# file
FIRST_DIR=true
for DIRNAME in *; do

  # Skip any files in this directory
  if [[ -f $DIRNAME ]]; then
    continue
  fi

  # For entries after the first, we add a comma to separate from the previous entry
  if [ $FIRST_DIR != true ]; then
    echo -n ',' >> $CHARSET_META_FILENAME
  else
    FIRST_DIR=false
  fi

  echo -n '"'$DIRNAME'"' >> $CHARSET_META_FILENAME

  # Create a character meta file for this folder
  cd "$DIRNAME"
  echo -n '{"chars":[' > $CHAR_META_FILENAME

  FIRST_FILE=true

  # Loop over all character entries
  for ENTRY in *; do

    # Skip config files
    if [[ "$ENTRY" == "$CONFIG_FILENAME" ]]; then
      continue
    fi

    # Skip generated metadata
    if [[ "$ENTRY" == "$CHAR_META_FILENAME" ]]; then
      continue
    fi

    # For entries after the first, we add a comma to separate from the previous entry
    if [ $FIRST_FILE != true ]; then
      echo -n ',' >> $CHAR_META_FILENAME
    else
      FIRST_FILE=false
    fi


    # Handle direct PNG characters
    if [[ -f "$ENTRY" && "$ENTRY" == *.png ]]; then

      NAME=$(echo "$ENTRY" | sed 's/.png$//' | sed 's/^[0-9]*-//')

      echo -n '{"fullname": "'$ENTRY'", "name":"'$NAME'","image":"'$ENTRY'","config":null}' >> $CHAR_META_FILENAME


    # Handle folder based characters
    elif [[ -d "$ENTRY" ]]; then

      IMAGE_FILE=""

      # Find the first png inside the character folder
      for IMAGE in "$ENTRY"/*.png; do
        if [[ -f "$IMAGE" ]]; then
          IMAGE_FILE=$(basename "$IMAGE")
          break
        fi
      done


      # Only add the character if an image exists
      if [[ ! -z "$IMAGE_FILE" ]]; then

        NAME=$(echo "$ENTRY" | sed 's/^[0-9]*-//')

        CONFIG_PATH="null"

        if [[ -f "$ENTRY/config.json" ]]; then
          CONFIG_PATH='"'$ENTRY'/config.json"'
        fi

        echo -n '{"fullname": "'$ENTRY'","name":"'$NAME'","image":"'$ENTRY'/'$IMAGE_FILE'","config":'$CONFIG_PATH'}' >> $CHAR_META_FILENAME

      fi

    fi

  done

  # Finish off the character list
  echo -n ']' >> $CHAR_META_FILENAME


  # Check if a config file is present for this character set, and include the config if so
  if [[ -f $CONFIG_FILENAME ]]; then
    echo -n ',"config":' >> $CHAR_META_FILENAME
    cat $CONFIG_FILENAME >> $CHAR_META_FILENAME
  else
    echo -n ',"config":null' >> $CHAR_META_FILENAME
  fi


  # Finish off the file
  echo -n '}' >> $CHAR_META_FILENAME

  cd ..

done

# Finish off the character set meta file
echo -n ']}' >> $CHARSET_META_FILENAME