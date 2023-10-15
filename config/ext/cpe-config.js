//config/ext/cpe-config.js
const API_URL = 'rbac.one-isp.net';

const http = require('https');

const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-API-Key': process.env.ACS_API_KEY
}


function resetPppoe(args, callback) {

    let params = JSON.parse(args[0]);
    const options = {
        headers,
        'method': 'POST',
        'hostname': API_URL,
        'path': '/api/v2/acs/configuration',
        'maxRedirects': 20
    };

    const postData = JSON.stringify(params);
    sendRequest(options, postData, callback)
}

function initDevice(args, callback) {

    let params = JSON.parse(args[0]);
    const options = {
        headers,
        'method': 'POST',
        'hostname': API_URL,
        'path': '/api/v2/acs/init-device',
        'maxRedirects': 20
    };


    const postData = JSON.stringify(params);
    sendRequest(options, postData, callback)
}


function sendRequest(options, postData, callback) {
    const req = http.request(options, function (res) {

        if (res.statusCode >= 400) {
            return callback(new Error("Unexpected error resetting PPPoE credentials. Response Code: " +
                res.statusCode + '. Status Message: ' + res.statusMessage + '. t: ' + typeof res.statusCode));
        }


        const chunks = [];

        res.on("data", function (chunk) {
            chunks.push(chunk);
        });

        res.on("end", function (chunk) {
            const body = Buffer.concat(chunks);
            // console.log(body.toString());
            let result = JSON.parse(body.toString());

            console.log('Returning credentials to client', result.data);
            return callback(null, result.data);
        });

        res.on("error", function (error) {
            // console.log('args');
            // console.log(arguments);
            callback(error);
        });
    });
    req.write(postData);
    req.end();
}

exports.resetPppoe = resetPppoe;
exports.initDevice = initDevice;