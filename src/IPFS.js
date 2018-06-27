"use strict";

const ipfsAPI_ = require("ipfs-api");
// rollup complains about calling a namespace...
const ipfsAPI = ipfsAPI_;

exports.connectImpl = function(host, port) {
    return ipfsAPI(host, port, {protocol: "http"});
};


exports.identityImpl = function(ipfs) {
    return ipfs.id();
};

exports.versionImpl = function(ipfs) {
    return ipfs.version();
};
