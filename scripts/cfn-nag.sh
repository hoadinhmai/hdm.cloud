#!/bin/bash

for TEMPLATE in $(find . -name 'cfn-*.yaml'); do
    if cfn_nag_scan --input-path $TEMPLATE; then
        echo "$TEMPLATE PASSED"
    else
        echo "$TEMPLATE FAILED"
    fi
done