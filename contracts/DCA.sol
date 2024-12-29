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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
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
        address depositAddress;
        uint256 totalIterations;
        uint256 completedIterations;
    }

    mapping(address => mapping(address => address)) public userDepositAddresses;
    mapping(address => DCA) public dcaStrategies;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyDepositAddress(address strategyAddress) {
        require(msg.sender == dcaStrategies[strategyAddress].depositAddress, "Not authorized");
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
        DCAType _dcaType,
        address _depositAddress,
        uint256 _totalIterations
    ) external returns (address strategyAddress) {
        require(_amount > 0, "Invalid amount");
        require(_token != address(0) && _token != uniswapRouter.WETH(), "Token cannot be ETH");
        require(_totalIterations > 0, "Total iterations must be greater than 0");
        require(userDepositAddresses[msg.sender][_token] == _depositAddress || userDepositAddresses[msg.sender][_token] == address(0), "Deposit address mismatch");

        if (userDepositAddresses[msg.sender][_token] == address(0)) {
            userDepositAddresses[msg.sender][_token] = _depositAddress;
        }

        strategyAddress = address(uint160(uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, _token)))));

        dcaStrategies[strategyAddress] = DCA({
            user: msg.sender,
            token: _token,
            interval: _interval,
            amount: _amount,
            lastExecution: 0,
            dcaType: _dcaType,
            depositAddress: _depositAddress,
            totalIterations: _totalIterations,
            completedIterations: 0
        });

        bool success = IERC20(_token).transferFrom(msg.sender, _depositAddress, _amount * _totalIterations);
        if (!success) {
            delete dcaStrategies[strategyAddress];
            revert("Token transfer failed");
        }
    }

    function executeDCA(address strategyAddress) external onlyDepositAddress(strategyAddress) {
        DCA storage dca = dcaStrategies[strategyAddress];
        require(dca.user != address(0), "DCA does not exist");
        require(block.timestamp >= dca.lastExecution + dca.interval, "Interval not reached");
        require(dca.completedIterations < dca.totalIterations, "All iterations completed");

        if (dca.dcaType == DCAType.BUY) {
            _executeBuy(dca);
        } else {
            _executeSell(dca);
        }

        dca.lastExecution = block.timestamp;
        dca.completedIterations++;
    }

    function _executeBuy(DCA storage dca) internal {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = dca.token;

        uint256 initialBalance = IERC20(dca.token).balanceOf(dca.depositAddress);

        uniswapRouter.swapExactETHForTokens{value: dca.amount}(
            0,
            path,
            dca.depositAddress,
            block.timestamp + 300
        );

        uint256 newBalance = IERC20(dca.token).balanceOf(dca.depositAddress);
        uint256 receivedTokens = newBalance - initialBalance;

        require(receivedTokens > 0, "No tokens received");

        bool success = IERC20(dca.token).transferFrom(dca.depositAddress, dca.user, receivedTokens);
        require(success, "Token transfer to user failed");
    }

    function _executeSell(DCA storage dca) internal {
        uint256 tokenBalance = IERC20(dca.token).balanceOf(dca.depositAddress);
        require(tokenBalance >= dca.amount, "Insufficient token balance");

        IERC20(dca.token).approve(address(uniswapRouter), dca.amount);

        address[] memory path = new address[](2);
        path[0] = dca.token;
        path[1] = uniswapRouter.WETH();

        uint256 initialBalance = address(dca.depositAddress).balance;

        uniswapRouter.swapExactTokensForETH(
            dca.amount,
            0,
            path,
            dca.depositAddress,
            block.timestamp + 300
        );

        uint256 toTransfer = address(dca.depositAddress).balance - initialBalance;
        require(toTransfer > 0, "No ETH received");
        address payable recipient = payable(dca.user);
        recipient.transfer(toTransfer);

    }

    function withdrawFunds(address strategyAddress) external onlyDepositAddress(strategyAddress) {
        DCA storage dca = dcaStrategies[strategyAddress];
        require(dca.user != address(0), "DCA does not exist");

        if (dca.dcaType == DCAType.BUY) {
            uint256 ethBalance = address(dca.depositAddress).balance;
            if (ethBalance > 0) {
                payable(dca.user).transfer(ethBalance);
            }
        } else if (dca.dcaType == DCAType.SELL) {
            uint256 tokenBalance = IERC20(dca.token).balanceOf(address(dca.depositAddress));
            if (tokenBalance > 0) {
                IERC20(dca.token).transferFrom(dca.depositAddress, dca.user, tokenBalance);
            }
        }

        delete dcaStrategies[strategyAddress];
    }

    function updateRouterAddress(address newUniswapRouter) external onlyOwner {
        require(newUniswapRouter != address(0), "Invalid address");
        uniswapRouter = IUniswapV2Router(newUniswapRouter);
    }
}
