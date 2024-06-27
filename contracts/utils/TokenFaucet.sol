// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IGamesHub.sol";
import "../interfaces/IERC20.sol";

contract TokenFaucet {
    IERC20 public tokenInstance;
    IGamesHub public gamesHub;
    uint256 public amountToDistribute;
    uint256 public constant ethAmountToDistribute = 0.1 ether;
    uint256 public lockDuration = 1 hours;

    mapping(address => uint256) public lastTokenAccessTime;
    mapping(address => bool) public ethRequested;

    /**
     * @dev Constructor function
     * @param _gamesHub The address of the GamesHub contract
     */
    constructor(address _gamesHub) {
        gamesHub = IGamesHub(_gamesHub);
        tokenInstance = IERC20(gamesHub.helpers(keccak256("TOKEN")));
        amountToDistribute = 1000000000;
    }

    /**
     * @dev Modifier to check if the caller is an admin
     */
    modifier onlyAdmin() {
        require(
            gamesHub.checkRole(gamesHub.ADMIN_ROLE(), msg.sender),
            "Caller is not admin"
        );
        _;
    }

    /**
     * @dev Function to request tokens from the faucet
     */
    function requestTokens() public {
        require(block.timestamp - lastTokenAccessTime[msg.sender] > lockDuration, "Lock period has not expired.");
        
        lastTokenAccessTime[msg.sender] = block.timestamp;
        tokenInstance.mint(msg.sender, amountToDistribute);
    }

    /**
     * @dev Function to request ETH from the faucet
     * @param _requester The address of the requester
     */
    function requestEth(address _requester) public {
        require(ethRequested[_requester] == false, "ETH already requested.");
        ethRequested[_requester] = true;
        payable(_requester).transfer(ethAmountToDistribute);
    }
    
    /**
     * @dev Function to update the distribution amount of tokens
     * @param _newAmount The new amount to distribute
     */
    function updateDistributionAmount(uint256 _newAmount) public {
        amountToDistribute = _newAmount;
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {}
}
