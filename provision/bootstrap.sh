#!/bin/sh

curl --location --request PUT 'http://localhost:7557/provisions/oneisp-bootstrap' \
  --data-raw 'const now = Date.now();
declare("InternetGatewayDevice.ManagementServer.ConnectionRequestUsername", { value: now }, { value: "'"$ConnectionRequestUsername"'" });
declare("InternetGatewayDevice.ManagementServer.ConnectionRequestPassword", { value: now }, { value: "'"$ConnectionRequestPassword"'" })

let model = declare("InternetGatewayDevice.DeviceInfo.ModelName", {value: 1}).value[0];
let serialNumber = declare("DeviceID.SerialNumber", {value: 1}).value[0];
let productClass = declare("DeviceID.ProductClass", {value: 1}).value[0];
let oui = declare("DeviceID.OUI", {value: 1}).value[0];
let args = {SerialNumber: serialNumber, ProductClass: productClass, OUI: oui};

log("Getting device config")

//Get the PPPoE creds
let config = ext('cpe-config', 'resetPppoe', JSON.stringify(args));
if (!config) {
    log('No config returned from API');
    return;
}

setConfig(config.BridgeConfig)
setConfig(config.PPPoEConfig)
setConfig(config.DhcpConfig)
setConfig(config.StaticConfig)
setConfig(config.WLANConfig)
setConfig(config.Settings)

updateTags(config);

return; //Not explicitly needed, but I want to prevent any extranious code at the bottom from executing...

function updateTags(config) {
    if (config.tags) {
        if (config.tags.add && config.tags.add.length) {
            log("Adding tags: " + config.tags.add.join(", "));

            for (let [index, tag] of Object.entries(config.tags.add)) {
                log("Tag: " + tag);

                declare("Tags." + tag, null, {value: true});
            }
        }

        if (config.tags.remove && config.tags.remove.length) {
            log("Removing tags: " + config.tags.remove.join(", "));

            for (let [index, tag] of Object.entries(config.tags.remove)) {
                log("Tag: " + tag);
                declare("Tags." + tag, null, {value: false});
            }
        }
    }

    log("Done configuring. Setting provisioned tag");
    declare("Tags.Provisioned", null, {value: true});
}

function setConfig(cnf) {

    if (cnf) {
        for (let [key, value] of Object.entries(cnf)) {

            log("KVP", {key: key, value: value});

            if (key.endsWith("*")) {
                if (value === null) {
                    declare(key, {path: now});
                } else {
                    declare(key, {path: now}, {path: value});
                }
            } else declare(key, {value: now}, {value: value});

        }
    }

}

'
