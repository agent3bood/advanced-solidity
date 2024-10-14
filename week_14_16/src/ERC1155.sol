// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Arrays} from "openzeppelin-contracts/contracts/utils/Arrays.sol";
import {IERC1155, IERC1155MetadataURI, IERC1155Receiver} from "./IERC1155.sol";

contract ERC1155 is IERC1155 {
    using Arrays for uint256[];
    using Arrays for address[];

    // id => (owner => balance)
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // owner => (operator => approved)
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId;
        //        assembly {
        //            let erc1155 := keccak256("") // TODO
        //
        //            let ret := or(eq(erc1155, interfaceId))
        //            return (ret, 32)
        //        }
    }

    function balanceOf(
        address account,
        uint256 id
    ) public view virtual returns (uint256) {
        assembly {
            if iszero(account) {
                revert(0, 0)
            }
            // load free memory pointer
            let p := mload(0x40)

            // store account & id
            mstore(p, account)
            mstore(add(p, 0x20), id)

            // calculate balance slot
            let slot := keccak256(p, 0x40)

            // load balance into memory
            mstore(add(p, 0x60), sload(slot))

            // return balance
            return(add(p, 0x60), 0x20)
        }
    }

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view virtual returns (uint256[] memory) {
        assembly {
            if iszero(eq(accounts.length, ids.length)) {
                revert(0, 0)
            }
            let p := mload(0x40)
            let len := accounts.length
            let retSize := add(0x40, mul(len, 0x20))
            let retP := add(p, 0x40)

            mstore(retP, 0x20) // offset
            mstore(add(retP, 0x20), len) // length

            let i := 0
            for {

            } lt(i, len) {
                i := add(i, 1)
            } {
                let account := calldataload(add(accounts.offset, mul(i, 0x20)))
                let id := calldataload(add(ids.offset, mul(i, 0x20)))

                mstore(p, account)
                mstore(add(p, 0x20), id)
                // log0(p, 0x20)
                // log0(add(p, 0x20), 0x20)

                let slot := keccak256(p, 0x40)
                let b := sload(slot)
                mstore(p, b)
                // log0(p, 0x20)

                // skip two workds (offset, length) and then add the balance at index
                mstore(add(add(retP, 0x40), mul(i, 0x20)), b)
            }
            // log0(retP, retSize)
            return(retP, retSize)
        }
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external virtual override {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert();
        }
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external virtual override {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert();
        }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual {
        if (ids.length != values.length) {
            revert();
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                uint256 fromBalance = _balances[id][from];
                if (fromBalance < value) {
                    revert();
                }
                unchecked {
                    // Overflow not possible: value <= fromBalance
                    _balances[id][from] = fromBalance - value;
                }
            }

            if (to != address(0)) {
                _balances[id][to] += value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }
    }

    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = _msgSender();
            if (ids.length == 1) {
                uint256 id = ids.unsafeMemoryAccess(0);
                uint256 value = values.unsafeMemoryAccess(0);
                _doSafeTransferAcceptanceCheck(
                    operator,
                    from,
                    to,
                    id,
                    value,
                    data
                );
            } else {
                _doSafeBatchTransferAcceptanceCheck(
                    operator,
                    from,
                    to,
                    ids,
                    values,
                    data
                );
            }
        }
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        if (to == address(0)) {
            revert();
        }
        if (from == address(0)) {
            revert();
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(
            id,
            value
        );
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        if (to == address(0)) {
            revert();
        }
        if (from == address(0)) {
            revert();
        }
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal virtual {
        assembly {
            if iszero(to) {
                revert(0, 0)
            }
        }
        _update(msg.sender, address(0), to, id, amount, data);
    }

    function _batchMint(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal {
        assembly {
            if iszero(to) {
                revert(0, 0)
            }
        }

        _updateBatch(msg.sender, address(0), to, ids, amounts, data);

        // assembly {
        //     let p := mload(0x40)
        //     mstore(p, to) // used to calculate slots
        //     let len := ids.length
        //     let i := 0
        //     for {

        //     } lt(i, len) {
        //         i := add(i, 1)
        //     } {
        //         let id := calldataload(add(ids.offset, mul(i, 0x20)))
        //         let amount := calldataload(add(amounts.offset, mul(i, 0x20)))
        //         mstore(add(p, 0x20), id)
        //         let slot := keccak256(p, 0x40)
        //         let b := sload(slot)
        //         let newBalance := add(b, amount)
        //         sstore(slot, newBalance)
        //     }
        // }
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert();
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(
            id,
            amount
        );
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    function _batchBurn(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) internal virtual {
        if (from == address(0)) {
            revert();
        }
        _updateWithAcceptanceCheck(from, address(0), ids, amounts, "");
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (operator == address(0)) {
            revert();
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _msgSender() internal view virtual returns (address sender) {
        return msg.sender;
    }

    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        assembly ("memory-safe") {
            // Load the free memory pointer
            array1 := mload(0x40)
            // Set array length to 1
            mstore(array1, 1)
            // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

            // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    value,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert();
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert();
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    values,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    // Tokens rejected
                    revert();
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert();
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function _update(
        address operator,
        address from,
        address to,
        uint id,
        uint amount,
        bytes calldata data
    ) internal {
        // TODO: update from balance
        assembly {
            let p := mload(0x40)
            mstore(p, to)
            mstore(add(p, 0x20), id)

            let slot := keccak256(p, 0x40)
            let b := sload(slot)
            let newBalance := add(b, amount)

            sstore(slot, newBalance)

            if eq(extcodesize(to), 0) {
                return(0, 0)
            }

            //
            // call onERC1155Received(operator, from, id, amount, mintData)
            // store call params
            //
            // first is the function selector, 4 bytes
            // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
            // 0xf23a6e6100000000000000000000000000000000000000000000000000000000
            // we need to put the whole 32 bytes
            // otherwise solidity will pad the value with zeros to the left
            let
                onERC1155ReceivedSelector
            := 0xf23a6e6100000000000000000000000000000000000000000000000000000000
            mstore(p, onERC1155ReceivedSelector)
            log0(p, 4)
            mstore(add(p, 0x04), operator)
            log0(add(p, 0x4), 0x20)
            mstore(add(p, 0x24), from)
            log0(add(p, 0x24), 0x20)
            mstore(add(p, 0x44), id)
            log0(add(p, 0x44), 0x20)
            mstore(add(p, 0x64), amount)
            log0(add(p, 0x64), 0x20)

            // data
            // [offset , length , data........] // nice name
            // [bytes32, bytes32, dynamic size] // words
            // [0x84   , 0xa4   , 0xc4........] // offset in this function - p
            // [0x80   , 0xa0   , 0xc0........] // offset in calldata, this is what the receiver will see
            // offset of 'data' in the calldata we are constructing
            // we put 'a0' and NOT 'a4' because we have to subtract the '4' function selector bytes
            mstore(add(p, 0x84), 0xa0)
            log0(add(p, 0x84), 0x20)
            // bytes in calldata look like this [offset, length, data.......]
            // where offset will point at 'length'
            let dataLen := data.length
            mstore(add(p, 0xa4), dataLen)
            log0(add(p, 0xa4), 0x20)
            // copy data to memory
            calldatacopy(add(p, 0xc4), data.offset, dataLen)
            log0(add(p, 0xc4), dataLen)

            let totalSize := add(0xc4, mul(div(add(dataLen, 31), 32), 32))
            log0(p, totalSize)
            mstore(0, 0)
            let success := call(gas(), to, 0, p, totalSize, 0x00, 0x04)
            if iszero(success) {
                revert(0, 0)
            }
            if iszero(eq(mload(0x00), onERC1155ReceivedSelector)) {
                revert(0, 0)
            }
        }
    }

    function _updateBatch(
        address operator,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal {
        // TODO: update from balance
        assembly {
            if iszero(eq(ids.length, amounts.length)) {
                revert(0, 0)
            }

            let p := mload(0x40)
            mstore(p, to)
            let len := ids.length
            let i := 0
            for {

            } lt(i, len) {
                i := add(i, 1)
            } {
                let id := calldataload(add(ids.offset, mul(i, 0x20)))
                let amount := calldataload(add(amounts.offset, mul(i, 0x20)))

                mstore(add(p, 0x20), id)

                let slot := keccak256(p, 0x40)
                let b := sload(slot)
                let newBalance := add(b, amount)

                sstore(slot, newBalance)
            }

            if eq(extcodesize(to), 0) {
                return(0, 0)
            }

            // [selector,   operator,   from,   idsOffset,  amountsOffset,  dataOffset, ids , amounts, data]
            // [0x00    ,   0x04     ,  0x24,   0x44     ,  0x64         ,  0x84      , 0xa4, 0x..   , 0x..] // memory locations
            // [0x00    ,   0x00     ,  0x20,   0x40     ,  0x60         ,  0x80      , 0xa0, 0x..   , 0x..] // calldata location
            //
            // call onERC1155BatchReceived(operator, from, ids, amounts, mintData)
            // first is the function selector, 4 bytes
            // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
            // 0xbc197c8100000000000000000000000000000000000000000000000000000000
            // we need to put the whole 32 bytes
            // otherwise solidity will pad the value with zeros to the left
            let
                onERC1155BatchReceivedSelector
            := 0xbc197c8100000000000000000000000000000000000000000000000000000000
            mstore(p, onERC1155BatchReceivedSelector)
            log0(p, 4)
            mstore(add(p, 0x04), operator)
            log0(add(p, 0x4), 0x20)
            mstore(add(p, 0x24), from)
            log0(add(p, 0x24), 0x20)

            let idsLen := ids.length
            let idsLenBytes := mul(idsLen, 0x20)

            let idsOffset := 0xa0 // ids offset relative to start of calldata; noes NOT start count selector
            mstore(add(p, 0x44), idsOffset)

            // 0x20(length slot) + idsOffset + idsLenBytes
            let amountsOffset := add(add(idsOffset, idsLenBytes), 0x20)
            mstore(add(p, 0x64), amountsOffset)

            let dataOffset := add(add(amountsOffset, idsLenBytes), 0x20)
            mstore(add(p, 0x84), dataOffset)

            let pData := add(p, 0xa4)

            mstore(pData, idsLen)
            pData := add(pData, 0x20)
            calldatacopy(pData, ids.offset, idsLenBytes)
            pData := add(pData, idsLenBytes)

            mstore(pData, idsLen)
            pData := add(pData, 0x20)
            calldatacopy(pData, amounts.offset, idsLenBytes)
            pData := add(pData, idsLenBytes)

            let dataLen := data.length
            mstore(pData, dataLen)
            pData := add(pData, 0x20)
            calldatacopy(pData, data.offset, dataLen)

            let totalSize := add(
                0xc4,
                add(
                    add(idsLenBytes, 0x20),
                    add(
                        add(idsLenBytes, 0x20),
                        mul(div(add(dataLen, 31), 32), 32)
                    )
                )
            )
            log0(p, totalSize)
            mstore(0, 0)
            let success := call(gas(), to, 0, p, totalSize, 0x00, 0x04)
            if iszero(success) {
                revert(0, 0)
            }
            if iszero(eq(mload(0x00), onERC1155BatchReceivedSelector)) {
                revert(0, 0)
            }
        }
    }
}
