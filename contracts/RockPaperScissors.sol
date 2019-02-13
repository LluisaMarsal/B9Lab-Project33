pragma solidity ^0.4.19;
 
contract RockPaperScissors {
    
    address private owner;
    uint constant maxNumberOfBlocks = 1 days / 15;
    uint constant minNumberOfBlocks = 1 hours / 15;
    uint constant maxNextNumberOfBlocks = 1 days / 15;
    uint constant minNextNumberOfBlocks = 1 hours / 15;
    
    enum Bet {NULL, ROCK, PAPER, SCISSORS}
    
    struct BetBox {
       address player1;
       address player2;
       address winner;
       Bet betPlayer1;
       Bet betPlayer2;
       bytes32 hashedPlayer1Move;
       bytes32 hashedPlayer2Move;
       uint amountPlayer1;
       uint amountPlayer2;
       uint amountWinner;
       uint joinDeadline; 
       uint playersNextMoveDeadline;
    }
    
    mapping (bytes32 => BetBox) public betStructs; 
    
    event LogCreateBet(address caller, uint amount, uint numberOfBlocks);
    event LogJoinBet(address caller, uint amount, uint nextNumberOfBlocks);
    event LogPlayBet(address caller, Bet betPlayer1, Bet betPlayer2);
    event LogAwardWinner (address caller, address winner);
    event LogAwardBet(uint amount, address winner);
    event LogCancelBet(address caller, uint amount);
    
    function RockPaperScissors() public {
        owner = msg.sender;
    }
    
    function getGameID(bytes32 passCreateBet, address player1) public pure returns(bytes32 gameID) {
        return keccak256(passCreateBet, player1);
    }
    
    function createBet(bytes32 gameID, address player2, uint numberOfBlocks) public payable returns(bool success) {
        BetBox storage betBox = betStructs[gameID];
        require(betBox.player1 == 0);
        require(betBox.amountPlayer1 == 0);
        require(msg.sender != player2); 
        require(numberOfBlocks < maxNumberOfBlocks);
        require(numberOfBlocks > minNumberOfBlocks);
        betBox.player1 = msg.sender;
        betBox.player2 = player2;
        betBox.joinDeadline = block.number + numberOfBlocks;
        betBox.amountPlayer1 = msg.value;
        LogCreateBet(msg.sender, msg.value, numberOfBlocks);
        return true;
    }
    
    function joinBet(bytes32 gameID, uint nextNumberOfBlocks) public payable returns(bool success) {
        BetBox storage betBox = betStructs[gameID];
        require(betBox.amountPlayer2 == 0);
        require(betBox.joinDeadline > block.number);
        require(betBox.player2 == msg.sender); 
        require(betBox.amountPlayer1 == msg.value);
        require(nextNumberOfBlocks < maxNextNumberOfBlocks);
        require(nextNumberOfBlocks > minNextNumberOfBlocks);
        betBox.joinDeadline = 0;
        betBox.playersNextMoveDeadline = block.number + nextNumberOfBlocks;
        betBox.amountPlayer2 = msg.value;
        LogJoinBet(msg.sender, msg.value, nextNumberOfBlocks);
        return true;
    }
    
    function hashPlayerMove(bytes32 passPlayer, Bet betPlayer) public pure returns(bytes32 hashedPlayerMove) {
        return keccak256(passPlayer, betPlayer);
    }
    
    function writePlayerHashedMove(bytes32 hashedPlayerMove, bytes32 gameID) public returns(bool success) {
        BetBox storage betBox = betStructs[gameID];
        require(betBox.playersNextMoveDeadline > block.number);
        if (betBox.player1 == msg.sender) {
            betBox.hashedPlayer1Move = hashedPlayerMove;
        } else if (betBox.player2 == msg.sender) {
            betBox.hashedPlayer2Move = hashedPlayerMove;
        } else {
            assert(false);
        }
        return true;
    }

    function writePlayerMove(bytes32 passPlayer, Bet betPlayer, bytes32 gameID) public returns(bool success) {
        bytes32 hashedPlayerMove = hashPlayerMove(passPlayer, betPlayer);
        BetBox storage betBox = betStructs[gameID];
        require(betPlayer == Bet.ROCK || betPlayer == Bet.PAPER || betPlayer == Bet.SCISSORS);
        require(betBox.playersNextMoveDeadline > block.number);
        if (betBox.player1 == msg.sender && betBox.hashedPlayer1Move == hashedPlayerMove) {
            betBox.betPlayer1 = betPlayer;
        } else if (betBox.player2 == msg.sender && betBox.hashedPlayer2Move == hashedPlayerMove) {
            betBox.betPlayer2 = betPlayer;
        } else {
            assert(false);
        }
        return true;
    }
    
    function playBet(bytes32 passCreateBet, address player1) public view returns(uint winningPlayer) {
        bytes32 gameID = getGameID(passCreateBet, player1);
        BetBox storage betBox = betStructs[gameID];
        if (betBox.betPlayer1 == betBox.betPlayer2) revert();
        if ((betBox.betPlayer1 == Bet.PAPER && betBox.betPlayer2 == Bet.ROCK)||
            (betBox.betPlayer1 == Bet.ROCK && betBox.betPlayer2 == Bet.SCISSORS)||
            (betBox.betPlayer1 == Bet.SCISSORS && betBox.betPlayer2 == Bet.PAPER)||
            (betBox.betPlayer1 == Bet.ROCK && betBox.betPlayer2 == Bet.SCISSORS)||
            (betBox.betPlayer1 == Bet.PAPER && betBox.betPlayer2 == Bet.ROCK)||
            (betBox.betPlayer1 == Bet.SCISSORS && betBox.betPlayer2 == Bet.PAPER)) return 1;
        if ((betBox.betPlayer2 == Bet.PAPER && betBox.betPlayer1 == Bet.ROCK)||
            (betBox.betPlayer2 == Bet.ROCK && betBox.betPlayer1 == Bet.SCISSORS)||
            (betBox.betPlayer2 == Bet.SCISSORS && betBox.betPlayer1 == Bet.PAPER)||
            (betBox.betPlayer2 == Bet.ROCK && betBox.betPlayer1 == Bet.SCISSORS)||
            (betBox.betPlayer2 == Bet.PAPER && betBox.betPlayer1 == Bet.ROCK)||
            (betBox.betPlayer2 == Bet.SCISSORS && betBox.betPlayer1 == Bet.PAPER)) return 2; 
        assert(false);
    }

    function awardWinner(bytes32 passCreateBet, address player1) public returns(bool success) {
        uint winningPlayer = playBet(passCreateBet, player1);
        bytes32 gameID = getGameID(passCreateBet, player1);
        BetBox storage betBox = betStructs[gameID];
        address winner;
        if (winningPlayer == 1) {
            winner = betBox.player1;
        } else if (winningPlayer == 2) {
            winner = betBox.player2;
        } else {
            assert(false);
        }
        betBox.winner = winner;
        LogAwardWinner(msg.sender, winner);
        return true;
    }

    function awardBetToWinner(bytes32 gameID) public returns(bool success) {
        BetBox storage betBox = betStructs[gameID];
        require(betBox.winner == msg.sender);
        betBox.amountWinner = betBox.amountPlayer1 + betBox.amountPlayer2;
        uint amount = betBox.amountWinner;
        require(amount != 0);
        betBox.amountWinner = 0;
        betBox.amountPlayer1 = 0;
        betBox.amountPlayer2 = 0;
        betBox.player1 = 0x0;
        betBox.player2 = 0x0;
        betBox.winner = 0x0; 
        betBox.playersNextMoveDeadline = 0;
        LogAwardBet(amount, msg.sender);
        betBox.winner.transfer(amount);
        return true;    
    }
    
    function cancelBet(bytes32 gameID) public returns(bool success) {
        BetBox storage betBox = betStructs[gameID];
        require(betBox.player1 == msg.sender || betBox.player2 == msg.sender);
        require(betBox.betPlayer1 == Bet.ROCK && betBox.betPlayer2 == Bet.ROCK|| 
                betBox.betPlayer1 == Bet.PAPER && betBox.betPlayer2 == Bet.PAPER|| 
                betBox.betPlayer1 == Bet.SCISSORS && betBox.betPlayer1 == Bet.SCISSORS);
        require(betBox.amountPlayer1 != 0);
        require(betBox.amountPlayer2 != 0);
        require(betBox.amountPlayer1 == betBox.amountPlayer2);
        uint amount = betBox.amountPlayer1; 
        betBox.amountPlayer1 = 0;
        betBox.amountPlayer2 = 0;
        betBox.player1 = 0x0;
        betBox.player2 = 0x0;
        betBox.playersNextMoveDeadline = 0;
        LogCancelBet(msg.sender, amount);
        betBox.player1.transfer(amount);
        betBox.player2.transfer(amount);
        return true;
    }
}