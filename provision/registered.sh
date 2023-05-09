#!/bin/sh

curl --location --request PUT 'http://localhost:7557/provisions/oneisp-registered' \
  --data-raw 'const now = Date.now();
declare("InternetGatewayDevice.ManagementServer.ConnectionRequestUsername", { value: now }, { value: "'"$ConnectionRequestUsername"'" });
declare("InternetGatewayDevice.ManagementServer.ConnectionRequestPassword", { value: now }, { value: "'"$ConnectionRequestPassword"'" })

let serialNumber = declare("DeviceID.SerialNumber", {value: 1}).value[0];
let productClass = declare("DeviceID.ProductClass", {value: 1}).value[0];
let oui = declare("DeviceID.OUI", {value: 1}).value[0];

let wifiPass;
let wifiName;
let deviceMACAddress;

let res = declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.*.PreSharedKey.1.PreSharedKey", {value: now})
if (res) {
    wifiPass = res.value[0];
}

let res2 = declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.MACAddress", {value: now});
if (res2) {
    deviceMACAddress = res2.value[0];
}

let res3 = declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID", {value: now});
if (res3) {
    wifiName = res3.value[0];
}


let args = {
    SerialNumber: serialNumber,
    ProductClass: productClass,
    OUI: oui,
    WifiName: wifiName,
    DeviceMACAddress: deviceMACAddress,
    WifiPass: wifiPass
};

log(JSON.stringify(args));

//Get the PPPoE creds
let config = ext("cpe-config", "initDevice", JSON.stringify(args));
if (!config) {
    log("No config returned from API");
    return;
}

declare("Tags.Registered", null, {value: true});
'
