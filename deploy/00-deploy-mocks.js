const developmentChains = require("../helper-hardhat-config")

// mock variables
const BASE_FEE = ethers.utils.parseEther("0.25") // 0.25 LINK is the premium per request
const GAS_PRICE_LINK = 1e9 // LINK per gas

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if (chainId == 31337) {
        log("Local network detected! Deploying mocks...")
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: [BASE_FEE, GAS_PRICE_LINK],
        })
        log("Mocks deployed!")
        log("--------------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
