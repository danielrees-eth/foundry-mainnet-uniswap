// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

// import interfaces
import { ISwapRouter } from "v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IERC20 } from "oz-contracts/token/ERC20/IERC20.sol";

// import constants
import { ROUTER, POOL_FEE } from "./helpers/Constants.sol";

///@notice Trader contract executes trades on Uniswap
contract UniTrader { 
    // swap params struct
    ISwapRouter.ExactInputSingleParams exactInputSingleParams;
    
    ///@notice Executes a trade on Uniswap V3
    ///@dev ROUTER address is needed. POOL_FEE must be 3000.
    ///@param tokenIn address of token to be traded
    ///@param tokenOut address of token to be recieved
    ///@param amountIn amount of token to be traded
    function trade(address tokenIn, address tokenOut, uint256 amountIn) public {
        // trader must have pre-approval from owner to transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // trader must approve router to spend 
        IERC20(tokenIn).approve(ROUTER, type(uint256).max);
        
        // set swap params
        exactInputSingleParams = ISwapRouter.ExactInputSingleParams(
            tokenIn,                           // tokenIn
            tokenOut,                          // tokenOut
            POOL_FEE,                           // fee
            msg.sender,                         // recipient;
            uint256(block.timestamp + 60*60*1), // deadline
            amountIn,                          // amountIn
            0,                                  // amountOutMinimum
            0                                   // sqrtPriceLimit
        );

        // call: SwapRouter.exactInputSingle()
        ISwapRouter(ROUTER).exactInputSingle(exactInputSingleParams);
    }  
}
