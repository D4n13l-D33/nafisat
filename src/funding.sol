// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "./StudentFundingTkn.sol";

contract FundingStudent is Pausable, ReentrancyGuard, Ownable {
    ERC20 private _nativeToken;
    uint256 public proposalCount;
    uint256 public proposalDeadline;

    struct Student {
        address student;
        string imageIPFSHash;
        uint256 disbursedBalance;
    }

    struct Proposal {
        uint256 proposalId;
        address student;
        string description;
        string title;
        string referral;
        ProposalStatus status;
        string imageIPFSHashTranscript;
        uint256 amount;
        bool approved;
        bool disbursed;
    }

    enum ProposalStatus {
        Pending,
        Approved,
        Denied,
        Closed,
        Executed
    }

    Proposal[] public pendingProposals;
    Proposal[] public approvedProposals;
    mapping(address => Student) public registeredStudents;
    mapping(address => Proposal) public proposalByAddress;
    mapping(address => bool) public isStudent;
    mapping(address => bool) public revoked;
    mapping(address => uint256) public studentMap;

    event StudentRegistered(
        address indexed student,
        string indexed imageIPFSHash
    );
    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed student
    );
    event Status(uint256 indexed proposalId, ProposalStatus indexed status);
    event ProposalClosed(
        uint256 indexed proposalId,
        ProposalStatus indexed status
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        ProposalStatus indexed status
    );
    event Donation(address indexed donor, uint256 amount, uint256 timestamp);
    event Revoked(address indexed studentAddress, uint256 timestamp);

    modifier validStudent() {
        require(isStudent[msg.sender], "Not a student");
        _;
    }

    modifier notRevoked() {
        require(!revoked[msg.sender], "Revoked");
        _;
    }

    modifier onlyOwnerOrEscrow() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    constructor(address nativeToken) Ownable(msg.sender) {
        _nativeToken = ERC20(nativeToken);
    }

    receive() external payable {}

    function registerStudent(string memory _imageIPFSHash) external {
        require(!isStudent[msg.sender], "Student is already registered");
        require(
            bytes(_imageIPFSHash).length > 0,
            "Image IPFS hash must not be empty"
        );
        isStudent[msg.sender] = true;
        Student storage student = registeredStudents[msg.sender];
        student.student = msg.sender;
        student.imageIPFSHash = _imageIPFSHash;

        emit StudentRegistered(msg.sender, _imageIPFSHash);
    }

    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _amount,
        string memory _imageIPFSHash,
        string memory _referral
    ) external validStudent returns (uint256 id) {
        require(!revoked[msg.sender], "You are revoked due to offence");
        Proposal storage proposal = proposalByAddress[msg.sender];
        proposal.student = msg.sender;
        proposal.proposalId = proposalCount;
        proposal.description = _description;
        proposal.imageIPFSHashTranscript = _imageIPFSHash;
        proposal.status = ProposalStatus.Pending;
        proposal.amount = _amount;
        proposal.title = _title;
        proposal.referral = _referral;

        pendingProposals.push(proposal);

        emit ProposalCreated(proposalCount, _description, msg.sender);
        proposalCount += 1;
        id = proposal.proposalId;
    }

    function approveProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = pendingProposals[_proposalId];
        require(
            proposal.status == ProposalStatus.Pending,
            "Proposal not pending"
        );
        proposal.status = ProposalStatus.Approved;
        approvedProposals.push(proposal);

        emit Status(_proposalId, ProposalStatus.Approved);
    }

    function getApprovedProposals() external view returns (Proposal[] memory) {
        return approvedProposals;
    }

    function getPendingProposals() external view returns (Proposal[] memory) {
        return pendingProposals;
    }

    function closeProposal(uint256 _proposalId) private {
        Proposal storage proposal = approvedProposals[_proposalId];
        proposal.status = ProposalStatus.Closed;
        emit ProposalClosed(_proposalId, ProposalStatus.Closed);
    }

    function donate(uint256 _amount, uint256 _proposalId) external payable {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            approvedProposals[_proposalId].amount >
                studentMap[approvedProposals[_proposalId].student],
            "Proposal Amount Reached, Thank you!. Please Consider other Proposals"
        );
        require(
            _nativeToken.balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );
        uint256 usdtAmount = _amount;

        //Transfer USDT tokens from the sender to this contract
        require(
            _nativeToken.transferFrom(msg.sender, address(this), usdtAmount),
            "Token transfer failed"
        );

        // Update student's balance
        studentMap[approvedProposals[_proposalId].student] += usdtAmount;

        emit Donation(msg.sender, usdtAmount, block.timestamp);
    }

    function withdraw(uint256 _amount) external validStudent {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            _nativeToken.balanceOf(address(this)) >= _amount,
            "Insufficient balance"
        );
        //update the state variable
        Proposal storage proposal = proposalByAddress[msg.sender];
        //withdraw
        studentMap[proposal.student] -= _amount;
        _nativeToken.transferFrom(address(this), msg.sender, _amount);
    }

    function disburseFund(uint256 _proposalId) external nonReentrant onlyOwner {
        require(_proposalId < approvedProposals.length, "Invalid proposal ID");
        require(
            approvedProposals[_proposalId].status == ProposalStatus.Approved,
            "Proposal not approved"
        );
        require(
            !approvedProposals[_proposalId].disbursed,
            "Loan already disbursed"
        );
        require(studentMap[approvedProposals[_proposalId].student] >= approvedProposals[_proposalId].amount, "Amount not reached yet");
        
        approvedProposals[_proposalId].disbursed = true;

        closeProposal(_proposalId);
        
        registeredStudents[approvedProposals[_proposalId].student].disbursedBalance += approvedProposals[_proposalId].amount;


        emit Donation(
            approvedProposals[_proposalId].student,
            approvedProposals[_proposalId].amount,
            block.timestamp
        );
    }

    function changeProposalState(
        uint256 _proposalId,
        bool _proposalState
    ) external onlyOwner {
        require(_proposalId < pendingProposals.length, "Invalid proposal ID");
        Proposal storage proposal = pendingProposals[_proposalId];
        require(
            proposal.status == ProposalStatus.Pending,
            "Proposal status not pending"
        );

        if (_proposalState) {
            proposal.status = ProposalStatus.Approved;
        } else {
            proposal.status = ProposalStatus.Denied;
        }

        emit Status(_proposalId, proposal.status);
    }

    function revokeStudent(address _student) external onlyOwner {
        require(isStudent[_student], "Not a student");
        isStudent[_student] = false;

        emit Revoked(_student, block.timestamp);
    }

    function updateProposalDeadline(
        uint256 _proposalDeadline
    ) external onlyOwner {
        proposalDeadline = _proposalDeadline;
    }

    // function getProposalStatus(
    //     uint256 _proposalId
    // ) external view returns (ProposalStatus) {
    //     require(_proposalId < proposals.length, "Invalid proposal ID");
    //     return proposals[_proposalId].status;
    // }

    function pauseContract() external onlyOwner {
        super._pause();
    }

    function unpauseContract() external onlyOwner {
        super._unpause();
    }

    function rewardNFT(
        address _recipient,
        uint256 _tokenId,
        string memory _tokenURI
    ) external onlyOwner {
        //_nftContract.mint(_recipient, _tokenId);
        //_nftContract.setTokenURI(_tokenId, _tokenURI);
    }
}

// // Compatible with OpenZeppelin Contracts ^5.0.0
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract FundToken is ERC20, Ownable {
//     constructor()
//         ERC20("MyToken", "MTK")
//         Ownable(msg.sender)
//     { _mint(msg.sender, 1000000000000000000000000000);

//     }

// }
