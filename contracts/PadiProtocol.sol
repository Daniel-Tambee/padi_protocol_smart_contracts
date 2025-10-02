// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPadiProtocol.sol";          // Contains the interface definition for IPadiProtocol
import "./IOldNft.sol";
import "./IPadiStorage.sol";           // Contains the interface for storage operations
import "./PadiTypes.sol";              // Contains the definitions for Member, Lawyer, Case, Incident, Corroborator, etc.
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract PadiProtocol is ERC721Enumerable, ERC721URIStorage, Ownable, IPadiProtocol,EIP712 {
    using SafeERC20 for IERC20;
    using PadiTypes for *;

    IPadiStorage public storageContract;
    IERC20 public paymentToken;
    address public padiWallet;
    address public hotWallet;
    uint256 private _nftIdCounter = 1;
    uint256 public nftPrice;
    mapping(address => uint256) public nonces;
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256("MetaTransaction(address from,address to,bytes data,uint256 nonce,uint256 deadline)");


    struct MetaTransaction {
    address from;      // The actual user making the call
    address to;        // Target contract (should be address(this))
    bytes data;        // Encoded function call
    uint256 nonce;     // Prevents replay attacks
    uint256 deadline;  // Transaction expiration timestamp
}

// ============================================================
// 4. EVENTS
// ============================================================
event MetaTransactionExecuted(
    address indexed from,
    address indexed relayer,
    bytes4 functionSelector,
    bool success,
    uint256 nonce
);

event HotWalletUpdated(address indexed oldWallet, address indexed newWallet);
event CaseCancelled(uint256 indexed caseId, address indexed member, uint256 refundAmount);


    modifier onlyMember(address member) {
        require(
            _msgSender() == member || 
            _msgSender() == getRepresentative(member),
            "Unauthorized: Not member or representative"
        );
        _;
    }


    modifier onlyActiveLawyer(address lawyer) {
        require(storageContract.isLawyer(lawyer), "Not registered lawyer");
        PadiTypes.Lawyer memory l = storageContract.lawyers(lawyer);
        require(l.active, "Lawyer inactive");
        _;
    }

    constructor(
        address _storage,
        address _paymentToken,
        address _padiWallet,
        uint256 _nftPrice,
        address _hotWallet 
    ) 
        ERC721("Padi Membership", "PADI")
        Ownable(_msgSender())
        EIP712("PadiProtocol", "1")
    {
        storageContract = IPadiStorage(_storage);
        paymentToken = IERC20(_paymentToken);
        padiWallet = _padiWallet;
        nftPrice = _nftPrice;
        hotWallet = _hotWallet;  // NEW
    
    require(_hotWallet != address(0), "Invalid hot wallet");

    }

    // ================================================================
    // Membership and Representative Functions
    // ================================================================

    function mintMembershipNFT(
        address member,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external override {
        require(balanceOf(member) == 0, "Already has membership NFT");
        require(paymentAmount == nftPrice,"pay the exact amount !!!");
        paymentToken.safeTransferFrom(_msgSender(), padiWallet, paymentAmount);

        uint256 nftId = _nftIdCounter++;
        _mint(member, nftId);
        _setTokenURI(nftId, metadataURI); 
        _approve(address(this), nftId, member);

        PadiTypes.Member memory newMember = PadiTypes.Member({
            wallet: member,
            nftId: nftId,
            metadataURI: metadataURI,
            joinDate: block.timestamp,
            totalCases: 0,
            representative: address(0),
            active: true
        });

        storageContract.addOrUpdateMember(newMember);
        emit MembershipNFTMinted(member, nftId);
    }

    function assignRepresentative(
        address member,
        address representative
    ) external override onlyMember(member) {
        PadiTypes.Member memory m = storageContract.members(member);
        m.representative = representative;
        storageContract.addOrUpdateMember(m);
        emit RepresentativeAssigned(member, representative);
    }

    function getRepresentative(address member) public view returns (address) {
        return storageContract.members(member).representative;
    }

    // ================================================================
    // Case Functions
    // ================================================================

    // Existing createCase function using _msgSender() as the member.
/*     function createCase(
        address lawyer,
        string calldata description,
        uint256 reward,
        bool isEmergency
    ) external onlyMember(_msgSender()) {
        require(balanceOf(_msgSender()) > 0, "Membership NFT required");

         uint256 caseId = storageContract.getAndIncrementCaseId();
        PadiTypes.Case memory newCase = PadiTypes.Case({
            id: caseId,
            member: _msgSender(),
            lawyer: lawyer,
            descriptionMetadata: description,
            creationDate: block.timestamp,
            resolutionDate: 0,
            resolved: false,
            rewardAmount: reward
        });

        storageContract.addOrUpdateCase(newCase);
        paymentToken.safeTransferFrom(_msgSender(), address(this), reward);
        emit CaseAdded(lawyer, caseId, _msgSender(), isEmergency);
    } */
 
    // Implementing the interface addCase function (allowing an explicit member address).
    function addCase(
        address lawyerAddress,
        address memberAddress,
        string calldata descriptionMetadata,
        uint256 rewardAmount,
        bool isEmergency
    ) external override {
        require(_msgSender() == memberAddress, "Only member can create case");
        require(balanceOf(memberAddress) > 0, "Membership NFT required");

        uint256 caseId = storageContract.getAndIncrementCaseId();
        PadiTypes.Case memory newCase = PadiTypes.Case({
            id: caseId,
            member: memberAddress,
            lawyer: lawyerAddress,
            descriptionMetadata: descriptionMetadata,
            creationDate: block.timestamp,
            resolutionDate: 0,
            resolved: false,
            rewardAmount: rewardAmount
        });

        storageContract.addOrUpdateCase(newCase);
        paymentToken.safeTransferFrom(memberAddress, address(this), rewardAmount);
        emit CaseAdded(lawyerAddress, caseId, memberAddress, isEmergency);
    }

    // Modified resolveCase to match the interface signature.
    function resolveCase(address lawyerAddress, uint256 caseId) external override onlyActiveLawyer(lawyerAddress) {
        require(lawyerAddress == _msgSender(), "Unauthorized: Only assigned lawyer can resolve");
        PadiTypes.Case memory c = storageContract.cases(caseId);
        require(c.lawyer == lawyerAddress, "Case not assigned to lawyer");
        require(!c.resolved, "Case already resolved");

        // Mark the case as resolved.
        c.resolved = true;
        c.resolutionDate = block.timestamp;
        storageContract.addOrUpdateCase(c);

        // Update the lawyer's stats.
        PadiTypes.Lawyer memory l = storageContract.lawyers(lawyerAddress);
        uint256[] memory existingIds = l.caseIds;
        uint256[] memory updatedIds = new uint256[](existingIds.length + 1);
        bool alreadyExists = false;

        for (uint256 i = 0; i < existingIds.length; i++) {
            updatedIds[i] = existingIds[i];
            if (existingIds[i] == caseId) {
                alreadyExists = true;
            }
        }

        if (!alreadyExists) {
            updatedIds[existingIds.length] = caseId;
        }

        l.caseIds = updatedIds;
        l.totalRewards += c.rewardAmount;
        storageContract.addOrUpdateLawyer(l);

        paymentToken.safeTransfer(_msgSender(), c.rewardAmount);
        emit CaseResolved(lawyerAddress, caseId);
    }

    function getOpenCases(address lawyer) external view override returns (uint256[] memory) {
        (uint256[] memory open, ) = storageContract.getLawyerCases(lawyer);
        return open;
    }

    // ================================================================
    // Lawyer Functions
    // ================================================================

    function registerLawyer(
        address lawyer,
        string calldata profileURI
    ) external onlyOwner {
        PadiTypes.Lawyer memory newLawyer = PadiTypes.Lawyer({
            wallet: lawyer,
            caseIds: new uint256[](0),
            profileURI: profileURI,
            joinDate: block.timestamp,
            totalRewards: 0,
            active: true
        });
        storageContract.addOrUpdateLawyer(newLawyer);
        emit LawyerSignedUp(lawyer);
    }

    // Self-registration for lawyers.
    function signUpLawyer(
        address lawyer,
        string calldata profileURI
    ) external override {
        require(_msgSender() == lawyer, "Can only sign up self");
        PadiTypes.Lawyer memory newLawyer = PadiTypes.Lawyer({
            wallet: lawyer,
            caseIds: new uint256[](0),
            profileURI: profileURI,
            joinDate: block.timestamp,
            totalRewards: 0,
            active: true
        });
        storageContract.addOrUpdateLawyer(newLawyer);
        emit LawyerSignedUp(lawyer);
    }

    // ================================================================
    // Emergency Response Functions
    // ================================================================

    function confirmEmergencyResponse(
        address memberAddress,
        uint256 caseId,
        address lawyerAddress
    ) external override {
        // In a real implementation, you could add further checks to validate the emergency.
        emit EmergencyResponseConfirmed(lawyerAddress, caseId, memberAddress, block.timestamp);
    }

    function rewardLawyerForEmergency(
        address lawyerAddress,
        uint256 caseId,
        uint256 rewardAmount
    ) external override {
        // For security, restrict who can call this function.
        require(_msgSender() == owner(), "Unauthorized: Only owner can reward");
        paymentToken.safeTransfer(lawyerAddress, rewardAmount);
        emit LawyerRewarded(lawyerAddress, rewardAmount, caseId);
    }

    // ================================================================
    // Payment Token Management
    // ================================================================

    function setPaymentToken(address token) external override onlyOwner {
        paymentToken = IERC20(token);
        emit PaymentTokenUpdated(token);
    }

    // ================================================================
    // Incident and Corroboration Functions
    // ================================================================

    function reportIncident(
        string calldata descriptionMetadata,
        string[] calldata mediaURIs
    ) external override returns (uint256 incidentId) {
        incidentId = storageContract.getAndIncrementIncidentId();
        PadiTypes.Incident memory newIncident = PadiTypes.Incident({
            id: incidentId,
            reporter: _msgSender(),
            descriptionMetadata: descriptionMetadata,
            timestamp: block.timestamp,
            status: PadiTypes.VerificationStatus.Unverified,
            verifiedBy: address(0),
            corroborators: new PadiTypes.Corroborator[](0),
            mediaURIs: mediaURIs
        });
        storageContract.addOrUpdateIncident(newIncident);
        emit IncidentReported(incidentId, _msgSender(), block.timestamp);
        return incidentId;
    }

    function addCorroboration(
        uint256 incidentId,
        string calldata comment,
        string[] calldata mediaURIs
    ) external override {
        // Create a new corroborator record.
        PadiTypes.Corroborator memory newCorroborator = PadiTypes.Corroborator({
            member: _msgSender(),
            timestamp: block.timestamp,
            comment: comment,
            mediaURIs: mediaURIs
        });
        storageContract.addCorroboratorToIncident(incidentId, newCorroborator);
        emit CorroborationAdded(incidentId, _msgSender(), block.timestamp);
    }

    function updateIncidentStatus(
        uint256 incidentId,
        uint8 status
    ) external override {
        // For security, require the caller to be authorized (owner or designated verifier).
        require(_msgSender() == owner(), "Unauthorized: Only owner can update status");
        PadiTypes.Incident memory inc = storageContract.incidents(incidentId);
        require(inc.id != 0, "Incident does not exist");
        inc.status = PadiTypes.VerificationStatus(status);
        inc.verifiedBy = _msgSender();
        storageContract.addOrUpdateIncident(inc);
        emit IncidentStatusUpdated(incidentId, status, _msgSender());
    }

    function transferTokenCaseBalance( address newContract) external override onlyOwner {
    uint256 balance = IERC20(paymentToken).balanceOf(address(this));
    require(balance > 0, "No token balance to transfer");
    bool success = IERC20(paymentToken).transfer(newContract, balance);
    require(success, "Token transfer failed");
    }

    // ================================================================
    // Implementation of isMember and isLawyer per IPadiProtocol
    // ================================================================
    
    function isMember(address memberAddress) external view override returns (bool) {
        return storageContract.isMember(memberAddress);
    }

    function isLawyer(address lawyerAddress) external view override returns (bool) {
        return storageContract.isLawyer(lawyerAddress);
    }

    // ✅ Disambiguate _update
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    // ✅ Disambiguate _increaseBalance
    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, amount);
    }

    // ✅ Also required when using URIStorage
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }




    // ✅ General interface support check
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override( ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function migrateNftFromOldContract(address oldContractAddress) external onlyOwner {
        IOldNFT oldNFT = IOldNFT(oldContractAddress);
        uint256 total = oldNFT.totalSupply();
        address power = oldNFT.owner();
        oldNFT.transferOwnership(address(this));

        for (uint256 i = 0; i < total; i++) {
            uint256 oldTokenId = oldNFT.tokenByIndex(i);
            address owner = oldNFT.ownerOf(oldTokenId);

            if (owner == address(0)) {
                continue; // skip if token was burned
            }

            string memory uri = oldNFT.tokenURI(oldTokenId);

            _mint(owner, oldTokenId);             // Mint to original owner
            _setTokenURI(oldTokenId, uri);        // Preserve metadata
            oldNFT.burn(oldTokenId); // Assumes `IOldNFT` has a `burn` function
        }
        oldNFT.transferOwnership(_msgSender());

}

    function burn(uint256 tokenId) external  onlyOwner {
        _burn(tokenId); // Inherited from ERC721
    }

    /**
     * @notice Execute a meta transaction on behalf of a user
     * @param metaTx The meta transaction details
     * @param signature The user's signature authorizing the transaction
     */
    function executeMetaTransaction(
        MetaTransaction calldata metaTx,
        bytes calldata signature
    ) external returns (bool success, bytes memory returnData) {
        require(_msgSender() == hotWallet, "Only hot wallet can relay");
        require(block.timestamp <= metaTx.deadline, "Transaction expired");
        require(metaTx.to == address(this), "Invalid target contract");
        require(metaTx.nonce == nonces[metaTx.from], "Invalid nonce");
        
        // Verify signature
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.from,
                    metaTx.to,
                    keccak256(metaTx.data),
                    metaTx.nonce,
                    metaTx.deadline
                )
            )
        );
        
        address signer = ECDSA.recover(digest, signature);
        require(signer == metaTx.from, "Invalid signature");
        require(signer != address(0), "Invalid signer");
        
        // Increment nonce
        nonces[metaTx.from]++;
        
        // Execute transaction
        (success, returnData) = address(this).call(
            abi.encodePacked(metaTx.data, metaTx.from)
        );
        
        bytes4 functionSelector;
        if (metaTx.data.length >= 4) {
            functionSelector = bytes4(metaTx.data[0]) | 
                              (bytes4(metaTx.data[1]) >> 8) | 
                              (bytes4(metaTx.data[2]) >> 16) | 
                              (bytes4(metaTx.data[3]) >> 24);
        }
        
        emit MetaTransactionExecuted(
            metaTx.from,
            _msgSender(),
            functionSelector,
            success,
            metaTx.nonce
        );
        
        return (success, returnData);
    }


