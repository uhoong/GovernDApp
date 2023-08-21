// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {CTHelpers} from "./CTHelpers.sol";

import {IConditionalTokens} from "../interfaces/market/IConditionalTokens.sol";

contract ConditionalTokens is ERC1155,IConditionalTokens {
    

    /// Mapping key is an condition ID. Value represents numerators of the payout vector associated with the condition. This array is initialized with a length equal to the outcome slot count. E.g. Condition with 3 outcomes [A, B, C] and two of those correct [0.5, 0.5, 0]. In Ethereum there are no decimal values, so here, 0.5 is represented by fractions like 1/2 == 0.5. That's why we need numerator and denominator values. Payout numerators are also used as a check of initialization. If the numerators array is empty (has length zero), the condition was not created/prepared. See getOutcomeSlotCount.
    mapping(bytes32 => uint256[]) public payoutNumerators;
    /// Denominator is also used for checking if the condition has been resolved. If the denominator is non-zero, then the condition has been resolved.
    mapping(bytes32 => uint256) public payoutDenominator;

    constructor(string memory uri_) ERC1155(uri_) {}

    /// @dev This function prepares a condition by initializing a payout vector associated with the condition.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    /// @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
    function prepareCondition(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external {
        // Limit of 256 because we use a partition array that is a number of 256 bits.
        require(outcomeSlotCount <= 256, "too many outcome slots");
        require(
            outcomeSlotCount > 1,
            "there should be more than one outcome slot"
        );
        bytes32 conditionId = CTHelpers.getConditionId(
            oracle,
            questionId,
            outcomeSlotCount
        );
        require(
            payoutNumerators[conditionId].length == 0,
            "condition already prepared"
        );
        payoutNumerators[conditionId] = new uint256[](outcomeSlotCount);
        emit ConditionPreparation(
            conditionId,
            oracle,
            questionId,
            outcomeSlotCount
        );
    }

    /// @dev Called by the oracle for reporting results of conditions. Will set the payout vector for the condition with the ID ``keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount))``, where oracle is the message sender, questionId is one of the parameters of this function, and outcomeSlotCount is the length of the payouts parameter, which contains the payoutNumerators for each outcome slot of the condition.
    /// @param questionId The question ID the oracle is answering for
    /// @param payouts The oracle's answer
    function reportPayouts(
        bytes32 questionId,
        uint256[] calldata payouts
    ) external {
        uint256 outcomeSlotCount = payouts.length;
        require(
            outcomeSlotCount > 1,
            "there should be more than one outcome slot"
        );
        // IMPORTANT, the oracle is enforced to be the sender because it's part of the hash.
        bytes32 conditionId = CTHelpers.getConditionId(
            msg.sender,
            questionId,
            outcomeSlotCount
        );
        require(
            payoutNumerators[conditionId].length == outcomeSlotCount,
            "condition not prepared or found"
        );
        require(
            payoutDenominator[conditionId] == 0,
            "payout denominator already set"
        );

        uint256 den = 0;
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            uint256 num = payouts[i];
            den = den + num;

            require(
                payoutNumerators[conditionId][i] == 0,
                "payout numerator already set"
            );
            payoutNumerators[conditionId][i] = num;
        }
        require(den > 0, "payout is all zeroes");
        payoutDenominator[conditionId] = den;
        emit ConditionResolution(
            conditionId,
            msg.sender,
            questionId,
            outcomeSlotCount,
            payoutNumerators[conditionId]
        );
    }

    /// @dev This function splits a position. If splitting from the collateral, this contract will attempt to transfer `amount` collateral from the message sender to itself. Otherwise, this contract will burn `amount` stake held by the message sender in the position being split worth of EIP 1155 tokens. Regardless, if successful, `amount` stake will be minted in the split target positions. If any of the transfers, mints, or burns fail, the transaction will revert. The transaction will also revert if the given partition is trivial, invalid, or refers to more slots than the condition is prepared with.
    /// @param collateralToken The address of the positions' backing collateral token.
    /// @param conditionId The ID of the condition to split on.
    /// @param partition An array of disjoint index sets representing a nontrivial partition of the outcome slots of the given condition. E.g. A|B and C but not A|B and B|C (is not disjoint). Each element's a number which, together with the condition, represents the outcome collection. E.g. 0b110 is A|B, 0b010 is B, etc.
    /// @param amount The amount of collateral or stake to split.
    function splitPosition(
        IERC20 collateralToken,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        require(partition.length > 1, "got empty or singleton partition");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        // For a condition with 4 outcomes fullIndexSet's 0b1111; for 5 it's 0b11111...
        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        // freeIndexSet starts as the full collection
        uint256 freeIndexSet = fullIndexSet;
        // This loop checks that all condition sets are disjoint (the same outcome is not part of more than 1 set)
        uint256[] memory positionIds = new uint256[](partition.length);
        uint256[] memory amounts = new uint256[](partition.length);
        for (uint256 i = 0; i < partition.length; i++) {
            uint256 indexSet = partition[i];
            require(
                indexSet > 0 && indexSet < fullIndexSet,
                "got invalid index set"
            );
            require(
                (indexSet & freeIndexSet) == indexSet,
                "partition not disjoint"
            );
            freeIndexSet ^= indexSet;
            positionIds[i] = CTHelpers.getPositionId(
                collateralToken,
                CTHelpers.getCollectionId(conditionId, indexSet)
            );
            amounts[i] = amount;
        }

        if (freeIndexSet == 0) {
            // Partitioning the full set of outcomes for the condition in this branch
            require(
                collateralToken.transferFrom(msg.sender, address(this), amount),
                "could not receive collateral tokens"
            );
        } else {
            // Partitioning a subset of outcomes for the condition in this branch.
            // For example, for a condition with three outcomes A, B, and C, this branch
            // allows the splitting of a position $:(A|C) to positions $:(A) and $:(C).
            _burn(
                msg.sender,
                CTHelpers.getPositionId(
                    collateralToken,
                    CTHelpers.getCollectionId(
                        conditionId,
                        fullIndexSet ^ freeIndexSet
                    )
                ),
                amount
            );
        }

        _mintBatch(
            msg.sender,
            // position ID is the ERC 1155 token ID
            positionIds,
            amounts,
            ""
        );
        emit PositionSplit(
            msg.sender,
            collateralToken,
            conditionId,
            partition,
            amount
        );
    }

    function mergePositions(
        IERC20 collateralToken,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        require(partition.length > 1, "got empty or singleton partition");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        uint256 freeIndexSet = fullIndexSet;
        uint256[] memory positionIds = new uint256[](partition.length);
        uint256[] memory amounts = new uint256[](partition.length);
        for (uint256 i = 0; i < partition.length; i++) {
            uint256 indexSet = partition[i];
            require(
                indexSet > 0 && indexSet < fullIndexSet,
                "got invalid index set"
            );
            require(
                (indexSet & freeIndexSet) == indexSet,
                "partition not disjoint"
            );
            freeIndexSet ^= indexSet;
            positionIds[i] = CTHelpers.getPositionId(
                collateralToken,
                CTHelpers.getCollectionId(conditionId, indexSet)
            );
            amounts[i] = amount;
        }
        _burnBatch(msg.sender, positionIds, amounts);

        if (freeIndexSet == 0) {
            require(
                collateralToken.transfer(msg.sender, amount),
                "could not send collateral tokens"
            );
        } else {
            _mint(
                msg.sender,
                CTHelpers.getPositionId(
                    collateralToken,
                    CTHelpers.getCollectionId(
                        conditionId,
                        fullIndexSet ^ freeIndexSet
                    )
                ),
                amount,
                ""
            );
        }
        emit PositionsMerge(
            msg.sender,
            collateralToken,
            conditionId,
            partition,
            amount
        );
    }

    function redeemPositions(
        IERC20 collateralToken,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external {
        uint256 den = payoutDenominator[conditionId];
        require(den > 0, "result for condition not received yet");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        uint256 totalPayout = 0;

        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        for (uint256 i = 0; i < indexSets.length; i++) {
            uint256 indexSet = indexSets[i];
            require(
                indexSet > 0 && indexSet < fullIndexSet,
                "got invalid index set"
            );
            uint256 positionId = CTHelpers.getPositionId(
                collateralToken,
                CTHelpers.getCollectionId(conditionId, indexSet)
            );

            uint256 payoutNumerator = 0;
            for (uint256 j = 0; j < outcomeSlotCount; j++) {
                if (indexSet & (1 << j) != 0) {
                    payoutNumerator =
                        payoutNumerator +
                        payoutNumerators[conditionId][j];
                }
            }

            uint256 payoutStake = balanceOf(msg.sender, positionId);
            if (payoutStake > 0) {
                totalPayout =
                    totalPayout +
                    (payoutStake * payoutNumerator) /
                    den;
                _burn(msg.sender, positionId, payoutStake);
            }
        }

        if (totalPayout > 0) {
            require(
                collateralToken.transfer(msg.sender, totalPayout),
                "could not transfer payout to message sender"
            );
        }
        emit PayoutRedemption(
            msg.sender,
            collateralToken,
            conditionId,
            indexSets,
            totalPayout
        );
    }

    /// @dev Gets the outcome slot count of a condition.
    /// @param conditionId ID of the condition.

    function getOutcomeSlotCount(
        bytes32 conditionId
    ) external view returns (uint256) {
        return payoutNumerators[conditionId].length;
    }

    /// @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    /// @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
    function getConditionId(
        address oracle,
        bytes32 questionId,
        uint256 outcomeSlotCount
    ) external pure returns (bytes32) {
        return CTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
    }

    /// @dev Constructs an outcome collection ID from a parent collection and an outcome collection.
    /// @param conditionId Condition ID of the outcome collection to combine with the parent outcome collection.
    /// @param indexSet Index set of the outcome collection to combine with the parent outcome collection.
    function getCollectionId(
        bytes32 conditionId,
        uint256 indexSet
    ) external pure returns (bytes32) {
        return CTHelpers.getCollectionId(conditionId, indexSet);
    }

    /// @dev Constructs a position ID from a collateral token and an outcome collection. These IDs are used as the ERC-1155 ID for this contract.
    /// @param collateralToken Collateral token which backs the position.
    /// @param collectionId ID of the outcome collection associated with this position.
    function getPositionId(
        IERC20 collateralToken,
        bytes32 collectionId
    ) external pure returns (uint256) {
        return CTHelpers.getPositionId(collateralToken, collectionId);
    }
}
