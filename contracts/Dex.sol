// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.1;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
//import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title DEX Project
 * @dev Decentralized exchange example, used for trading tokens peer-to-peer
 */


contract Dex {
    
    //using SafeMath for uint;
    
    enum Side {
        BUY,
        SELL
    }

    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    
    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint filled;
        uint price;
        uint date;
    }
    
    bytes32[] public tokenList;
    bytes32 constant DAI = bytes32('DAI');
    mapping(bytes32 => Token) public tokens;
    mapping(address => mapping(bytes32 => uint)) public traderBalances;
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;
    address public admin;
    uint public nextOrderId;
    uint public nextTradeId;
    
    /**
    * @dev Event for front end to pick up usable data from each trade
    */
    
    event NewTrade(uint tradeId, uint orderId, bytes32 indexed ticker, address indexed trader1, address indexed trader2, uint amount, uint price, uint date);
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @dev function to add token to registry, Admin only
     */
     
    function addToken(bytes32 ticker, address tokenAddress) onlyAdmin() external {
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }
    
    /**
     * @dev Function used to deposit tokens for trading into DEX "wallet"
     */
     
    function deposit(uint amount, bytes32 ticker) tokenExist(ticker) external {
        
        IERC20(tokens[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount);
        
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker] + (amount);
        
    }
    
    /**
     * @dev Used to withdraw funds to an external wallet, requires msg.sender to possess the funds
     */
     
    function withdraw( uint amount, bytes32 ticker) tokenExist(ticker) external {
        require(traderBalances[msg.sender][ticker] >= amount, 'Balance is too low');
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker] - (amount);
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }
    
    /**
     * @dev Function to create Limit Order trades, requires msg.sender to have specified funds
     */
     
    function createLimitOrder(bytes32 ticker, uint amount, uint price, Side side) tokenExist(ticker) tokenIsNotDai(ticker) external {
        if(side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, 'Token balance too low');
        } else {
            require(traderBalances[msg.sender][DAI] >= (amount * price), 'DAI balance too low');
        }
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(
            nextOrderId,
            msg.sender,
            side,
            ticker,
            amount,
            0,
            price,
            block.timestamp
        ));
        
        uint i = orders.length > 0 ? orders.length - 1 : 0;
        while(i > 0) {
            if(side == Side.BUY && orders[i - 1].price > orders[i].price) {
                break;
            }
            if(side == Side.SELL && orders[i - 1].price < orders[i].price) {
                break;
            }
            Order memory order = orders[i - 1];
            orders[i - 1] = orders[i];
            orders[i] = order;
            i--;
        }
        nextOrderId++;
    }
    
    /**
     * @dev Function to create Market Order trades, requires msg.sender to possess correct funds
     */
    
    function createMarketOrder(bytes32 ticker, uint amount, Side side) tokenExist(ticker) tokenIsNotDai(ticker) external {
        if(side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, 'Balance is too low');
        }
        
        Order[] storage orders = orderBook[ticker][uint(side == Side.BUY ? Side.SELL : Side.BUY)];
        uint i;
        uint remaining = amount;
        
        while(i < orders.length && remaining > 0) {
            uint available = orders[i].amount - (orders[i].filled);
            uint matched = (remaining > available) ? available : remaining;
            remaining = (remaining - matched);
            orders[i].filled = (orders[i].filled + matched);
            
            emit NewTrade(nextTradeId, orders[i].id, ticker, orders[i].trader, msg.sender, matched, orders[i].price, block.timestamp);
            
            if(side == Side.SELL) {
                traderBalances[msg.sender][ticker] = (traderBalances[msg.sender][ticker] - matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][DAI] + (matched * orders[i].price);
                traderBalances[orders[i].trader][ticker] = (traderBalances[msg.sender][ticker] + matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[orders[i].trader][DAI] - (matched * (orders[i].price));
            }
            
            if(side == Side.BUY) {
                require(traderBalances[msg.sender][DAI] >= (matched * (orders[i].price)), 'DAI balance too low');
                traderBalances[msg.sender][ticker] = (traderBalances[msg.sender][ticker] + matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][DAI] - (matched * (orders[i].price));
                traderBalances[orders[i].trader][ticker] = (traderBalances[orders[i].trader][ticker] - matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[orders[i].trader][DAI] + (matched * (orders[i].price));
            }
            nextTradeId++;
            i++;
        }
        
        i = 0;
        while(i < orders.length && orders[i].filled == orders[i].amount) {
            for(uint j = i; j < orders.length - 1; j++) {
                orders[j] = orders[j + 1];
            }
            orders.pop();
            i++;
        }
        
        
    }
    
    /**
     * @dev Functions to call for front end usable data
     */
    
    function getOrders(bytes32 ticker, Side side) external view returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }
    
    function getTokens() external view returns(Token[] memory) {
        Token[] memory _tokens = new Token[](tokenList.length);
        for(uint i = 0; i < tokenList.length; i++) {
            _tokens[i] = Token(tokens[tokenList[i]].ticker, tokens[tokenList[i]].tokenAddress);
        }
        return _tokens;
    }
    
    modifier tokenIsNotDai(bytes32 ticker) {
        require(ticker != DAI, 'Cannot trade DAI');
        _;
    }
    
    modifier tokenExist(bytes32 ticker) {
        require(tokens[ticker].tokenAddress != address(0), 'This token does not exist');
        _;
    }
       
    modifier onlyAdmin {
        require(msg.sender == admin, 'Only admin');
        _;
    }
}