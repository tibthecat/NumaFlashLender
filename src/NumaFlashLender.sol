// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./interfaces/IERC3156FlashBorrower.sol";
import "./interfaces/IERC3156FlashLender.sol";



/**
 * @author tibthecat
 * @dev numa flash lending.
 */
contract NumaFlashLender is IERC3156FlashLender, Ownable, Pausable  {

    using SafeERC20 for IERC20;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address public numaToken;
    mapping(address => bool) public isWhitelisted;

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "Not whitelisted");
        _;
    }

    /**
     * @param supportedToken_ Token contract supported for flash lending.
     */
    constructor(
        address supportedToken_
    ) Ownable(msg.sender)
    {
        numaToken = supportedToken_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setWhitelist(address user, bool status) external onlyOwner {
        isWhitelisted[user] = status;
    }

    /**
     * @dev Loan `amount` tokens to `receiver`, and takes it back plus a `flashFee` after the callback.
     * @param receiver The contract receiving the tokens, needs to implement the `onFlashLoan(address user, uint256 amount, uint256 fee, bytes calldata)` interface.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data A data parameter to be passed on to the `receiver` for any custom use.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external whenNotPaused onlyWhitelisted override returns(bool) {
        require(
            (token == numaToken),
            "FlashLender: Unsupported currency"
        );
        uint256 fee = _flashFee();
        IERC20(token).safeTransfer(address(receiver), amount);


        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "FlashLender: Callback failed"
        );

        IERC20(token).safeTransferFrom(address(receiver), address(this), amount + fee);

        return true;
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.  
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(
        address token,
        uint256
    ) external view override returns (uint256) {
        require(
            (token == numaToken),
            "FlashLender: Unsupported currency"
        );
        return _flashFee();
    }


    /**
     * @dev The fee to be charged for a given loan. Internal function with no checks.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function _flashFee() internal pure returns (uint256) {
        return 0;
    }

    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(
        address token
    ) external view override returns (uint256) {
        return  (token == numaToken) ? IERC20(token).balanceOf(address(this)) : 0;
    }


    
    function withdrawERC20(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(owner(), amount);
    }
}