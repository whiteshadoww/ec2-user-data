#!/bin/sh

curl --location --request PUT 'http://localhost:7557/presets/oneisp-registered' \
--header 'Content-Type: application/json' \
--data-raw '{
    "weight": 0,
    "channel": "registered",
    "events": {
        "Registered": true
    },
    "precondition": "",
    "configurations": [
        {
            "type": "provision",
            "name": "oneisp-registered",
            "args": null
        }
    ]
}'