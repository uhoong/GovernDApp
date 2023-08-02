// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {CTHelpers} from "./CTHelpers.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";

library CeilDiv {
    // calculates ceil(x/y)
    function ceildiv(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x > 0) return ((x - 1) / y) + 1;
        return x / y;
    }
}

contract MarketMaker is Ownable, ERC1155Receiver {
    using SafeMath for uint256;
    using CeilDiv for uint256;
    /*
     *  Constants
     */
    uint64 public constant FEE_RANGE = 10**18;

    /*
     *  Events
     */
    event AMMCreated(uint256 initialFunding);
    event AMMPaused();
    event AMMResumed();
    event AMMClosed();
    event AMMFundingChanged(int256 fundingChange);
    event AMMFeeChanged(uint64 newFee);
    event AMMFeeWithdrawal(uint256 fees);
    event AMMOutcomeTokenTrade(
        address indexed transactor,
        int256[] outcomeTokenAmounts,
        int256 outcomeTokenNetCost,
        uint256 marketFees
    );
    event FPMMBuy(
        address indexed buyer,
        uint256 investmentAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensBought
    );
    event FPMMSell(
        address indexed seller,
        uint256 returnAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensSold
    );

    enum Stage {
        Running,
        Paused,
        Closed
    }

    /*
     *  Storage
     */
    ConditionalTokens public conditionalTokens;
    IERC20 public collateralToken;
    bytes32 public conditionId;
    uint256 public OutcomeSlotCount;
    uint64 public fee;
    uint256 public funding;
    Stage public stage;
    uint256 constant ONE = 10**18;
    uint256[] positionIds;

    /*
     *  Modifiers
     */
    modifier atStage(Stage _stage) {
        // Contract has to be in given stage
        require(stage == _stage);
        _;
    }

    constructor(
        ConditionalTokens _conditionalTokens,
        IERC20 _collateralToken,
        bytes32 _conditionId
    ) {
        funding = 0;
        stage = Stage.Paused;
        conditionalTokens = ConditionalTokens(_conditionalTokens);
        collateralToken = IERC20(_collateralToken);
        conditionId = _conditionId;
        OutcomeSlotCount = conditionalTokens.getOutcomeSlotCount(conditionId);
        for (uint256 i = 0; i < OutcomeSlotCount; i++) {
            bytes32 collectionId = conditionalTokens.getCollectionId(
                conditionId,
                1 << i
            );
            positionIds.push(
                conditionalTokens.getPositionId(collateralToken, collectionId)
            );
        }
    }

    function getPoolBalances() private view returns (uint256[] memory) {
        address[] memory thises = new address[](positionIds.length);
        for (uint256 i = 0; i < positionIds.length; i++) {
            thises[i] = address(this);
        }
        return conditionalTokens.balanceOfBatch(thises, positionIds);
    }

    /// @dev Allows to fund the market with collateral tokens converting them into outcome tokens
    /// Note for the future: should combine splitPosition and mergePositions into one function, as code duplication causes things like this to happen.
    function changeFunding(int256 fundingChange)
        public
        onlyOwner
        atStage(Stage.Paused)
    {
        require(fundingChange != 0, "funding change must be non-zero");
        // Either add or subtract funding based off whether the fundingChange parameter is negative or positive
        if (fundingChange > 0) {
            require(
                collateralToken.transferFrom(
                    msg.sender,
                    address(this),
                    uint256(fundingChange)
                ) &&
                    collateralToken.approve(
                        address(conditionalTokens),
                        uint256(fundingChange)
                    )
            );
            splitPositionThroughAllConditions(uint256(fundingChange));
            funding = funding + uint256(fundingChange);
            emit AMMFundingChanged(fundingChange);
        }
        if (fundingChange < 0) {
            mergePositionsThroughAllConditions(uint256(-fundingChange));
            funding = funding - uint256(-fundingChange);
            require(collateralToken.transfer(owner(), uint256(-fundingChange)));
            emit AMMFundingChanged(fundingChange);
        }
    }

    function pause() public onlyOwner atStage(Stage.Running) {
        stage = Stage.Paused;
        emit AMMPaused();
    }

    function resume() public onlyOwner atStage(Stage.Paused) {
        stage = Stage.Running;
        emit AMMResumed();
    }

    function changeFee(uint64 _fee) public onlyOwner atStage(Stage.Paused) {
        fee = _fee;
        emit AMMFeeChanged(fee);
    }

    /// @dev Allows market owner to close the markets by transferring all remaining outcome tokens to the owner
    function close() public onlyOwner {
        require(
            stage == Stage.Running || stage == Stage.Paused,
            "This Market has already been closed"
        );
        for (uint256 i = 0; i < OutcomeSlotCount; i++) {
            uint256 positionId = generateAtomicPositionId(i);
            conditionalTokens.safeTransferFrom(
                address(this),
                owner(),
                positionId,
                conditionalTokens.balanceOf(address(this), positionId),
                ""
            );
        }
        stage = Stage.Closed;
        emit AMMClosed();
    }

    /// @dev Allows market owner to withdraw fees generated by trades
    function withdrawFees() public onlyOwner returns (uint256 fees) {
        fees = collateralToken.balanceOf(address(this));
        // Transfer fees
        require(collateralToken.transfer(owner(), fees));
        emit AMMFeeWithdrawal(fees);
    }

    function calcBuyAmount(uint256 investmentAmount, uint256 outcomeIndex)
        public
        view
        returns (uint256)
    {
        require(outcomeIndex < positionIds.length, "invalid outcome index");

        uint256[] memory poolBalances = getPoolBalances();
        uint256 investmentAmountMinusFees = investmentAmount.sub(
            investmentAmount.mul(fee) / ONE
        );
        uint256 buyTokenPoolBalance = poolBalances[outcomeIndex];
        uint256 endingOutcomeBalance = buyTokenPoolBalance.mul(ONE);
        for (uint256 i = 0; i < poolBalances.length; i++) {
            if (i != outcomeIndex) {
                uint256 poolBalance = poolBalances[i];
                endingOutcomeBalance = endingOutcomeBalance
                    .mul(poolBalance)
                    .ceildiv(poolBalance.add(investmentAmountMinusFees));
            }
        }
        require(endingOutcomeBalance > 0, "must have non-zero balances");

        return
            buyTokenPoolBalance.add(investmentAmountMinusFees).sub(
                endingOutcomeBalance.ceildiv(ONE)
            );
    }

    function calcSellAmount(uint256 returnAmount, uint256 outcomeIndex)
        public
        view
        returns (uint256 outcomeTokenSellAmount)
    {
        require(outcomeIndex < positionIds.length, "invalid outcome index");

        uint256[] memory poolBalances = getPoolBalances();
        uint256 returnAmountPlusFees = returnAmount.mul(ONE) / ONE.sub(fee);
        uint256 sellTokenPoolBalance = poolBalances[outcomeIndex];
        uint256 endingOutcomeBalance = sellTokenPoolBalance.mul(ONE);
        for (uint256 i = 0; i < poolBalances.length; i++) {
            if (i != outcomeIndex) {
                uint256 poolBalance = poolBalances[i];
                endingOutcomeBalance = endingOutcomeBalance
                    .mul(poolBalance)
                    .ceildiv(poolBalance.sub(returnAmountPlusFees));
            }
        }
        require(endingOutcomeBalance > 0, "must have non-zero balances");

        return
            returnAmountPlusFees.add(endingOutcomeBalance.ceildiv(ONE)).sub(
                sellTokenPoolBalance
            );
    }

    function buy(
        uint256 investmentAmount,
        uint256 outcomeIndex,
        uint256 minOutcomeTokensToBuy
    ) external {
        uint256 outcomeTokensToBuy = calcBuyAmount(
            investmentAmount,
            outcomeIndex
        );
        require(
            outcomeTokensToBuy >= minOutcomeTokensToBuy,
            "minimum buy amount not reached"
        );

        require(
            collateralToken.transferFrom(
                msg.sender,
                address(this),
                investmentAmount
            ),
            "cost transfer failed"
        );

        uint256 feeAmount = investmentAmount.mul(fee) / ONE;
        uint256 investmentAmountMinusFees = investmentAmount.sub(feeAmount);
        require(
            collateralToken.approve(
                address(conditionalTokens),
                investmentAmountMinusFees
            ),
            "approval for splits failed"
        );
        splitPositionThroughAllConditions(investmentAmountMinusFees);

        conditionalTokens.safeTransferFrom(
            address(this),
            msg.sender,
            positionIds[outcomeIndex],
            outcomeTokensToBuy,
            ""
        );

        emit FPMMBuy(
            msg.sender,
            investmentAmount,
            feeAmount,
            outcomeIndex,
            outcomeTokensToBuy
        );
    }

    function sell(
        uint256 returnAmount,
        uint256 outcomeIndex,
        uint256 maxOutcomeTokensToSell
    ) external {
        uint256 outcomeTokensToSell = calcSellAmount(
            returnAmount,
            outcomeIndex
        );
        require(
            outcomeTokensToSell <= maxOutcomeTokensToSell,
            "maximum sell amount exceeded"
        );

        conditionalTokens.safeTransferFrom(
            msg.sender,
            address(this),
            positionIds[outcomeIndex],
            outcomeTokensToSell,
            ""
        );

        uint256 feeAmount = returnAmount.mul(fee) / (ONE.sub(fee));
        uint256 returnAmountPlusFees = returnAmount.add(feeAmount);
        mergePositionsThroughAllConditions(returnAmountPlusFees);

        require(
            collateralToken.transfer(msg.sender, returnAmount),
            "return transfer failed"
        );

        emit FPMMSell(
            msg.sender,
            returnAmount,
            feeAmount,
            outcomeIndex,
            outcomeTokensToSell
        );
    }

    function onERC1155Received(
        address operator,
        address, /*from*/
        uint256, /*id*/
        uint256, /*value*/
        bytes calldata /*data*/
    ) external returns (bytes4) {
        if (operator == address(this)) {
            return this.onERC1155Received.selector;
        }
        return 0x0;
    }

    function onERC1155BatchReceived(
        address _operator,
        address, /*from*/
        uint256[] calldata, /*ids*/
        uint256[] calldata, /*values*/
        bytes calldata /*data*/
    ) external returns (bytes4) {
        if (_operator == address(this)) {
            return this.onERC1155BatchReceived.selector;
        }
        return 0x0;
    }

    function generateBasicPartition(uint256 outcomeSlotCount)
        private
        pure
        returns (uint256[] memory partition)
    {
        partition = new uint256[](outcomeSlotCount);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            partition[i] = 1 << i;
        }
    }

    function generateAtomicPositionId(uint256 i)
        internal
        view
        returns (uint256)
    {
        return positionIds[i];
    }

    function splitPositionThroughAllConditions(uint256 amount) private {
        uint256[] memory partition = generateBasicPartition(OutcomeSlotCount);
        conditionalTokens.splitPosition(
            collateralToken,
            conditionId,
            partition,
            amount
        );
    }

    function mergePositionsThroughAllConditions(uint256 amount) private {
        uint256[] memory partition = generateBasicPartition(OutcomeSlotCount);
        conditionalTokens.mergePositions(
            collateralToken,
            conditionId,
            partition,
            amount
        );
    }
}
