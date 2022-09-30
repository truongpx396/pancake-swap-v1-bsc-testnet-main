pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;


interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IERC20 {
  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function name() external view returns (string memory);
  function getOwner() external view returns (address);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address _owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IMasterChef{
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }

     // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    function poolInfo(uint256 key) external view returns (PoolInfo memory);

    function userInfo(uint256 key,address userAddress) external view returns (UserInfo memory);

    function pendingSushi(uint256 pid, address user) external view returns (uint256);

}

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)
library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

contract PancakeLibraryUtils {
    using SafeMath for uint;

    struct PoolInfo {
        address poolAddress;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        uint256 userBalance;
    }

    struct FarmingInfo {
        IERC20 lpToken;
        uint256 totalStakedAmount;
        uint256 userStakedAmount;     
        uint256 userPendingReward;
        uint256 poolAllocPoint; 
        uint256 poolAccRewardPerShare;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) public pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                //hex'd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66' // init code hash
                hex'ced7c507bf75a9c4a42a9c14d582db9f48b2de7a90ccc86d338a41f541fe4f53'   // Change to INIT_CODE_PAIR_HASH of Pancake Factory
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        pairFor(factory, tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPancakePair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getReservesWithPoolAddress(address factory, address tokenA, address tokenB) public view returns (address poolAddress,uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        poolAddress = pairFor(factory, tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPancakePair(poolAddress).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getReservesWithPoolAddressAndUserBalance(address factory, address tokenA, address tokenB, address userAddress) public view returns (address poolAddress,uint reserveA, uint reserveB, uint totalSupply, uint userBalance) {
        (address token0,) = sortTokens(tokenA, tokenB);
        poolAddress = pairFor(factory, tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPancakePair(poolAddress).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        totalSupply = IPancakePair(poolAddress).totalSupply();
        userBalance = IPancakePair(poolAddress).balanceOf(userAddress);
    }

    function getPoolInfo(address factory, address tokenA, address tokenB, address userAddress) public view returns (PoolInfo memory poolInfo) {
         (address token0,) = sortTokens(tokenA, tokenB);
        address poolAddress = pairFor(factory, tokenA, tokenB);
        poolInfo.poolAddress=poolAddress;
        (uint reserve0, uint reserve1,) = IPancakePair(poolAddress).getReserves();
        (poolInfo.reserveA, poolInfo.reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        poolInfo.totalSupply = IPancakePair(poolAddress).totalSupply();
        poolInfo.userBalance = IPancakePair(poolAddress).balanceOf(userAddress);
    }

    function getFarmingInfo(address masterChef, uint256 poolId,address userAddress) public view returns (FarmingInfo memory farmingInfo) {
        IMasterChef.UserInfo memory userInfo= IMasterChef(masterChef).userInfo(poolId,userAddress);
        farmingInfo.userStakedAmount = userInfo.amount;
        farmingInfo.userPendingReward=IMasterChef(masterChef).pendingSushi(poolId,userAddress);
        farmingInfo.lpToken=IMasterChef(masterChef).poolInfo(poolId).lpToken;
        farmingInfo.totalStakedAmount=farmingInfo.lpToken.balanceOf(masterChef);
        farmingInfo.poolAllocPoint=IMasterChef(masterChef).poolInfo(poolId).allocPoint;
        farmingInfo.poolAccRewardPerShare=IMasterChef(masterChef).poolInfo(poolId).accSushiPerShare;
    }

    function getFarmingData(address factory, address tokenA, address tokenB, address userAddress,address masterChef,uint256 poolId) public view returns (PoolInfo memory poolInfo,FarmingInfo memory farmingInfo) {
         (address token0,) = sortTokens(tokenA, tokenB);
        address poolAddress = pairFor(factory, tokenA, tokenB);
        poolInfo.poolAddress=poolAddress;
        (uint reserve0, uint reserve1,) = IPancakePair(poolAddress).getReserves();
        (poolInfo.reserveA, poolInfo.reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        poolInfo.totalSupply = IPancakePair(poolAddress).totalSupply();
        poolInfo.userBalance = IPancakePair(poolAddress).balanceOf(userAddress);
        
        farmingInfo=getFarmingInfo(masterChef,poolId,userAddress);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, 'PancakeLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, 'PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(998);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure returns (uint amountIn) {
        require(amountOut > 0, 'PancakeLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(998);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}