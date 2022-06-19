// SPDX-License-Identifier:MIT
pragma solidity ^0.8.8;

contract MultiSigWallet {
    // We need events for
    event Deposit(address indexed sender, uint amount);
    // Deposits
    event Submit(uint indexed txnId);
    // when we submit a proposal
    event Approve(address indexed owner, uint indexed txId);
    // when the proposal is approved
    event Revoke(uint indexed txId, address indexed sender);
    // when the proposal is revoked
    event Executed(uint txId);
    // when the proposal is executed

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    // list of the owner of the wallet
    address[] public owners;
    // mapping to verify the owner
    mapping(address => bool) public isOwner;
    uint public required;

    // list of the transaction
    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint txId) {
        require(txId < transactions.length, "Txn doesnot exists");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "Approved");
        _;
    }

    modifier notExecuted(uint txId) {
        require(!transactions[txId].executed, "Already executed");
        _;
    }

    constructor(address[] memory _owner, uint _required) {
        require(_owner.length > 0, "owners required");
        require(
            _required > 0 && _required <= _owner.length,
            "invalid required number of owner"
        );

        for (uint i; i < _owner.length; i++) {
            address owner = _owner[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "Not a unique owner");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint _value,
        bytes calldata _data,
        bool _executed
    ) external onlyOwner {
        transactions.push(Transaction(_to, _value, _data, _executed));
        emit Submit(transactions.length - 1);
    }

    function approve(uint _txId)
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txnId) private view returns (uint count) {
        for (uint i; i < owners.length; i++) {
            if (approved[_txnId][msg.sender]) {
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= required, "Approvals not more");
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "The transaction was not completed");
        emit Executed(_txId);
    }

    function revoke(uint _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(approved[_txId][msg.sender], "Transaction not yet approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(_txId, msg.sender);
    }
}
