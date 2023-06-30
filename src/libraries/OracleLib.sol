// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Thomas Heim
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
 * We want the DSCEngine to freeze if prices become stale.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    /**
     * @notice Checks the latest round data from the Chainlink Oracle feed.
     * Reverts if the data is stale, rendering the DSCEngine unusable.
     * @param chainlinkFeed The Chainlink Oracle feed to check.
     * @return roundId The round ID.
     * @return answer The price answer.
     * @return startedAt The timestamp when the round started.
     * @return updatedAt The timestamp when the data was last updated.
     * @return answeredInRound The round ID when the answer was computed.
     */
    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /**
     * @notice Returns the timeout value used to determine stale data.
     * @return The timeout value in seconds.
     */
    function getTimeout(AggregatorV3Interface /* chainlinkFeed */) public pure returns (uint256) {
        return TIMEOUT;
    }
}
