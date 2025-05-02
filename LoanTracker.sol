// DISCS Certificate of Authorship - Code Comment Block Certification
// [Student Full Name]-[ID Number]-[Section]

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
    
    enum LoanStatus { Pending, Approved, Rejected, Completed }

    struct Loan {
        uint256 id;
        address borrower;
        uint256 amount;
        uint256 interestRate;
        LoanStatus status;
        uint256 totalRepaid;
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
        interestRate = 500; // default 5% interest rate
    }


    function setInterestRate(uint256 newRate) external onlyAdmin {
        require(newRate <= 10000, "Max interest is 100%");
        interestRate = newRate;
    }

    function requestLoan(uint256 amount) external {
        loanCounter++;

        uint256 createdAt = block.timestamp;
        uint256 dueDate = createdAt + 30 days;

        loans[loanCounter] = Loan({
            id: loanCounter,
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            status: LoanStatus.Pending,
            totalRepaid: 0,
            createdAt: createdAt,
            dueDate: dueDate
        });

        borrowerLoans[msg.sender].push(loanCounter);
    }

    function approveLoan(uint256 loanId) external onlyAdmin {
        require(loans[loanId].status == LoanStatus.Pending, "Loan not pending");
        loans[loanId].status = LoanStatus.Approved;
    }

    function rejectLoan(uint256 loanId) external onlyAdmin {
        require(loans[loanId].status == LoanStatus.Pending, "Loan not pending");
        loans[loanId].status = LoanStatus.Rejected;
    }

    function repayLoan(uint256 loanId, uint256 amount) external onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];

        require(loan.status == LoanStatus.Approved, "Loan not approved");

        loan.totalRepaid += amount;
        uint256 totalDue = loan.amount + (loan.amount * loan.interestRate / 10000);

        if (block.timestamp > loan.dueDate) {
            totalDue += (loan.amount * latePenalty / 10000);
        }

        if (loan.totalRepaid >= totalDue) {
            loan.status = LoanStatus.Completed;
        }
    }
}