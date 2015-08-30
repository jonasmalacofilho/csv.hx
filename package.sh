#!/bin/bash

dest=$1

if [ "$dest" == "" ]; then
    dest=./csv.zip
fi

zip -r "$dest" lib test *.{txt,md,json,hxml}

