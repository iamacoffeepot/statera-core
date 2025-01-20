pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {TokenTransferLibrary} from "../src/libraries/TokenTransferLibrary.sol";
import {Token} from "../src/interfaces/Token.sol";

contract AlwaysFailTokenStub {
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success) {
        return false;
    }
}

contract AlwaysRevertTokenStub {
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success) {
        revert("");
    }
}

contract AlwaysSuccessTokenStub {
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success) {
        return true;
    }
}

contract IncompleteReturnDataTokenStub {
    function transferFrom(address owner, address recipient, uint256 amount) external {
        assembly {
            mstore(0x18, 0x01) // [ 0x00, ... (29x), 0x01 ]
            return(0x00, 0x19)
        }
    }
}

contract NoReturnDataTokenStub {
    function transferFrom(address owner, address recipient, uint256 amount) external { }
}

contract TokenTransferLibraryTest is Test {
    function test_fuzz_transfer_from_always_fails(address owner, address recipient, uint256 amount) external {
        AlwaysFailTokenStub token = new AlwaysFailTokenStub();

        vm.expectCall(address(token), abi.encodeCall(Token.transferFrom, (owner, recipient, amount)));

        assertFalse(TokenTransferLibrary.tryTransferFrom(Token(address(token)), owner, recipient, amount));
    }

    function test_fuzz_transfer_from_always_revert(address owner, address recipient, uint256 amount) external {
        AlwaysRevertTokenStub token = new AlwaysRevertTokenStub();

        vm.expectCall(address(token), abi.encodeCall(Token.transferFrom, (owner, recipient, amount)));

        assertFalse(TokenTransferLibrary.tryTransferFrom(Token(address(token)), owner, recipient, amount));
    }

    function test_fuzz_transfer_from_always_success(address owner, address recipient, uint256 amount) external {
        AlwaysSuccessTokenStub token = new AlwaysSuccessTokenStub();

        vm.expectCall(address(token), abi.encodeCall(Token.transferFrom, (owner, recipient, amount)));

        assertTrue(TokenTransferLibrary.tryTransferFrom(Token(address(token)), owner, recipient, amount));
    }

    function test_fuzz_transfer_from_incomplete_data(address owner, address recipient, uint256 amount) external {
        IncompleteReturnDataTokenStub token = new IncompleteReturnDataTokenStub();

        vm.expectCall(address(token), abi.encodeCall(Token.transferFrom, (owner, recipient, amount)));

        assertFalse(TokenTransferLibrary.tryTransferFrom(Token(address(token)), owner, recipient, amount));
    }

    function test_fuzz_transfer_from_no_return_data(address owner, address recipient, uint256 amount) external {
        NoReturnDataTokenStub token = new NoReturnDataTokenStub();

        vm.expectCall(address(token), abi.encodeCall(Token.transferFrom, (owner, recipient, amount)));

        assertTrue(TokenTransferLibrary.tryTransferFrom(Token(address(token)), owner, recipient, amount));
    }
}