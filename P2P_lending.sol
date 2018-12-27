pragma solidity ^0.4.0;

contract P2PLending {

    mapping (address => uint) balances; 
    mapping (address => Creditor) public creditors; 
    mapping (address => Borrower) public borrowers; 

    uint numApplications;
    uint numCredits;

    mapping (uint => CreditApplication) public applications;
    mapping (uint => Credit) public credits;

    mapping(address => bool) hasOngoingCredit;
    mapping(address => bool) hasOngoingApplication;
    mapping(address => bool) hasOngoingInvestment;

    // Structs
    struct Creditor{
        address creditor_public_key;
        string name;
        bool EXISTS;
    }
    struct Borrower{
        address borrower_public_key;
        string name;
        bool EXISTS;
    }
    struct CreditApplication{
        
        bool openApp;
        uint applicationId;

        address borrower;
        uint duration; 
        uint credit_amount; 
        uint interest_rate; 
        string otherData; 

    }
    struct Credit{

        bool openCredit;
        uint creditId;

        address borrower;
        address creditor;
        uint interest_rate;
        uint duration;
        uint principal_amount;
        uint original_amount;
        uint amount_paid;
        uint startTime;
        uint monthlyCheckpoint;
        uint appId;

    }
    // Methods
    function P2PLending(){
        numCredits = 1;
        numApplications = 1;
    }
    function createCreditor(string name){
        Creditor creditor;
        creditor.name = name;
        creditor.creditor_public_key = msg.sender;
        creditor.EXISTS = true;
        require (borrowers[msg.sender].EXISTS != true);
        creditors[msg.sender] = creditor;
        hasOngoingInvestment[msg.sender] = false;
        balances[msg.sender] = 0; 

    }
    function createBorrower(string name){
        Borrower borrower;
        borrower.name = name;
        borrower.borrower_public_key = msg.sender;
        borrower.EXISTS = true;
        require (creditors[msg.sender].EXISTS != true);
        borrowers[msg.sender] = borrower;
        hasOngoingCredit[msg.sender] = false;
        hasOngoingApplication[msg.sender] = false;
        balances[msg.sender] = 0;
    }
    function viewBalance() public returns (uint){
        return balances[msg.sender];
    }
    function deposit(uint amount) {
        balances[msg.sender] += amount;
    }
    function withdraw(uint amount) returns (uint) {
        require(amount <= balances[msg.sender]);
        balances[msg.sender] -= amount;
        return amount;
    }
    function transfer(address giver, address taker, uint amount){
        require(balances[giver] >= amount);
        balances[giver] -= amount;
        balances[taker] += amount;
    }
    function createApplication(uint duration, uint interest_rate, uint credit_amount, string otherData){

        require(hasOngoingCredit[msg.sender] == false);
        require(hasOngoingApplication[msg.sender] == false);
        require(isBorrower(msg.sender));
        applications[numApplications] = CreditApplication(true, numApplications, msg.sender, duration, credit_amount, interest_rate, otherData);

        numApplications += 1;
        hasOngoingApplication[msg.sender] = true;
    }
    function giveCredit(uint appId){
        require(balances[msg.sender] >= applications[appId].credit_amount);
        require(hasOngoingInvestment[msg.sender] == false);

        balances[msg.sender] -= applications[appId].credit_amount;
        balances[applications[appId].borrower] += applications[appId].credit_amount;

        credits[numCredits] = Credit(true, numCredits, applications[appId].borrower, msg.sender, applications[appId].interest_rate, applications[appId].duration,
        applications[appId].credit_amount, applications[appId].credit_amount, 0, now,0, appId);
        numCredits += 1;

        applications[appId].openApp = false;
        hasOngoingCredit[applications[appId].borrower] = true;
        hasOngoingInvestment[msg.sender] = true;


    }
    function repayCredit(uint amount, uint estimatedInterest, uint timeSinceLastPayment){
        require(balances[msg.sender] >= amount);

        uint id_ = 0;
        for(uint i=1; i<=numCredits; i++)
        {
                if(credits[i].borrower == msg.sender)
                {
                    id_ = i;
                    break;
                }
        }
        Credit credit = credits[id_];

        require(credit.openCredit == true);

        uint p = credit.principal_amount;
        uint r = credit.interest_rate;
        uint checkpoint = credit.monthlyCheckpoint;
        uint n = 12; 


        uint amountWithInterest = estimatedInterest;

        uint interest = amountWithInterest - p;
        uint t = timeSinceLastPayment;

        require(amountWithInterest>=amount);

        require(amount>=interest);

        balances[msg.sender] -= interest;
        balances[credit.creditor] += interest;

        amount -= interest;
        credit.monthlyCheckpoint += timeSinceLastPayment;
        credit.amount_paid += interest;

        if(amount>0)
        {
            credit.principal_amount -= amount;
            credit.amount_paid += amount;

            balances[msg.sender] -= amount;
            balances[credit.creditor] += amount;
        }

        if(credit.principal_amount == 0)
        {
            credits[id_].openCredit = false;
            hasOngoingCredit[msg.sender] = false;
            hasOngoingApplication[msg.sender] = false;
            hasOngoingApplication[credit.creditor] = false;
            hasOngoingCredit[credit.creditor] = false;
        }
    }
    function ifApplicationOpen(uint index) returns (bool){
        CreditApplication app = applications[index];
        if(app.openApp) return true; else return false;
    }
    function ifCreditOpen(uint index) returns (bool){
        Credit credit = credits[index];
        if (credit.openCredit == true) return true; else return false;
    }
    function getApplicationData(uint index) returns (uint[], string, address){
        string otherData = applications[index].otherData;
        uint[] memory numericalData = new uint[](4);
        numericalData[0] = index;
        numericalData[1] = applications[index].duration;
        numericalData[2] = applications[index].credit_amount;
        numericalData[3] = applications[index].interest_rate;

        address borrower = applications[index].borrower;
        return (numericalData, otherData, borrower);
    }
    function getCreditData(uint index) returns (uint[], address, address){
        uint[] memory numericalData = new uint[](9);
        numericalData[0] = index;
        numericalData[1] = credits[index].interest_rate;
        numericalData[2] = credits[index].duration;
        numericalData[3] = credits[index].principal_amount;
        numericalData[4] = credits[index].original_amount;
        numericalData[5] = credits[index].amount_paid;
        numericalData[6] = credits[index].startTime;
        numericalData[7] = credits[index].monthlyCheckpoint;
        numericalData[8] = credits[index].appId;

        return (numericalData, credits[index].borrower, credits[index].creditor);
    }
    function getNumApplications() returns (uint) { return numApplications;}
    function getNumCredits() returns (uint) { return numCredits;}
    function isCreditor(address account) returns (bool) {return creditors[account].EXISTS;}
    function isBorrower(address account) returns (bool) {return borrowers[account].EXISTS;}
    function getTime() returns (uint){return now;}
}