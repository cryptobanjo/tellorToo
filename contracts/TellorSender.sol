pragma solidity 0.5.16;

import "tellorcore/contracts/TellorMaster.sol";

/**
* @title UserContract 
* This is a TEST contract. It creates for easy integration to the Tellor System
* by allowing smart contracts to read data off Tellor
* **************only for testing**************
*/
contract UsingTellor{
    TellorMaster tellor;
    /*Constructor*/
    /**
    * @dev the constructor sets the storage address and owner
    * @param _tellor is the TellorMaster address
    */
    constructor(address payable _tellor) public {
        tellor = TellorMaster(_tellor);
    }

     /**
    * @dev Retreive value from oracle based on requestId/timestamp
    * @param _requestId being requested
    * @param _timestamp to retreive data/value from
    * @return uint value for requestId/timestamp submitted
    */
    function retrieveData(uint256 _requestId, uint256 _timestamp) public view returns(uint256){
        return tellor.retrieveData(_requestId,_timestamp);
    }

    /**
    * @dev Gets the 5 miners who mined the value for the specified requestId/_timestamp
    * @param _requestId to looku p
    * @param _timestamp is the timestamp to look up miners for
    * @return bool true if requestId/timestamp is under dispute
    */
    function isInDispute(uint256 _requestId, uint256 _timestamp) public view returns(bool){
        return tellor.isInDispute(_requestId, _timestamp);
    }

    /**
    * @dev Counts the number of values that have been submited for the request
    * @param _requestId the requestId to look up
    * @return uint count of the number of values received for the requestId
    */
    function getNewValueCountbyRequestId(uint256 _requestId) public view returns(uint) {
        return tellor.getNewValueCountbyRequestId(_requestId);
    }

    /**
    * @dev Gets the timestamp for the value based on their index
    * @param _requestId is the requestId to look up
    * @param _index is the value index to look up
    * @return uint timestamp
    */
    function getTimestampbyRequestIDandIndex(uint256 _requestId, uint256 _index) public view returns(uint256) {
        return tellor.getTimestampbyRequestIDandIndex( _requestId,_index);
    }

    /**
    * @dev Allows the user to get the latest value for the requestId specified
    * @param _requestId is the requestId to look up the value for
    * @return bool true if it is able to retreive a value, the value, and the value's timestamp
    */
    function getCurrentValue(uint256 _requestId) public view returns (bool ifRetrieve, uint256 value, uint256 _timestampRetrieved) {
        uint256 _count = tellor.getNewValueCountbyRequestId(_requestId);
        uint _time = tellor.getTimestampbyRequestIDandIndex(_requestId, _count - 1);
        uint _value = tellor.retrieveData(_requestId, _time);
        if(_value > 0) return (true, _value, _time);
        return (false, 0 , _time);
    }

    function getIndexForDataBefore(uint _requestId, uint256 _timestamp) public view returns (bool found, uint256 index){
        uint256 _count = tellor.getNewValueCountbyRequestId(_requestId);
        if (_count > 0) {
            uint middle;
            uint start = 0;
            uint end = _count - 1;
            uint _time;

            //Checking Boundaries to short-circuit the algorithm
            _time = tellor.getTimestampbyRequestIDandIndex(_requestId, start);
            if(_time >= _timestamp) return (false, 0);
            _time = tellor.getTimestampbyRequestIDandIndex(_requestId, end);
            if(_time < _timestamp) return (true, end);

            //Since the value is within our boundaries, do a binary search
            while(true) {
                middle = (end - start) / 2 + 1 + start;
                _time = tellor.getTimestampbyRequestIDandIndex(_requestId, middle);
                if(_time < _timestamp){
                    //get imeadiate next value
                    uint _nextTime = tellor.getTimestampbyRequestIDandIndex(_requestId, middle + 1);
                    if(_nextTime >= _timestamp){
                        //_time is correct
                        return (true, middle);
                    } else  {
                        //look from middle + 1(next value) to end
                        start = middle + 1;
                    }
                } else {
                    uint _prevTime = tellor.getTimestampbyRequestIDandIndex(_requestId, middle - 1);
                    if(_prevTime < _timestamp){
                        // _prevtime is correct
                        return(true, middle - 1);
                    } else {
                        //look from start to middle -1(prev value)
                        end = middle -1;
                    }
                }
                //We couldn't found a value
                //if(middle - 1 == start || middle == _count) return (false, 0);
            }
        }
        return (false, 0);
    }


    /**
    * @dev Allows the user to get the first value for the requestId before the specified timestamp
    * @param _requestId is the requestId to look up the value for
    * @param _timestamp before which to search for first verified value
    * @return bool true if it is able to retreive a value, the value, and the value's timestamp
    */
    function getDataBefore(uint256 _requestId, uint256 _timestamp)
        public
        returns (bool _ifRetrieve, uint256 _value, uint256 _timestampRetrieved)
    {

        (bool _found, uint _index) = getIndexForDataBefore(_requestId,_timestamp);
        if(!_found) return (false, 0, 0);
        uint256 _time = tellor.getTimestampbyRequestIDandIndex(_requestId, _index);
        _value = tellor.retrieveData(_requestId, _time);
        //If value is diputed it'll return zero
        if (_value > 0) return (true, _value, _time);
        return (false, 0, 0);
    }
}



/** 
The sender address from Ethereum and receiver address deployed in Matic must
be registered in Matic's sender contact on Ethereum for 
*/
interface IStateSender {
  function syncState(address receiver, bytes calldata data) external;
  function register(address sender, address receiver) public;
}


/**
@title Sender
This contract helps send Tellor's data on Ethereum to Matic's Network
*/
contract TellorSender is UsingTellor {
    IStateSender public stateSender;
    event DataSent(uint _requestId, uint _timestamp, uint _value, address _sender);    
    address public receiver;

    /**
    @dev
    @param _tellorAddress is the tellor master address
    @param _stateSender is the Matic's state sender address --- they need to add the sender and receiver address
    @param _receiver is the contract receiver address in Matic
    */
    constructor(address payable _tellorAddress, address _stateSender, address _receiver) UsingTellor(_tellorAddress) public {
      stateSender = IStateSender(_stateSender);
      receiver = _receiver;
    }

    /**
    @dev This function gets the value for the specified request Id and timestamp from UsingTellor
    @param _requestId is Tellor's requestId to retreive
    @param _timestamp is Tellor's requestId timestamp to retreive
    */
    function retrieveDataAndSend(uint256 _requestId, uint256 _timestamp) public {
        uint256 value = retrieveData(_requestId, _timestamp);
        require(value > 0);
        stateSender.syncState(receiver, abi.encode(_requestId, _timestamp, value, msg.sender));
        emit DataSent(_requestId, _timestamp, value, msg.sender);
    }

    /**
    @dev This function gets the current value for the specified request Id from UsingTellor
    @param _requestId is Tellor's requestId to retreive the latest curent value for it
    */
    function getCurrentValueAndSend(uint256 _requestId) public {
      (bool ifRetrieve, uint256 value, uint256 timestamp) = getCurrentValue(_requestId);
      require(ifRetrieve);
      stateSender.syncState(receiver, abi.encode(_requestId, timestamp, value, msg.sender));
      emit DataSent(_requestId, timestamp, value, msg.sender);
    }
}