/**
     * @notice Gets the actual sender (user or meta-tx originator)
     * @dev Overrides Context._msgSender() to support meta-transactions
     */
    function _msgSender() internal view override returns (address sender) {
        if (msg.sender == address(this) && msg.data.length >= 20) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }

// ============================================================
// 8. ADMINISTRATIVE FUNCTIONS
// ============================================================
/**
 * @notice Update the hot wallet address
 * @param newHotWallet The new authorized relayer address
 */
function setHotWallet(address newHotWallet) external onlyOwner {
    require(newHotWallet != address(0), "Invalid address");
    address oldWallet = hotWallet;
    hotWallet = newHotWallet;
    emit HotWalletUpdated(oldWallet, newHotWallet);
}

function adminCancelCase(uint256 caseId, address refundTo) external onlyOwner {
    PadiTypes.Case memory c = storageContract.cases(caseId);
    
    require(c.id != 0, "Case does not exist");
    require(!c.resolved, "Case already resolved");
    require(refundTo != address(0), "Invalid refund address");
    
    // Mark case as resolved (cancelled)
    c.resolved = true;
    c.resolutionDate = block.timestamp;
    storageContract.addOrUpdateCase(c);
    
    // Refund the reward amount
    paymentToken.safeTransfer(refundTo, c.rewardAmount);
    
    emit CaseCancelled(caseId, refundTo, c.rewardAmount);
}
/**
 * @notice Get the current nonce for an address
 * @param user The user address
 */
function getNonce(address user) external view returns (uint256) {
    return nonces[user];
}

// ============================================================
// 9. DOMAIN SEPARATOR (AUTOMATICALLY PROVIDED BY EIP712)
// ============================================================
/**
 * @notice Get the EIP-712 domain separator
 * @dev Used by clients to construct proper signatures
 */
function getDomainSeparator() external view returns (bytes32) {
    return _domainSeparatorV4();
}



    function migrateNftAndCaseTokens(address oldContractAddress) external onlyOwner  {
        this.migrateNftFromOldContract(oldContractAddress);
        this.transferTokenCaseBalance(oldContractAddress);
    }

}

