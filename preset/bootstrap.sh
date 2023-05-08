#!/bin/sh

curl --location --request PUT 'http://localhost:7557/presets/oneisp-bootstrap' \
--header 'Content-Type: application/json' \
--data-raw '{
    "weight": 0,
    "channel": "bootstrap",
    "events": {
        "0 BOOTSTRAP": true
    },
    "precondition": "",
    "configurations": [
        {
            "type": "provision",
            "name": "oneisp-bootstrap",
            "args": null
        }
    ]
}'