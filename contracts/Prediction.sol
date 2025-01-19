// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AffiliateManager.sol";
import "hardhat/console.sol";

contract Prediction is Ownable, ReentrancyGuard {
    struct BetGroup {
        uint256[] bets;
        address[] addresses;
        uint256 total;
        uint256 distributedCount;
        uint256 totalDistributed;
    }

    struct Round {
        bool created;
        int32 startPrice;
        int32 endPrice;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 poolBetsLimit;
        BetGroup upBetGroup;
        BetGroup downBetGroup;
        int64 roundStartTime;
    }

    struct Distribution {
        uint256 winnersFeeAmt;
        uint256 fee;
        uint256 totalFees;
        uint256 remainingWinAmt;
        uint256 remainingFeeAmt;
        uint256 pending;
    }

    AffiliateManager public affiliateManager;

    address public gameController;
    mapping(bytes => Round) public pools;
    uint8 public feePercentage = 5;
    uint8 public feeJackpotPercentage = 5;
    address public feeJackpotAddress;
    address public feeAddress = msg.sender;
    bool public isRunning;
    bytes public notRunningReason;
    uint256 public gameId;

    // Errors
    error PendingDistributions();

    // Events
    event RoundStarted(
        bytes indexed poolId,
        int64 timestamp,
        int32 price,
        uint256 minTradeAmount,
        uint256 maxTradeAmount,
        uint256 poolTradesLimit
    );
    event RoundEnded(
        bytes indexed poolId,
        int64 timestamp,
        int32 startPrice,
        int32 endPrice
    );
    event TradePlaced(
        bytes poolId,
        address indexed sender,
        uint256 amount,
        string prediction,
        uint256 newTotal,
        uint256 indexed gameId,
        int64 roundStartTime
    );
    event TradeReturned(bytes poolId, address sender, uint256 amount);
    event GameStopped(bytes reason);
    event GameStarted();
    event RoundDistributed(
        bytes poolId,
        uint256 totalWinners,
        uint256 from,
        uint256 to,
        int64 timestamp
    );
    event TradeWinningsSent(
        bytes poolId,
        address indexed sender,
        uint256 tradeAmount,
        uint256 winningsAmount,
        uint256 finalWin
    );

    constructor(
        address _newGameController,
        address _feeJackpotAddress,
        address _affiliateManager
    ) Ownable(_newGameController) {
        require(
            _newGameController != address(0),
            "Invalid game controller address"
        );
        require(_feeJackpotAddress != address(0), "Invalid jackpot address");
        require(
            _affiliateManager != address(0),
            "Invalid AffiliateManager address"
        );

        affiliateManager = AffiliateManager(_affiliateManager);
        gameController = _newGameController;
        feeJackpotAddress = _feeJackpotAddress;
    }

    // Modifiers
    modifier onlyOpenPool(bytes calldata poolId) {
        require(isPoolOpen(poolId), "This pool has a round in progress");
        _;
    }

    modifier onlyGameController() {
        require(
            msg.sender == gameController,
            "Only game controller can do this"
        );
        _;
    }

    modifier onlyGameRunning() {
        require(isRunning, "The game is not running");
        _;
    }

    modifier onlyPoolExists(bytes calldata poolId) {
        require(pools[poolId].created, "Pool does not exist");
        _;
    }

    function startGame() public onlyOwner {
        isRunning = true;
        notRunningReason = "";
        emit GameStarted();
    }

    function stopGame(bytes calldata reason) public onlyOwner {
        isRunning = false;
        notRunningReason = reason;
        emit GameStopped(reason);
    }

    function createPool(
        bytes calldata poolId,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 poolBetsLimit
    ) public onlyGameController {
        pools[poolId].created = true;
        pools[poolId].minBetAmount = minBetAmount;
        pools[poolId].maxBetAmount = maxBetAmount;
        pools[poolId].poolBetsLimit = poolBetsLimit;
    }

    function isPoolOpen(bytes calldata poolId) public view returns (bool) {
        bool a = pools[poolId].startPrice == 0;
        return a;
    }

    function trigger(
        bytes calldata poolId,
        int64 timeMS,
        int32 price,
        uint32 batchSize
    ) public onlyGameController onlyPoolExists(poolId) {
        Round storage currentRound = pools[poolId];
        console.log("aaa L175:");

        if (isPoolOpen(poolId)) {
            require(isRunning, "The game is not running");
            currentRound.startPrice = price;
            console.log("Start price aaa L180:");
            currentRound.roundStartTime = timeMS;

            emit RoundStarted(
                poolId,
                timeMS,
                currentRound.startPrice,
                currentRound.minBetAmount,
                currentRound.maxBetAmount,
                currentRound.poolBetsLimit
            );
        } else if (currentRound.endPrice == 0) {
            currentRound.endPrice = price;
            console.log("End price aaa L193:");

            emit RoundEnded(
                poolId,
                timeMS,
                currentRound.startPrice,
                currentRound.endPrice
            );
            console.log("Before distribute aaa L201:");

            distribute(poolId, batchSize, timeMS);
        } else {
            revert PendingDistributions();
        }
    }

    function returnBets(
        bytes calldata poolId,
        BetGroup storage group,
        uint32 batchSize
    ) private {
        uint256 pending = group.bets.length - group.distributedCount;
        uint256 limit = pending > batchSize ? batchSize : pending;
        uint256 to = group.distributedCount + limit;

        for (uint256 i = group.distributedCount; i < to; i++) {
            sendEther(group.addresses[i], group.bets[i]);
            emit TradeReturned(poolId, group.addresses[i], group.bets[i]);
        }

        group.distributedCount = to;
    }

    function distribute(
        bytes calldata poolId,
        uint32 batchSize,
        int64 timeMS
    ) public onlyGameController onlyPoolExists(poolId) nonReentrant {
        Round storage round = pools[poolId];
        console.log("Inside distribute function L232");

        if (
            round.upBetGroup.bets.length == 0 ||
            round.downBetGroup.bets.length == 0 ||
            (round.startPrice == round.endPrice)
        ) {
            console.log("Inside distribute function draw L239");
            if (round.startPrice == round.endPrice) {
                console.log(
                    "Inside distribute function draw if price equal L239"
                );
                BetGroup storage returnGroupUp = round.upBetGroup;
                BetGroup storage returnGroupDown = round.downBetGroup;
                uint256 fromReturnUp = returnGroupUp.distributedCount;
                uint256 fromReturnDown = returnGroupDown.distributedCount;
                returnBets(poolId, returnGroupUp, batchSize);
                returnBets(poolId, returnGroupDown, batchSize);
                emit RoundDistributed(
                    poolId,
                    returnGroupUp.bets.length,
                    fromReturnUp,
                    returnGroupUp.distributedCount,
                    timeMS
                );
                emit RoundDistributed(
                    poolId,
                    returnGroupDown.bets.length,
                    fromReturnDown,
                    returnGroupDown.distributedCount,
                    timeMS
                );
                if (
                    returnGroupUp.distributedCount ==
                    returnGroupUp.bets.length &&
                    returnGroupDown.distributedCount ==
                    returnGroupDown.bets.length
                ) {
                    clearPool(poolId);
                }
            } else {
                BetGroup storage returnGroup = round.downBetGroup.bets.length ==
                    0
                    ? round.upBetGroup
                    : round.downBetGroup;
                uint256 fromReturn = returnGroup.distributedCount;
                returnBets(poolId, returnGroup, batchSize);
                emit RoundDistributed(
                    poolId,
                    returnGroup.bets.length,
                    fromReturn,
                    returnGroup.distributedCount,
                    timeMS
                );
                if (returnGroup.distributedCount == returnGroup.bets.length) {
                    gameId++;
                    clearPool(poolId);
                }
            }
            return;
        }

        BetGroup storage winners = round.downBetGroup;
        BetGroup storage losers = round.upBetGroup;

        if (round.startPrice < round.endPrice) {
            winners = round.upBetGroup;
            losers = round.downBetGroup;
        }

        Distribution memory dist = calculateDistribution(winners, losers);
        uint256 limit = dist.pending > batchSize ? batchSize : dist.pending;
        uint256 to = winners.distributedCount + limit;

        for (uint256 i = winners.distributedCount; i < to; i++) {
            // Calculate winnings based on the total winnings of the winners
            uint256 winnings = (winners.bets[i] * dist.remainingWinAmt) /
                winners.total;
            console.log("Inside for loop winnings L308:", winnings);

            (uint256 affiliateReward, address referrer) = affiliateManager
                .rewardAffiliate(winners.addresses[i], winnings);

            uint256 netWinnings = winnings - affiliateReward;
            uint finalWin = netWinnings + winners.bets[i];

            if (referrer != address(0) && affiliateReward > 0) {
                (bool success, ) = referrer.call{value: affiliateReward}("");
                require(success, "Transfer to referrer failed");
            }

            sendEther(winners.addresses[i], netWinnings + winners.bets[i]);

            emit TradeWinningsSent(
                poolId,
                winners.addresses[i],
                winners.bets[i],
                winnings,
                finalWin
            );

            winners.totalDistributed += netWinnings;
        }

        emit RoundDistributed(
            poolId,
            winners.bets.length,
            winners.distributedCount,
            to,
            timeMS
        );

        winners.distributedCount = to;

        if (winners.distributedCount == winners.bets.length) {
            sendEther(
                feeAddress,
                dist.remainingFeeAmt -
                    ((dist.fee * feeJackpotPercentage) /
                        (feePercentage + feeJackpotPercentage))
            );
            sendEther(
                feeJackpotAddress,
                (dist.fee * feeJackpotPercentage) /
                    (feePercentage + feeJackpotPercentage)
            );

            gameId++;
            clearPool(poolId);
        }
    }

    function calculateDistribution(
        BetGroup storage winners,
        BetGroup storage losers
    ) private view returns (Distribution memory) {
        uint256 serviceFeeAmt = ((winners.total + losers.total) *
            feePercentage) / 100;

        uint256 jackpotFeeAmt = ((winners.total + losers.total) *
            feeJackpotPercentage) / 100;

        uint256 totalFeeAmt = serviceFeeAmt + jackpotFeeAmt;

        uint256 remainingFeeAmt = totalFeeAmt;
        uint256 remainLoserAmt = losers.total - serviceFeeAmt - jackpotFeeAmt;

        uint256 remainWinnersAmt = winners.total -
            serviceFeeAmt -
            jackpotFeeAmt;

        uint256 pending = winners.bets.length - winners.distributedCount;

        return
            Distribution({
                winnersFeeAmt: (winners.total *
                    (feePercentage + feeJackpotPercentage)) / 100,
                fee: totalFeeAmt,
                totalFees: remainLoserAmt,
                remainingWinAmt: remainWinnersAmt,
                remainingFeeAmt: remainingFeeAmt,
                pending: pending
            });
    }

    function clearPool(bytes calldata poolId) private {
        delete pools[poolId].upBetGroup;
        delete pools[poolId].downBetGroup;
        delete pools[poolId].startPrice;
        delete pools[poolId].endPrice;
    }

    function hasPendingDistributions(
        bytes calldata poolId
    ) public view returns (bool) {
        return
            (pools[poolId].upBetGroup.bets.length +
                pools[poolId].downBetGroup.bets.length) > 0;
    }

    struct makeTradeStruct {
        bytes poolId;
        // string avatarUrl;
        // string countryCode;
        bool upOrDown;
        // string gameId;
    }

    struct userDataStruct {
        // string avatar;
        // string countryCode;
        int64 roundStartTime;
        // string gameId;
    }

    function addBet(
        BetGroup storage betGroup,
        uint256 amount
    )
        private
        returns (
            // string calldata avatar,
            // string calldata countryCode
            uint256
        )
    {
        betGroup.bets.push(amount);
        betGroup.addresses.push(msg.sender);
        // betGroup.avatars.push(avatar);
        // betGroup.countries.push(countryCode);
        betGroup.total += amount;
        return betGroup.total;
    }

    function makeTrade(
        makeTradeStruct calldata userTrade
    )
        public
        payable
        onlyOpenPool(userTrade.poolId)
        onlyGameRunning
        onlyPoolExists(userTrade.poolId)
    {
        require(isEOA(msg.sender), "Must be EOA");
        require(msg.value > 0, "Enter valid amount");
        require(
            msg.value >= pools[userTrade.poolId].minBetAmount,
            "Amount is not enough"
        );
        require(
            msg.value <= pools[userTrade.poolId].maxBetAmount,
            "Amount is higher"
        );
        require(
            !isAddressInAnyBetGroup(pools[userTrade.poolId], msg.sender),
            "User has already placed a bet"
        );

        // New Check: Ensure the user is registered in the AffiliateManager contract
        require(
            affiliateManager.isRegistered(msg.sender),
            "User is not registered in the AffiliateManager"
        );

        uint256 newTotal;

        if (userTrade.upOrDown) {
            require(
                pools[userTrade.poolId].upBetGroup.bets.length <=
                    pools[userTrade.poolId].poolBetsLimit - 1,
                "Pool is full, wait for next round"
            );

            newTotal = addBet(
                pools[userTrade.poolId].upBetGroup,
                msg.value
                // userTrade.avatarUrl,
                // userTrade.countryCode
            );
        } else {
            require(
                pools[userTrade.poolId].downBetGroup.bets.length <=
                    pools[userTrade.poolId].poolBetsLimit - 1,
                "Pool is full, wait for next round"
            );
            newTotal = addBet(pools[userTrade.poolId].downBetGroup, msg.value);
        }

        userDataStruct memory userTradeData;
        // userTradeData.avatar = userTrade.avatarUrl;
        // userTradeData.countryCode = userTrade.countryCode;
        userTradeData.roundStartTime = pools[userTrade.poolId].roundStartTime;
        uint256 gameId_ = gameId;

        emit TradePlaced(
            userTrade.poolId,
            msg.sender,
            msg.value,
            (userTrade.upOrDown) ? "UP" : "DOWN",
            newTotal,
            gameId_,
            userTradeData.roundStartTime
        );
    }

    function isAddressInBetGroup(
        BetGroup storage betGroup,
        address user
    ) private view returns (bool) {
        for (uint256 i = 0; i < betGroup.addresses.length; i++) {
            if (betGroup.addresses[i] == user) {
                return true;
            }
        }
        return false;
    }

    function isAddressInAnyBetGroup(
        Round storage round,
        address user
    ) private view returns (bool) {
        return
            isAddressInBetGroup(round.upBetGroup, user) ||
            isAddressInBetGroup(round.downBetGroup, user);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function isEOA(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size == 0;
    }

    // Helper function to send ether to an address
    function sendEther(address recipient, uint256 amount) private {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // Function to change the minBetAmount and maxBetAmount
    function changeBetAmounts(
        bytes calldata poolId,
        uint256 newMinBetAmount,
        uint256 newMaxBetAmount
    ) public onlyGameController onlyPoolExists(poolId) {
        require(
            newMinBetAmount <= newMaxBetAmount,
            "Minimum bet amount must be less than maximum bet amount"
        );

        pools[poolId].minBetAmount = newMinBetAmount;
        pools[poolId].maxBetAmount = newMaxBetAmount;
    }

    function changeGameControllerAddress(
        address newGameControllerAddress
    ) public onlyOwner {
        gameController = newGameControllerAddress;
    }

    function changeGameFeePercentage(uint8 newFeePercentage) public onlyOwner {
        require(newFeePercentage <= 100, "Wrong fee percentage value");
        feePercentage = newFeePercentage;
    }

    function changeGameFeeAddress(address newFeeAddress) public onlyOwner {
        feeAddress = newFeeAddress;
    }
}
