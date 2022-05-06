// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);
}

interface IVyper_contract {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface CheatCodes {
    function prank(address) external;
}


interface IMetaSwap {
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
}
contract ContractTest is DSTest {

    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IERC20 public susd = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);

    IERC20 public Saddle_DAI_USDC_USDT_V2 = IERC20(0x5f86558387293b6009d7896A61fcc86C17808D62);

    IVyper_contract  Curve_fi_sUSD_v2_Swap = IVyper_contract(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);

    IMetaSwap metaswap  = IMetaSwap(0x824dcD7b044D60df2e89B1bB888e66D8BCf41491);

    function test() public{

        cheat.prank(0x27182842E098f60e3D576794A5bFFb0777E025d3);

        usdc.transfer(address(this), 15000000000000);

        emit log_named_uint("Borrow USDC from Euler",usdc.balanceOf(address(this)));

        usdc.approve(address(Curve_fi_sUSD_v2_Swap), type(uint256).max);

        Curve_fi_sUSD_v2_Swap.exchange(1, 3, 15000000000000, 0);

        uint256 susd_balance = susd.balanceOf(address(this));

        emit log_named_uint("SUSD Balance after exchanging from Curve",susd_balance);

        susd.approve(address(metaswap),type(uint256).max);

        metaswap.swap(0, 1, susd_balance, 0, block.timestamp);

        uint256  Saddle_DAI_USDC_USDT_V2_Balance =  Saddle_DAI_USDC_USDT_V2.balanceOf(address(this));

        emit log_named_uint("Saddle_DAI_USDC_USDT_V2 Balance after swapping",Saddle_DAI_USDC_USDT_V2_Balance);

        Saddle_DAI_USDC_USDT_V2.approve(address(metaswap), type(uint256).max);

        metaswap.swap(1, 0, Saddle_DAI_USDC_USDT_V2_Balance, 0, block.timestamp);

        susd_balance = susd.balanceOf(address(this));

        emit log_named_uint("SUSD Balance after swapping back",susd_balance);

    }

}
