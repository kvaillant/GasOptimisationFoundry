// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

error Unauthorized(bytes message);

contract GasContract {
    uint8 public constant tradePercent = 12;
    uint8 wasLastOdd = 1;
    uint256 public paymentCounter;
    mapping(address => uint256) public balances;
    address public immutable contractOwner = msg.sender;
    mapping(address => Payment[]) private payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;

    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    struct ImportantStruct {
        uint256 amount;
        uint8 valueA; // max 3 digits
        uint8 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
        uint256 bigValue;
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (senderOfTx != contractOwner && !checkForAdmin(senderOfTx)) {
            revert Unauthorized(
                "Error in Gas contract - onlyAdminOrOwner modifier : revert happened because the originator of the transaction was not the admin, and furthermore he wasn't the owner of the contract, so he cannot run this function"
            );
        }
        _;
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender,
            "Gas Contract CheckIfWhiteListed modifier : revert happened because the originator of the transaction was not the sender"
        );
        uint256 usersTier = whitelist[senderOfTx];
        require(
            usersTier > 0,
            "Gas Contract CheckIfWhiteListed modifier : revert happened because the user is not whitelisted"
        );
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        for (uint256 ii = 0; ii < 5; ii++) {
            administrators[ii] = _admins[ii];
        }
        balances[contractOwner] = _totalSupply;
        emit supplyChanged(contractOwner, _totalSupply); // Only contract owner does have supply at the beginning
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function addHistory(address _updateAddress) public {
        History memory history = History({
            blockNumber: block.number,
            lastUpdate: block.timestamp,
            updatedBy: _updateAddress
        });
        paymentHistory.push(history);
    }

    function getPayments(
        address _user
    ) external view returns (Payment[] memory payments_) {
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        address senderOfTx = msg.sender;
        if (balances[senderOfTx] < _amount) {
            revert(
                "Gas Contract - Transfer function - Sender has insufficient Balance"
            );
        }
        if (bytes(_name).length > 8) {
            revert(
                "Gas Contract - Transfer function -  The recipient name is too long, there is a max length of 8 characters"
            );
        }
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
    }

    function addToWhitelist(
        address _userAddrs,
        uint256 _tier
    ) public onlyAdminOrOwner {
        if (_tier > 255) {
            revert(
                "Gas Contract - addToWhitelist function -  tier level should not be greater than 255"
            );
        }
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;

        require(
            balances[senderOfTx] >= _amount,
            "Gas Contract - whiteTransfers function - Sender has insufficient Balance"
        );
        require(
            _amount > 3,
            "Gas Contract - whiteTransfers function - amount to send have to be bigger than 3"
        );
        whiteListStruct[senderOfTx] = ImportantStruct(
            _amount,
            0,
            0,
            true,
            msg.sender,
            0
        );
        balances[senderOfTx] =
            balances[senderOfTx] -
            _amount +
            whitelist[senderOfTx];
        balances[_recipient] =
            balances[_recipient] +
            _amount -
            whitelist[senderOfTx];

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) public view returns (bool, uint256) {
        return (
            whiteListStruct[sender].paymentStatus,
            whiteListStruct[sender].amount
        );
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }

    fallback() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}
