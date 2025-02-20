//SPDX-License-Identifier: TBD

pragma solidity 0.8.20;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {Pair} from "../src/PairContract.sol";
import {FakeToken} from "./util/fakeToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract PairTest is Test {
    using SafeERC20 for IERC20;

    Pair pair;
    IERC20 baseToken;
    IERC20 quoteToken;

    address constant TOKEN_HOLDER = address(0x123);
    address constant GOVERNANCE_TREASURY = address(0x456);

    address constant USER_1 = address(0x789);
    address constant USER_2 = address(0xabc);

    function setUp() public {
        baseToken = new FakeToken("BASE", "BT", TOKEN_HOLDER, 18, 1000 * 10 ** 18);
        quoteToken = new FakeToken("QUOTE", "QT", TOKEN_HOLDER, 6, 30_000_000 * 10 ** 6);

        uint24 makerFee_ = 10;
        uint24 takerFee_ = 20;

        uint256 priceStep = 5 * 10 ** 6; // 5 USDT

        unit256 initialPricePoint = 2000 * 10 ** 6; // 2000 USDT

        pair = new Pair(
            address(baseToken),
            address(quoteToken),
            priceStep,
            makerFee_,
            takerFee_,
            GOVERNANCE_TREASURY
        );
    }

    function test_InsertLimitOrder() public {
        /// @NOTE Scenario 1 => Insert a limit maker order in buy side.
        /// Acceptance Criteria:
        ///      - Token transferred to the contract with the correct amount.
        ///      - Order get located in the orders Mapping with 0 orderID.
        ///      - Order get placed in the first position of  pricePoint
        ///      - PricePoint get updated correctly.
        ///      - check orderID 0 struct to check all the values are correct.
        ///      - check the event is emitted correctly.
        ///      - in the last step we should check the orderID is incremented correctly.

        /// TOKEN TRANSFER
        vm.startPrank(TOKEN_HOLDER);
        quoteToken.safeTransfer(USER_1, 10_000_000 * 10 ** 6);
        vm.stopPrank();

        /// TOKEN APPROVE AND INSERT LIMIT ORDER
        vm.startPrank(USER_1);

        bool isBuy = true;
        uint256 price = 2000 * 10 ** 6; // 2000 USDT
        uint256 amount = 1 ether;

        quoteToken.safeIncreaseAllowance(address(pair), price * amount);

        pair.insertLimitOrder(isBuy, price, amount);

        vm.stopPrank();

        /// @NOTE Scenario 2 => Insert another limit maker order in buy side.
        /// Acceptance Criteria:
        ///      - The same checks as scenario 1.

        /// @NOTE Scenario 3 => Insert a limit maker order in sell side.
        /// Acceptance Criteria:
        ///      - The same checks as scenario 1.

        /// @NOTE Scenario 4 => Insert another limit maker order in sell side.
        /// Acceptance Criteria:
        ///      - The same checks as scenario 1.

        /// @NOTE Scenario 5 => Insert a limit taker order in buy side.
        /// Acceptance Criteria:
        ///      - The all checks in the scenario 1 should get passed.
        ///      - user should receive the correct amount of baseToken for getting matched
        ///      - the pricePoint should update correctly in both sides.
        ///      - latestPricePoint should update correctly.

        /// @NOTE Scenario 6 => Insert a limit taker order in sell side.
        /// Acceptance Criteria:
        ///      - The all checks in the scenario 1 should get passed.
        ///      - user should receive the correct amount of quoteToken for getting matched
        ///      - the pricePoint should update correctly in both sides.
        ///      - latestPricePoint should update correctly.
    }

    function test_MarketOrder() public {
        /// @NOTE Scenario 1 => Insert a market maker order in buy side.
        /// Pre-requisite:
        ///      - Insert a limit order in sell side.
        /// Acceptance Criteria:
        ///      - Token transferred to the contract with the correct amount.
        ///      - the baseToken should get transferred to the user address.
        ///      - fee should calculate correctly based on the TakerFee.
        ///      - the latestPricePoint should update correctly.
        ///      - the pricePoint should update correctly.
        ///      - the orderID should get incremented correctly.

        /// Pre-requisite
        vm.startPrank(TOKEN_HOLDER);
        baseToken.safeTransfer(USER_1, 5 * 10 ** 18);
        quoteToken.safeTransfer(USER_2, 10000 * 10 ** 6);

        vm.stopPrank();

        /// @NOTE Insert a limit order in sell side.
        vm.startPrank(USER_1);

        bool isBuy = false;
        uint256 price = 2000 * 10 ** 6; // 2000 USDT
        uint256 amount = 1 * 10 ** 18;

        baseToken.safeIncreaseAllowance(address(pair), amount);

        pair.insertLimitOrder(isBuy, price, amount);

        uint256 newPrice = 2005 * 10 ** 6; // 2010 USDT
        pair.insertMarketOrder(isBuy, newPrice, amount);

        vm.stopPrank();

        /// @NOTE Insert a market maker order in buy side.
        vm.startPrank(USER_2);

        uint256 worstPrice = 2100 * 10 ** 6; // 2000 USDT
        uint256 marketOrder = 2 ether;
        bool marketOrderIsBuy = true;

        pair.insertMarketOrder(marketOrderIsBuy, marketOrder, worstPrice);

        vm.stopPrank();
        /// @NOTE Scenario 2 => Insert a market maker order in sell side.
        /// Pre-requisite:
        ///      - Insert a limit order in buy side.
        /// Acceptance Criteria:
        ///      - Token transferred to the contract with the correct amount.
        ///      - the quoteToken should get transferred to the user address.
        ///      - fee should calculate correctly based on the TakerFee.
        ///      - the latestPricePoint should update correctly.
        ///      - the pricePoint should update correctly.
        ///      - the orderID should get incremented correctly.
    }

    function test_CancelOrder() public {
        /// @NOTE Scenario 1 => Cancel a non filled limit order in buy side.
        /// Pre-requisite:
        ///      - Insert a limit order in buy side.
        /// Acceptance Criteria:
        ///      - Update the order status to cancelled.
        ///      - Transfer the token back to the user address.
        ///      - Update the pricePoint correctly.
        ///      - Update the latestPricePoint correctly.
        ///      - Update the cancellation trees correctly.
        ///      - Emit the correct event.

        /// @NOTE Scenario 2 => Cancel a partially filled limit order in sell side.
        /// Pre-requisite:
        ///      - Insert a limit order in sell side.
        ///      - Insert market order in buy to fill the limit order partially.
        /// Acceptance Criteria:
        ///      - the scenario 1 checks should get passed.
        ///      - the claim should happen for the filled amount.
        ///      - the base token should get transferred to the user address for claim.
        ///      - the maker fee should get reduced from the claim amount.

        /// @NOTE Scenario 3 => Cancel a fully filled limit order in buy side.
        /// Pre-requisite:
        ///      - Insert a limit order in buy side.
        ///      - Insert market order in sell to fill the limit order fully.
        /// Acceptance Criteria:
        ///      - the scenario 1 checks should get passed.
        ///      - the claim should happen for the filled amount.
        ///      - the quote token should get transferred to the user address for claim.
        ///      - the maker fee should get reduced from the claim amount.
    }

    function test_ClaimOrder() public {
        // @NOTE Scenario 1 => Claim a fully filled limit order in buy side.
        /// Pre-requisite:
        ///      - Insert a limit order in buy side.
        ///      - Insert market order in sell to fill the limit order fully.
        /// Acceptance Criteria:
        ///      - the claim should happen for the filled amount.
        ///      - the base token should get transferred to the user address for claim.
        ///      - the maker fee should get reduced from the claim amount.
        ///      - the order status should get updated to claimed.
        ///      - the pricePoint should get updated correctly.
        ///      - the correct event should get emitted.
    }
}
