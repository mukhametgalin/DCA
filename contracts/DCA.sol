// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function WETH() external pure returns (address);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DCAContract {
    address public owner;
    IUniswapV2Router public uniswapRouter;

    enum DCAType { BUY, SELL }

    struct DCA {
        address user;
        address token;
        uint256 interval;
        uint256 amount;
        uint256 lastExecution;
        DCAType dcaType;
    }

    mapping(address => DCA) public dcaStrategies;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _uniswapRouter) {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }

    function createDCA(
        address _token,
        uint256 _interval,
        uint256 _amount,
        DCAType _dcaType
    ) external payable returns (address strategyAddress) {
        require(_amount > 0, "Invalid amount");
        strategyAddress = address(uint160(uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, _token)))));
        dcaStrategies[strategyAddress] = DCA({
            user: msg.sender,
            token: _token,
            interval: _interval,
            amount: _amount,
            lastExecution: 0,
            dcaType: _dcaType
        });
    }

    function executeDCA(address strategyAddress) external {
        DCA storage dca = dcaStrategies[strategyAddress];
        require(dca.user != address(0), "DCA does not exist");
        require(block.timestamp >= dca.lastExecution + dca.interval, "Interval not reached");

        if (dca.dcaType == DCAType.BUY) {
            _executeBuy(dca);
        } else {
            _executeSell(dca);
        }

        dca.lastExecution = block.timestamp;
    }

    function _executeBuy(DCA storage dca) internal {
        require(address(this).balance >= dca.amount, "Not enough ETH in the contract");
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = dca.token;

        uniswapRouter.swapExactETHForTokens{value: dca.amount}(
            0,
            path,
            dca.user,
            block.timestamp + 300
        );
    }

    function _executeSell(DCA storage dca) internal {
        uint256 tokenBalance = IERC20(dca.token).balanceOf(address(this));
        require(tokenBalance >= dca.amount, "Insufficient token balance");

        IERC20(dca.token).approve(address(uniswapRouter), dca.amount);

        address[] memory path = new address[](2);
        path[0] = dca.token;
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETH(
            dca.amount,
            0,
            path,
            dca.user,
            block.timestamp + 300
        );
    }

    function withdrawFunds(address strategyAddress) external {
        DCA storage dca = dcaStrategies[strategyAddress];
        require(dca.user == msg.sender, "Not authorized");
        require(dca.user != address(0), "DCA does not exist");

        if (dca.dcaType == DCAType.BUY) {
            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) {
                payable(msg.sender).transfer(ethBalance);
            }
        } else if (dca.dcaType == DCAType.SELL) {
            uint256 tokenBalance = IERC20(dca.token).balanceOf(address(this));
            if (tokenBalance > 0) {
                IERC20(dca.token).transfer(msg.sender, tokenBalance);
            }
        }

        delete dcaStrategies[strategyAddress];
    }

    function updateRouterAddress(address newUniswapRouter) external onlyOwner {
        require(newUniswapRouter != address(0), "Invalid address");
        uniswapRouter = IUniswapV2Router(newUniswapRouter);
    }
}
