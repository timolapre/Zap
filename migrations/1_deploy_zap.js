const ZapFullV0 = artifacts.require("ZapFullV0");
const { getNetworkConfig } = require('../deploy-config')

module.exports = function (deployer, network, accounts) {
  let { routerAddress } = getNetworkConfig(network, accounts);
  deployer.deploy(ZapFullV0, routerAddress);
};
