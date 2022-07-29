
function getNetworkConfig(network, accounts) {
    if (["bsc", "bsc-fork"].includes(network)) {
        console.log(`Deploying with BSC MAINNET config.`)
        return {
            routerAddress: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
            masterChef: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
        }
    } else if (['bsc-testnet', 'bsc-testnet-fork'].includes(network)) {
        console.log(`Deploying with BSC testnet config.`)
        return {
            routerAddress: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
            masterChef: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
        }
    } else {
        throw new Error(`No config found for network ${network}.`)
    }
}

module.exports = { getNetworkConfig };
