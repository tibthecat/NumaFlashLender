// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/NumaFlashLender.sol";

contract MockToken is IERC20 {
    string public name = "MockToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function totalSupply() external pure override returns (uint256) { return 1_000_000 ether; }
    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract MockBorrower is IERC3156FlashBorrower {
    address public lender;
    bool public shouldFail;

    constructor(address _lender) {
        lender = _lender;
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override returns (bytes32) {
        require(!shouldFail, "Borrower: forced fail");

        // Pay back the flash loan
        IERC20(token).approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function setShouldFail(bool _fail) external {
        shouldFail = _fail;
    }
}

contract NumaFlashLenderTest is Test {
    NumaFlashLender public lender;
    MockToken public token;
    MockBorrower public borrower;

    address public owner = address(0xABCD);
    address public user = address(0xBEEF);

    function setUp() public {
        vm.startPrank(owner);
        token = new MockToken();
        lender = new NumaFlashLender(address(token));
        borrower = new MockBorrower(address(lender));

        token.mint(address(lender), 1000 ether);
        token.mint(address(borrower), 1000 ether);

        lender.setWhitelist(address(borrower), true);
        vm.stopPrank();
    }

    function testInitialSetup() public {
        assertEq(address(token), lender.numaToken());
        assertEq(lender.isWhitelisted(address(borrower)), true);
    }

    function testOnlyWhitelistedCanFlashLoan() public {
        vm.prank(user);
        vm.expectRevert("Not whitelisted");
        lender.flashLoan(IERC3156FlashBorrower(user), address(token), 10 ether, "");
    }

    function testFlashLoanSuccess() public {
        vm.prank(address(borrower));
        bool ok = lender.flashLoan(borrower, address(token), 10 ether, "");
        assertTrue(ok);
        assertEq(token.balanceOf(address(lender)), 1000 ether);
    }

    function testFlashLoanFailsOnCallback() public {
        vm.prank(owner);
        lender.setWhitelist(address(borrower), true);
        borrower.setShouldFail(true);

        vm.prank(address(borrower));
        vm.expectRevert("Borrower: forced fail");
        lender.flashLoan(borrower, address(token), 10 ether, "");
    }

    function testFlashLoanFailsOnUnsupportedToken() public {
        MockToken other = new MockToken();
        vm.prank(owner);
        lender.setWhitelist(user, true);

        vm.prank(user);
        vm.expectRevert("FlashLender: Unsupported currency");
        lender.flashLoan(borrower, address(other), 10 ether, "");
    }

    function testPauseBlocksFlashLoan() public {
        vm.prank(owner);
        lender.pause();

        vm.prank(address(borrower));
        vm.expectRevert();
        lender.flashLoan(borrower, address(token), 10 ether, "");
    }

    function testOnlyOwnerCanPauseUnpause() public {
        vm.prank(user);
        vm.expectRevert();
        lender.pause();

        vm.prank(owner);
        lender.pause();
        vm.prank(owner);
        lender.unpause();
    }

    function testWithdrawERC20() public {
        vm.prank(owner);
        lender.withdrawERC20(token, 100 ether);
        assertEq(token.balanceOf(owner), 100 ether);
    }

    function testFlashFeeIsZero() public {
        
        uint256 publicFee = lender.flashFee(address(token), 100 ether);
        assertEq(publicFee, 0);
    }

    function testMaxFlashLoan() public {
        uint256 amount = lender.maxFlashLoan(address(token));
        assertEq(amount, token.balanceOf(address(lender)));
    }
}
