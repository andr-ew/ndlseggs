#!/bin/bash

mkdir build
cd ..
zip -r ndlseggs/build/complete-source-code.zip ndlseggs/ -x "ndlseggs/.git/*" "ndlseggs/lib/eggs/lib/doc/*" "ndlseggs/lib/ndls/lib/doc/*" "ndlseggs/build.sh" "ndlseggs/build/*"
