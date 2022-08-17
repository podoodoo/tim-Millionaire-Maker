const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const {
    developmentChains,
    networkConfig,
} = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Millionaire", async function () {
          let raffle, vrfCoordinatorV2Mock, raffleEntranceFee, player, interval
          const chainId = network.config.chainId

          beforeEach(async function () {
              const accounts = await ethers.getSigners()
              // deployer = accounts[0]
              player = accounts[1]
              await deployments.fixture(["all"])
              raffle = await ethers.getContract("Millionaire", player)
              vrfCoordinatorV2Mock = await ethers.getContract(
                  "VRFCoordinatorV2Mock"
              )
              raffleEntranceFee = await raffle.getEntranceFee()
              interval = await raffle.getInterval()
          })

          describe("constructor", async function () {
              it("initializes the raffle correctly", async function () {
                  const raffleState = await raffle.getRaffleState()
                  assert.equal(raffleState.toString(), "0")
                  assert.equal(
                      interval.toString(),
                      networkConfig[chainId]["interval"]
                  )
              })
          })

          describe("enterRaffle", async function () {
              it("reverts when you don't pay enough", async function () {
                  await expect(raffle.enterRaffle()).to.be.revertedWith(
                      "Millionaire__NotEnoughEthEntered"
                  )
              })
              it("records players when they enter", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  const playerFromContract = await raffle.getPlayer(0)
                  assert.equal(playerFromContract, player.address)
              })
              it("emits even on enter", async function () {
                  await expect(
                      raffle.enterRaffle({ value: raffleEntranceFee })
                  ).to.emit(raffle, "MillionaireEnter")
              })
              //   it("doesn't allow entrance when raffle is calculating", async function () {
              //       await raffle.enterRaffle({ value: raffleEntranceFee })

              //       // https://hardhat.org/hardhat-network/reference
              //       await network.provider.send("evm_increaseTime", [
              //           interval.toNumber(),
              //       ])
              //       await network.provider.send("evm_mine")

              //       // pretend to be chainlink keeper
              //       await raffle.performUpkeep([])
              //       await expect(
              //           raffle.enterRaffle({ value: raffleEntranceFee })
              //       ).to.be.revertedWith("Millionaire__RaffleNotOpen")
              //   })
          })
      })
