// DISCS Certificate of Authorship - Code Comment Block Certification

// Terran M. Chato-211422-MT
// Julia Anishka Espera-212319-MT
// Gabriel I. Geraldo-212734-MT
// Kyle Joshua Ozo-214425-MT
// Ysabella Panghulan-214521-MT

// I hereby attest to the truth of the following facts:

// I have not discussed the Solidity code in my program with anyone
// other than my instructor or the teaching assistants assigned to this course.

// I have not used Solidity code obtained from another student, or
// any other unauthorized source, whether modified or unmodified.

// If any Solidity code or documentation used in my program was
// obtained from another source, it has been clearly noted with citations in the
// comments of my program.


// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;


contract LoanTracker {
    address public admin;
    uint256 public interestRate;
    uint256 public loanCounter;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    uint256 public latePenalty = 500;
    uint256 constant SCALING_FACTOR = 10**2; // represents decimal points
    
    enum LoanStatus { Pending, Approved, Rejected, Completed }

    struct Loan {
        uint256 id;
        address borrower;
        uint256 amount;     // scaled by SCALING_FACTOR
        LoanStatus status;
        uint256 interestRate; // scaled by SCALING_FACTOR
        uint256 amountToBePaid; // scaled by SCALING_FACTOR
        uint256 totalRepaid; // scaled by SCALING_FACTOR
        uint256 createdAt;
        uint256 dueDate;
    }

    modifier onlyAdmin() {  
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Not the borrower");
        _;
    }

    constructor() {
        admin = msg.sender;
        interestRate = 5 * SCALING_FACTOR; // default 5% interest rate
        loanCounter = 0;
    }

    function sample(uint256 xd) public view returns (uint256) {
        uint256 principal = xd * SCALING_FACTOR; // 250 pesos
        return principal + principal * interestRate / 10000;
    }

    function revert_back(uint256 scaled_value) public pure returns (uint256, bool) {
        // original value may have at most a +1 due to the floating point. LoanTracker will treat this as a convenience fee to be processed
        uint256 og = scaled_value / SCALING_FACTOR;
        // uint256 principal = xd * SCALING_FACTOR; // 250 pesos
        bool last_two = scaled_value % 100 == 0;
        return (og, last_two);
    }

    function calculateToBePaid(uint256 principal) internal view returns (uint256) {
        uint256 scaled_principal = principal * 100;
        uint256 scaled_toBePaid = scaled_principal + scaled_principal * interestRate / 10000;
        uint256 final_toBePaid = scaled_toBePaid / 100;

        uint256 last_two = scaled_toBePaid % 100;
        if (last_two == 0) {
            // do nothing because it's exactly 0
        } else {
            // since there is extra, convenience fee will be collected, value collected will be rounded to the nearest integer
            final_toBePaid += 1;
        }
        return final_toBePaid;
    }

    // CREATES A NEW LOAN REQUEST IN THE TRACKER
    // Input is regular amount but this will be scaled when kept inside the contract
    // If the amount to be paid is seen to have a floating point, this value will be rounded up to account for convenience fees.
    function requestLoan(uint256 principal, uint256 installments) external {
        require(installments == 1 || installments == 2 || installments == 4, "Installments must be either 1, 2, or 4");
        

        uint256 createdAt = block.timestamp;
        uint256 dueDate = createdAt + 30 days;
        // uint256 interest = principal * interestRate / 10000;
        uint256 amountToBePaid = calculateToBePaid(principal);


        loans[loanCounter] = Loan({
            id: loanCounter,
            borrower: msg.sender,
            amount: principal,
            interestRate: interestRate,
            amountToBePaid: amountToBePaid,
            status: LoanStatus.Pending,
            totalRepaid: 0,
            createdAt: createdAt,
            dueDate: dueDate
        });

        borrowerLoans[msg.sender].push(loanCounter);
        loanCounter++;
    }
    
    // EVENTS
    event ContractFunded(address funder, uint256 amount);

    // HELPER FUNCTION
    // function getInstallmentAmount(uint256 loanId) internal view returns(uint256) {
    //     Loan storage loan = loans[loanId];
    //     return (loan.amount + loan.amount * loan.interestRate / 10000) / loan.installments;
    // }

    // ADMIN ONLY FUNCTIONS
    function approveLoan(uint256 loanId) external payable onlyAdmin {
        require(loans[loanId].status == LoanStatus.Pending, "Loan not pending");

        Loan storage loan = loans[loanId];

        loan.status = LoanStatus.Approved;
        // loan.dueDate = block.timestamp + 30 days * loan.installments;
        // loan.nextDueDate = block.timestamp + 30 days; // first payment in 1 month
        
        address recipient = loan.borrower;
        uint256 amount = loan.amount;

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function rejectLoan(uint256 loanId) external onlyAdmin {
        require(loans[loanId].status == LoanStatus.Pending, "Loan not pending");
        loans[loanId].status = LoanStatus.Rejected;
    }

    function setInterestRate(uint256 newRate) external onlyAdmin {
        require(newRate <= 10000, "Max interest is 100%");
        interestRate = newRate;
    }
    
///// NOT IN USE YET /////////////////////////////////////////////////////////////////
    // Allow the contract to receive funds
    receive() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }
    
    // Function to fund the contract explicitly
    function fundContract() external payable onlyAdmin {
        require(msg.value > 0, "Must send ETH to fund contract");
        emit ContractFunded(msg.sender, msg.value);
    }
/////////////////////////////////////////////////////////////////////////////////////////////////////////

    // BORROWER ONLY FUNCTIONS FOR LOAN
    function repayLoan(uint256 loanId) external payable onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];



        require(loan.status == LoanStatus.Approved, "Loan not approved");
        require(msg.value == 0, "Must send Ether to repay loan");
        
        loan.totalRepaid += msg.value;
        uint256 totalDue = loan.amount + (loan.amount * loan.interestRate / 10000);

        if (block.timestamp > loan.dueDate) {
            totalDue += (loan.amount * latePenalty / 10000);
        }

        if (loan.totalRepaid >= totalDue) {
            loan.status = LoanStatus.Completed;
        }
    }

    // VIEW LOAN FUNCTIONS
    function getLoan(uint256 loanId) external view onlyAdmin returns (
        uint256 id,
        address borrower,
        uint256 amount,
        uint256 returnInterestRate,
        uint256 amountToBePaid,
        LoanStatus status,
        uint256 totalRepaid,
        uint256 createdAt,
        uint256 dueDate
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.id,
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.amountToBePaid,
            loan.status,
            loan.totalRepaid,
            loan.createdAt,
            loan.dueDate
        );
    }

    function getMyLoan(uint256 loanId) external view onlyBorrower(loanId) returns (
        uint256 id,
        address borrower,
        uint256 amount,
        uint256 returnInterestRate,
        uint256 amountToBePaid,
        LoanStatus status,
        uint256 totalRepaid,
        uint256 createdAt,
        uint256 dueDate
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.id,
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.amountToBePaid,
            loan.status,
            loan.totalRepaid,
            loan.createdAt,
            loan.dueDate
        );
    }

    function getAllLoansData() external view onlyAdmin returns (
        uint256[] memory ids,
        address[] memory borrowers,
        uint256[] memory amounts,
        uint256[] memory interestRates,
        uint256[] memory amountsToBePaid,
        LoanStatus[] memory statuses,
        uint256[] memory totalRepaids,
        uint256[] memory createdAts,
        uint256[] memory dueDates
        // uint256[] memory installments,
        // uint256[] memory nextDueDates,
        // uint256[] memory installmentsPaid
    ) {
        ids = new uint256[](loanCounter);
        borrowers = new address[](loanCounter);
        amounts = new uint256[](loanCounter);
        amountsToBePaid = new uint256[](loanCounter);
        interestRates = new uint256[](loanCounter);
        statuses = new LoanStatus[](loanCounter);
        totalRepaids = new uint256[](loanCounter);
        createdAts = new uint256[](loanCounter);
        dueDates = new uint256[](loanCounter);
        // installments = new uint256[](loanCounter);
        // nextDueDates = new uint256[](loanCounter);
        // installmentsPaid = new uint256[](loanCounter);

        for (uint256 i = 0; i < loanCounter; i++) {
            Loan storage loan = loans[i];
            ids[i] = loan.id;
            borrowers[i] = loan.borrower;
            amounts[i] = loan.amount;
            amountsToBePaid[i] = loan.amountToBePaid;
            interestRates[i] = loan.interestRate;
            statuses[i] = loan.status;
            totalRepaids[i] = loan.totalRepaid;
            createdAts[i] = loan.createdAt;
            dueDates[i] = loan.dueDate;
            // installments[i] = loan.installments;
            // nextDueDates[i] = loan.nextDueDate;
            // installmentsPaid[i] = loan.installmentsPaid;
        }
    }
}