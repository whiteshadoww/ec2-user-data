#!/bin/sh

curl --location --request PUT 'http://localhost:7557/provisions/oneisp-bootstrap' \
--data-raw 'const now = Date.now();

let provisioned = declare("Tags.Provisioned", { value: 1 });
if (provisioned.value !== undefined) {
    log('\''CPE is (allegedly) provisioned, returning'\'');
    return;
}

let model = declare("InternetGatewayDevice.DeviceInfo.ModelName", { value: 1 }).value[0];
let serialNumber = declare("DeviceID.SerialNumber", { value: 1 }).value[0];
let productClass = declare("DeviceID.ProductClass", { value: 1 }).value[0];
let oui = declare("DeviceID.OUI", { value: 1 }).value[0];
let args = { SerialNumber: serialNumber, ProductClass: productClass, OUI: oui };

log("Getting device config")

//Get the PPPoE creds
let config = ext('\''cpe-config'\'', '\''resetPppoe'\'', JSON.stringify(args));
if (!config) {
    log('\''No config returned from API'\'');
    return;
}

log(" device config", config)

//////////
refreshWlan();
setUpWlan(config)
//////////

/////////
setInternetConfiguration(config)

///////

setConnectionServicesAndDns();

setAdditionalSettings(config)

updateTags(config);

return; //Not explicitly needed, but I want to prevent any extranious code at the bottom from executing...

function updateTags(config) {
    if (config.tags) {
        if (config.tags.add && config.tags.add.length) {
            log('\''Adding tags: '\'' + config.tags.add.join('\'', '\''));

            for (let [index, tag] of Object.entries(config.tags.add)) {
                log('\''Tag: '\'' + tag);

                declare("Tags." + tag, null, { value: true });
            }
        }

        if (config.tags.remove && config.tags.remove.length) {
            log('\''Removing tags: '\'' + config.tags.remove.join('\'', '\''));

            for (let [index, tag] of Object.entries(config.tags.remove)) {
                log('\''Tag: '\'' + tag);
                declare("Tags." + tag, null, { value: false });
            }
        }
    }

    log('\''Done configuring. Setting provisioned tag'\'');
    declare("Tags.Provisioned", null, { value: true });
}

function refreshWlan() {
    //Refresh the WLAN config
    log('\''Refreshing WLAN'\'');
    declare("InternetGatewayDevice.LANDevice.*.WLANConfiguration.*.*", { path: now });
    declare("InternetGatewayDevice.LANDevice.*.WLANConfiguration.*.SSID", { value: now });
    declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.*.Enable", { value: now }, { value: true });

}

function setUpWlan(config) {

    if (!config.WLan.Password || config.WLan.Password === "")
        return;

    declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID", { value: now }, { value: config.WLan.Name });
    declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.5.SSID", { value: now }, { value: config.WLan.Name + "_5G" });
    declare("InternetGatewayDevice.LANDevice.1.WLANConfiguration.*.PreSharedKey.1.PreSharedKey", { value: now }, { value: config.WLan.Password });


}


function setInternetConfiguration(config) {
    if (config.Type === '\''pppoe'\'') {
        setupBaseWanPppConnection();
        setAccountSpecificSettings(config);
        bouncePppoeConnection();
    }
}

function setupBaseWanPppConnection() {
    //Ensure we have a WANPPPConnection instance
    log('\''Creating WANPPPConnection (if necessary)'\'');
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*", null, { path: 1 });

    log('\''Setting up WANPPPConnection'\'');
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.*", { path: now }); //Refresh the node...

    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.Name", { value: now }, { value: "Internet" });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.ConnectionType", { value: now }, { value: "IP_Routed" });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.X_BROADCOM_COM_IfName", { value: now }, { value: "ppp0.1" });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.NATEnabled", { value: now }, { value: true });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.X_BROADCOM_COM_FirewallEnabled", { value: now }, { value: true });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.Enable", { value: now }, { value: true });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.PPPoEServiceName", { value: now }, { value: "broadband" });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.X_HW_VLAN", { value: now }, { value: 0 });
    declare("InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.*.X_HW_LANBIND", { value: now }, { value: true });
}

function setAccountSpecificSettings(config) {
    //{value: now} forces GenieACS to update the value of the username/password if the value hasn'\''t been updated before now
    log('\''Setting un: '\'' + config.Config.UserName + '\'', pw: '\'' + config.Config.Password);
    declare("InternetGatewayDevice.WANDevice.*.WANConnectionDevice.*.WANPPPConnection.*.Username", { value: now }, { value: config.Config.UserName });
    declare("InternetGatewayDevice.WANDevice.*.WANConnectionDevice.*.WANPPPConnection.*.Password", { value: now }, { value: config.Config.Password });

    //Refresh the vParams
    declare("VirtualParameters.pppoeUsername", { value: now });

    //Refresh the mac and external ip
    declare("InternetGatewayDevice.WANDevice.*.WANConnectionDevice.1.WANPPPConnection.*.MACAddress", { value: now });
}

function setConnectionServicesAndDns() {
    log('\''Setting connection services'\'');

    let hasWanPort = declare("Tags.WanPort", { value: 1 }).value !== undefined;
    let connServices = '\''ppp0.1'\'';
    if (hasWanPort) {
        connServices = '\''ppp0.1,ppp1.1'\'';
    }

    declare("InternetGatewayDevice.Layer3Forwarding.*", { value: now });

    declare("InternetGatewayDevice.Layer3Forwarding.X_BROADCOM_COM_DefaultConnectionServices", { value: now }, { value: connServices });
    declare("InternetGatewayDevice.X_BROADCOM_COM_NetworkConfig.DNSIfName", { value: now }, { value: connServices });
}

function bouncePppoeConnection() {
    //Bounce the PPPoE connection
    switch (model) {
        case '\''SR515ac'\'':
            log('\''Rebooting, because the CPE is dumb'\'', { model: model });
            declare("Reboot", null, { value: Date.now() });
            break;
        case '\''SR510N'\'':
        default:
            log('\''Bouncing the WANPPPConnection instances'\'');
            declare("InternetGatewayDevice.WANDevice.*.WANConnectionDevice.1.WANPPPConnection.*.Reset", { value: now }, { value: true });
    }
}

function setAdditionalSettings(config) {

    if (config.Settings) {
        log('\''Setting wifi/dhcp config'\'');
        for (let [key, value] of Object.entries(config.Settings)) {
            log('\''KVP'\'', { key: key, value: value });
            declare(key, { value: now }, { value: value });
        }
    }

}'