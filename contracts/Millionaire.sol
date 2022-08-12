//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Millionaire__NotEnoughEthEntered();
error Millionaire__TransferFailed();
error Millionaire__RaffleNotOpen();
error Millionaire__UpkeepNotNeeded(
    uint256 balance,
    uint256 numPlayers,
    uint256 raffleState
);

/**
 * @title Make a Millionaire contract
 * @author Timothy Yang & Patrick Collins from FreeCodeCamp
 * @notice This contract is for creating safe and secure decentralized smart contracts to make millionaires.
 * Based on reddit.com/r/makeamillionaire.
 * Gets donations from users and picks a random winner from those donations.
 * @dev Implements Chainlink VRF and Keepers
 */

contract Millionaire is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /** Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    // VRF variables (https://docs.chain.link/docs/get-a-random-number/)
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    // Millionaire variables
    RaffleState private s_raffleState;
    address private s_recentWinner;
    uint256 private s_lastTimestamp;
    uint256 private immutable i_interval;

    /** Events */
    event MillionaireEnter(address indexed player);
    event MillionaireRequestedWinner(uint256 indexed requestId);
    event MillionaireWinnerPicked(address indexed winner);

    /** Functions */
    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Millionaire__NotEnoughEthEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Millionaire__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit MillionaireEnter(msg.sender);
    }

    /**
     * @dev This is the function the Chainlink Keeper nodes call.
     * They look for the `upkeepNeeded` to return true.
     * The following should be true in order to return true:
     * 1. Our time interval should have passed.
     * 2. The raffle should have at least one player and some ETH.
     * 3. Our subscription is funded with LINK.
     * 4. The raffle should be in an "open" state.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = (block.timestamp - s_lastTimestamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = isOpen && timePassed && hasPlayers && hasBalance;
    }

    function performUpkeep(
        bytes memory /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Millionaire__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        requestRandomWinner();
    }

    /** Uses VRF v2 for randomness */
    function requestRandomWinner() internal {
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit MillionaireRequestedWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Millionaire__TransferFailed();
        }

        emit MillionaireWinnerPicked(winner);

        // reset state
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
    }

    /** View/Pure Functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmation() public pure returns (uint256) {
        return REQUEST_CONFIRMATION;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
