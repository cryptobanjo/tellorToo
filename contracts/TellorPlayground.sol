pragma solidity 0.5.16;

//import "usingtellor/contracts/TellorPlayground.sol";
import "./libraries/SafeMath.sol";


contract TellorPlayground {

    using SafeMath for uint256;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);//ERC20 Transfer Event

    mapping(uint256 => mapping(uint256 => uint256)) public values; //requestId -> timestamp -> value
    mapping(uint256 => mapping(uint256 => bool)) public isDisputed; //requestId -> timestamp -> value
    mapping(uint256 => uint256[]) public timestamps;
    mapping(address => uint) public balances;
    uint256 public totalSupply;

    constructor(address[] memory _initialBalances, uint256[] memory _intialAmounts) public {
        require(_initialBalances.length == _intialAmounts.length, "Arrays have different lengths");
        for(uint i = 0; i < _intialAmounts.length; i++){
            balances[_initialBalances[i]] = _intialAmounts[i];
            totalSupply = totalSupply.add(_intialAmounts[i]);
        }
    }


    function mint(address _holder, uint256 _value) public {
        balances[_holder] = balances[_holder].add(_value);
        totalSupply = totalSupply.add(_value);
    }

    function transfer(address _to, uint256 _amount) public returns(bool) {
        return transferFrom(msg.sender, _to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns(bool){
        require(_amount != 0, "Tried to send non-positive amount");
        require(_to != address(0), "Receiver is 0 address");
        balances[_from] = balances[_from].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(_from, _to, _amount);
    }

    function submitValue(uint256 _requestId,uint256 _value) external {
        values[_requestId][block.timestamp] = _value;
        timestamps[_requestId].push(block.timestamp);
    }

    function disputeValue(uint256 _requestId, uint256 _timestamp) external {
        values[_requestId][_timestamp] = 0;
        isDisputed[_requestId][_timestamp] = true;
    }

    function retrieveData(uint256 _requestId, uint256 _timestamp) public view returns(uint256){
        return values[_requestId][_timestamp];
    }

    function isInDispute(uint256 _requestId, uint256 _timestamp) public view returns(bool){
        return isDisputed[_requestId][_timestamp];
    }

    function getNewValueCountbyRequestId(uint256 _requestId) public view returns(uint) {
        return timestamps[_requestId].length;
    }

    function getTimestampbyRequestIDandIndex(uint256 _requestId, uint256 index) public view returns(uint256) {
        uint len = timestamps[_requestId].length;
        if(len == 0 || len <= index) return 0;
        return timestamps[_requestId][index];
    }

    // function getTime() public view returns(uint256){
    //     return now;
    // }
}