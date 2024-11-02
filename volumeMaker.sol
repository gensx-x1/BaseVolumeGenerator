// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;


import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";


interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


contract volumeGenerator is IFlashLoanRecipient {

    uint256 private constant MAX_UINT = type(uint256).max;
    IWETH private weth = IWETH(0x4200000000000000000000000000000000000006);
    IUniswapV2Router02 private uni_router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);

    // balancer vault
    IVault private constant vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "nah");
        _;
    }

    constructor() {
        weth.approve(address(uni_router), MAX_UINT);
        owner = msg.sender;
    }





    function generateVolume(uint256 borrowAmount, address volumeToken) public payable {
        uint256[] memory borrowAmounts = new uint256[](1);
        borrowAmounts[0] = borrowAmount;
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(address(weth));
        bytes memory userData = abi.encode(volumeToken);

        vault.flashLoan(this, tokens, borrowAmounts, userData);

    }



    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault));
        (address volumeToken) = abi.decode(userData, (address));


        uint256 amountIn = amounts[0];
        IERC20(volumeToken).approve(address(uni_router), MAX_UINT);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(volumeToken);
        weth.withdraw(amountIn);
        uni_router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
                    1,
                    path,
                    address(this),
                    block.timestamp
        );
        path[1] = address(weth);
        path[0] = address(volumeToken);
        uni_router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                    IERC20(volumeToken).balanceOf(address(this)),
                    1,
                    path,
                    address(this),
                    block.timestamp
        );

        weth.deposit{value: amountIn}();
        weth.transfer(address(vault), amountIn);
        uint256 w_b = weth.balanceOf(address(this));
        if (w_b > 0){
            weth.withdraw(w_b);
        }
        if (address(this).balance >0 ){
            payable(owner).transfer(address(this).balance);
        }
        
    }


    function checkTransactionCost(address token, uint256 amountIn_) public view returns(uint256 swapFee) {
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = address(token);
            uint256 tokenBalance = uni_router.getAmountsOut(amountIn_, path)[1];
            path[1] = address(weth);
            path[0] = address(token);
            uint256 returnAmount = uni_router.getAmountsOut(tokenBalance, path)[1];
            uint fee = (amountIn_ - returnAmount);
            return fee;
    }

    receive() external payable {}

    fallback() external payable {}


    function withdrawToken(IERC20 token) external onlyOwner {
        token.transfer(owner, token.balanceOf(address(this)));
    }

    function withdrawETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function kill() external onlyOwner {
        selfdestruct(payable(owner));
    }


}
