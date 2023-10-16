#!/bin/sh

curl --location --request PUT 'http://localhost:7557/provisions/oneisp-registered' \
  --data-raw 'const now = Date.now(); 

let serialNumber = declare("DeviceID.SerialNumber", {value: 1}).value[0];
let productClass = declare("DeviceID.ProductClass", {value: 1}).value[0];
let oui = declare("DeviceID.OUI", {value: 1}).value[0];

let wifiName = "";
let deviceMACAddress = "";

let res2 = declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.MACAddress", {value: now});
if (res2 && res2.value && res2.value.length) {
    deviceMACAddress = res2.value[0];
}

let res3 = declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID", {value: now});
if (res3 && res3.value && res3.value.length) {
    wifiName = res3.value[0];
}


let args = {
    SerialNumber: serialNumber,
    ProductClass: productClass,
    OUI: oui,
    WifiName: wifiName,
    DeviceMACAddress: deviceMACAddress,
    WifiPass: ""
};

log(JSON.stringify(args));

//Get the PPPoE creds
let config = ext("cpe-config", "initDevice", JSON.stringify(args));

declare("Tags.Registered", null, {value: true});
'
