// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfigConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, HelperConfigConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1); // to pass the deadline
        vm.roll(block.number + 1);

        _;
    }

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external skipFork {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entraceFee = config.entraceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleIntializesInOpenState() public view skipFork{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnoughEntraceFee() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);

        // Assert
        raffle.enterRaffle();
    }

    function testRaffleRecordsWhenPlayerEnter() public skipFork{
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entraceFee}();
        // Assert

        address playerRecord = raffle.getPlayer(0);

        assert(playerRecord == PLAYER);
    }

    function testEnterRaffleEmitsEvent() public skipFork{
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        // Assert

        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entraceFee}();
    }

    function testNotEnterWhenRaffleCalculating() public raffleEntered skipFork{
        //Arrange
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entraceFee}();
    }

    function testCheckUpKeepReturnsFalseWhenItHasNoBalance() public skipFork{
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpReturnsFalseIfRaffleIsntOpen() public raffleEntered skipFork{
        raffle.performUpkeep("");

        // Act
        (bool upKeedNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeedNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed() public {}

    function testCheckUpKeepReturnsTrueWhenParamsAreGood() public {}

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public raffleEntered skipFork{
        // Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public skipFork{
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entraceFee}();
        currentBalance = currentBalance + entraceFee;
        numPlayers = 1;

        // Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    // What if we need to get data from emitted events in our tests?

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered skipFork{
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    // Fuzz Testing
    function testFulfillrandomwWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 requestId) public raffleEntered skipFork{
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    // Final big test
    function testFulfillrandomWordsPicksAWinnerResetsAndSendMoney() public raffleEntered skipFork{
        // Arrange
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));

            hoax(newPlayer, 1 ether);

            raffle.enterRaffle{value: entraceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entraceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        console.log("Winner Balance is : ", winnerBalance);
        console.log("End thing is : ", winnerStartingBalance + prize);
        // assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
