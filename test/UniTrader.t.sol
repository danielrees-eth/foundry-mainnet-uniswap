// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

// import dependencies
import { DSTest }               from "ds-test/test.sol";
import { IERC20 }               from "oz-contracts/token/ERC20/IERC20.sol";

// import interfaces
import { IUniswapV3Pool }       from 'v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import { ISwapRouter }          from "v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IQuoter }              from "v3-periphery/contracts/interfaces/IQuoter.sol";
import { IWETH9 }               from "./helpers/IWETH9.sol"; 
// NOTE: unable to compile with v3-periphery IWETH9 (solc 0.7.6)

// import events
import { IUniswapV3PoolEvents } from "v3-core/contracts/interfaces/pool/IUniswapV3PoolEvents.sol";

// import helpers
import { CheatCodes}            from "./helpers/CheatCodes.sol";
import { 
    ROUTER, 
    QUOTER, 
    WETH, 
    DAI, 
    VB, 
    POOL_FEE, 
    POOL 
    }                           from "../src/helpers/Constants.sol";

// import contract to be tested
import { UniTrader }            from "../src/UniTrader.sol";

///@notice Test contract for UniTrader.sol
contract UniTraderTest is DSTest, IUniswapV3PoolEvents {

    // contract to be tested
    UniTrader trader;
    
    // uniswap params struct
    ISwapRouter.ExactInputSingleParams exactInputSingleParams;

    // ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // Initialize HEVM with CheatCodes
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    ///@notice setup protocol executed before each test
    ///@dev deposit WETH into VB wallet, assumes ETH balance >= 1000. 
    ///@dev pre-approve trader to spend VB WETH
    ///@dev label important addresses
    function setUp() public {
    
        // deploy test contract 
        trader = new UniTrader();

        // load WETH in VB wallet
        _depositWeth(1000);

        // approve trader to spend VB WETH
        evm.prank(VB);
        IERC20(WETH).approve(address(trader), type(uint256).max);
        
        // label addresses for easy debugging in call traces
        evm.label(ROUTER,   "0xROUTER");
        evm.label(WETH,     "0xWETH");
        evm.label(DAI,      "0xDAI");
        evm.label(VB,       "0xVB");
        evm.label(POOL,     "0xPOOL");
    }
    
    //
    // SIMPLE INTEGRATION TEST
    // 

    ///@notice test for UniswapTrader.trade() 
    ///@dev subcall to SwapRouter.exactInputSingle()
    function testTradeAll() public {
        // initial token balances
        // NOTE: initial weth balance must be non-zero
        uint256 daiBalance0 = IERC20(DAI).balanceOf(VB);
        uint256 wethBalance0 = IERC20(WETH).balanceOf(VB);
        assertGt(wethBalance0, 0);
        
        // quote dai amount
        uint256 daiAmount = _quoteDaiForWeth(wethBalance0);

        // set expected subcalls and emits
        _trade_expectedSubcalls(WETH, DAI, wethBalance0);
        _trade_expectedEmits(wethBalance0, daiAmount);
        
        // trade entire WETH balance for DAI
        evm.prank(VB);
        trader.trade(WETH, DAI, wethBalance0);

        // check token balances
        uint256 daiBalance1 = IERC20(DAI).balanceOf(VB);
        uint256 wethBalance1 = IERC20(WETH).balanceOf(VB);
        assertEq(daiBalance1, daiBalance0 + daiAmount);
        assertEq(wethBalance1, 0);

        // check dai recieved

    }
    
    //
    // FUZZ INTEGRATION TEST
    //

    ///@notice test call: UniswapTrader.tradeWethForDai() 
    ///@dev function calls SwapRouter.exactInputSingle()
    ///@param wethAmount amount of weth to be swapped
    function testTradeFuzz(uint256 wethAmount) public {
        // initial token balances
        // NOTE: weth balance must be non-zero
        uint256 daiBalance0 = IERC20(DAI).balanceOf(VB);
        uint256 wethBalance0 = IERC20(WETH).balanceOf(VB);
        assertGt(wethBalance0, 0);
                
        // check revert conditions
        bool success;
        // revert condition 1: VB does not have enough WETH
        if (wethAmount > wethBalance0) {
            evm.expectRevert();
        // revert condition 2: amount is zero
        } else if (wethAmount == 0) {
            evm.expectRevert(bytes("AS"));
        // otherwise success
        } else {
            success = true;
        }
        
        uint256 daiAmount;
        if (success) {
            // quote dai amount
            daiAmount = _quoteDaiForWeth(wethAmount);

            // set expected subcalls and emits
            _trade_expectedSubcalls(WETH, DAI, wethAmount);
            _trade_expectedEmits(wethAmount, daiAmount);
        }
        
        // trade WETH for DAI
        evm.prank(VB);
        trader.trade(WETH, DAI, wethAmount);

        // check weth spend
        if (success) {
            uint256 daiBalance1 = IERC20(DAI).balanceOf(VB);
            uint256 wethBalance1 = IERC20(WETH).balanceOf(VB);
            assertEq(daiBalance1, daiBalance0 + daiAmount);
            assertEq(wethBalance1, wethBalance0 - wethAmount);
        } 
    }
    
    //
    // INTERNAL HELPER FUNCTIONS
    //

    function _depositWeth(uint256 ethAmount) internal {
        // check that VB has no WETH balance
        // NOTE: this assumption may change based on VB mainnet activity
        uint256 wethBalance0 = IERC20(WETH).balanceOf(VB);
        assertEq(wethBalance0, 0);

        // deposit WETH in VB wallet
        // NOTE: assumes that VB has at least this amount of ETH
        evm.prank(VB);
        IWETH9(WETH).deposit{value: ethAmount}();
    }

    function _trade_expectedSubcalls(address tokenIn, address tokenOut, uint256 amountIn) internal {

        // expected call 1
        bytes memory callData1 = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            VB,
            address(trader),
            amountIn
        );
        evm.expectCall(tokenIn, callData1);
        
        // NOTE: foundry only supports check for first subcall
        /*
        // expected call 2
        exactInputSingleParams = ISwapRouter.ExactInputSingleParams(
            tokenIn,                            // tokenIn
            tokenOut,                           // tokenOut
            uint24(3000),                       // fee
            msg.sender,                         // recipient;
            uint256(block.timestamp + 60*60*1), // deadline
            amountIn,                             // amountIn
            0,                                  // amountOutMinimum
            0                                   // sqrtPriceLimit
        );
        bytes memory callData2 = abi.encodeWithSelector(
            ISwapRouter.exactInputSingle.selector,
            exactInputSingleParams
        );
        evm.expectCall(ROUTER, callData2);
        */
        
    }

    ///@notice queues expected events for UniTrader.tradeWethForDai() call
    ///@dev call expectEmit, then emit expected event, then call the tested function
    ///@param amountIn amountIn to be swapped
    ///@param amountOut amountOut to be recieved
    function _trade_expectedEmits(uint256 amountIn, uint256 amountOut) internal {

        // weth.transferFrom() VB --> trader
        evm.expectEmit(true, true, true, true);
        emit Transfer(VB, address(trader), amountIn);

        // weth.approve() ROUTER for trader
        evm.expectEmit(true, true, true, true);
        emit Approval(address(trader), ROUTER, type(uint256).max);
        
        // dai.transferFrom() POOL --> VB
        // NOTE: no transfer if tokenOut amount is zero
        if (amountOut > 0) {
            evm.expectEmit(true, true, true, true);
            emit Transfer(POOL, VB, amountOut);
        }
        
        // weth.transferFrom() trader --> POOL
        evm.expectEmit(true, true, true, true);
        emit Transfer(address(trader), POOL, amountIn);
        
        // UniswapV3Pool.swap() WETH --> DAI
        // NOTE: check ignores event data
        int256 negOutAmount = 0 - int256(amountOut);
        evm.expectEmit(true, true, true, false);
        emit Swap(ROUTER, VB, negOutAmount, int256(amountIn), 0, 0, 0);
    }
 
    ///@notice generates a quote in DAI for an exact amount of WETH input on uniswap v3
    ///@param wethAmount exact amount of weth to be swapped
    function _quoteDaiForWeth(uint256 wethAmount) internal returns (uint256 daiAmount) {
        daiAmount = IQuoter(QUOTER).quoteExactInputSingle(
            WETH,
            DAI,
            POOL_FEE,
            wethAmount,
            0 
        );
    }
}
