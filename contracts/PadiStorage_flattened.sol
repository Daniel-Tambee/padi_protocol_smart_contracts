
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/PadiTypes.sol


pragma solidity ^0.8.0;

library PadiTypes {
    struct Member {
        address wallet;
        address representative;     
        uint256 nftId;
        string metadataURI;
        uint256 joinDate;
        uint256 totalCases;
        bool active;
    }

    struct Lawyer {
        address wallet;
        uint256[] caseIds;
        string profileURI;
        uint256 joinDate;
        uint256 totalRewards;
        bool active;
    }

    struct Case {
        uint256 id;
        address member;
        address lawyer;
        string descriptionMetadata;
        uint256 creationDate;
        uint256 resolutionDate;
        bool resolved;
        uint256 rewardAmount;
    }

    enum VerificationStatus { Unverified, Verified, Rejected }

    struct Corroborator {
        address member;
        uint256 timestamp;
        string comment;
        string[] mediaURIs;
    }

    struct Incident {
        uint256 id;
        address reporter;
        string descriptionMetadata;
        uint256 timestamp;
        VerificationStatus status;
        address verifiedBy;
        Corroborator[] corroborators;
        string[] mediaURIs;
    }
}
// File: contracts/IPadiStorage.sol


pragma solidity ^0.8.0;


interface IPadiStorage {
    // *********************
    // Existing Storage Functions
    // *********************
    function members(address memberAddress) external view returns (PadiTypes.Member memory);
    function lawyers(address lawyerAddress) external view returns (PadiTypes.Lawyer memory);
    function cases(uint256 caseId) external view returns (PadiTypes.Case memory);
    function isMember(address user) external view returns (bool);
    function isLawyer(address user) external view returns (bool);
    function getLawyerCases(address lawyer) external view returns (uint256[] memory, uint256[] memory);
    function addOrUpdateMember(PadiTypes.Member calldata member) external;
    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) external;
    function addOrUpdateCase(PadiTypes.Case calldata _case) external;
    function getAndIncrementCaseId() external returns (uint256);

    // *********************
    // New Functions for Incidents and Corroborators
    // *********************
    /**
     * @notice Retrieve a specific incident by its identifier.
     * @param incidentId The unique identifier of the incident.
     * @return An Incident struct containing details such as reporter, description, status, evidence, and corroborators.
     */
    function incidents(uint256 incidentId) external view returns (PadiTypes.Incident memory);

    /**
     * @notice Add a new incident or update an existing one.
     * @param incident The Incident struct containing all relevant data.
     */
    function addOrUpdateIncident(PadiTypes.Incident calldata incident) external;

    /**
     * @notice Generate a new unique incident identifier and increment the internal counter.
     * @return The new incident ID.
     */
    function getAndIncrementIncidentId() external returns (uint256);

    /**
     * @notice Append a new corroborator entry to an existing incident.
     * @param incidentId The unique identifier for the incident.
     * @param corroborator The Corroborator struct containing the member, comment, media evidence, and timestamp.
     */
    function addCorroboratorToIncident(uint256 incidentId, PadiTypes.Corroborator calldata corroborator) external;
}

// File: contracts/PadiStorage.sol


pragma solidity ^0.8.0;




contract PadiStorage is IPadiStorage, Ownable {
    using PadiTypes for *;

    address public padiProtocol;
    uint256 public nextMemberId = 1;
    uint256 public nextCaseId = 1;
    uint256 public nextIncidentId = 1;

    mapping(address => PadiTypes.Member) public membersMap;
    mapping(address => PadiTypes.Lawyer) public lawyersMap;
    mapping(uint256 => PadiTypes.Case) public casesMap;
    mapping(uint256 => PadiTypes.Incident) public incidentsMap;

    mapping(address => bool) public isMemberMap;
    mapping(address => bool) public isLawyerMap;

    mapping(address => uint256[]) private lawyerOpenCases;
    mapping(address => uint256[]) private lawyerClosedCases;

    event MemberUpdated(address indexed wallet, uint256 nftId, bool active);
    event LawyerUpdated(address indexed wallet, bool active);
    event CaseUpdated(uint256 indexed caseId, address indexed member, address indexed lawyer, bool resolved);
    event IncidentReported(uint256 indexed incidentId, address indexed reporter, uint256 timestamp);
    event CorroborationAdded(uint256 indexed incidentId, address indexed corroborator, uint256 timestamp);

    modifier onlyPadiProtocol() {
        require(msg.sender == padiProtocol, "Unauthorized access");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function initializeProtocol(address _padiProtocol) external onlyOwner {
        require(_padiProtocol != address(0), "Invalid protocol address");
        padiProtocol = _padiProtocol;
    }

    // ---------------------------
    // Case-Related Functions
    // ---------------------------
    function getAndIncrementCaseId() external override onlyPadiProtocol returns (uint256) {
        return nextCaseId++;
    }

    function addOrUpdateMember(PadiTypes.Member calldata member) external override onlyPadiProtocol {
        require(member.wallet != address(0), "Invalid member address");
        membersMap[member.wallet] = member;
        isMemberMap[member.wallet] = member.active;
        emit MemberUpdated(member.wallet, member.nftId, member.active);
    }

    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) external override onlyPadiProtocol {
        require(lawyer.wallet != address(0), "Invalid lawyer address");
        lawyersMap[lawyer.wallet] = lawyer;
        isLawyerMap[lawyer.wallet] = lawyer.active;
        emit LawyerUpdated(lawyer.wallet, lawyer.active);
    }

    function addOrUpdateCase(PadiTypes.Case calldata _case) external override onlyPadiProtocol {
        require(_case.id != 0, "Invalid case ID");
        require(_case.member != address(0), "Invalid member");
        require(_case.lawyer != address(0), "Invalid lawyer");

        if (_case.resolved) {
            _moveCaseToClosed(_case);
        } else {
            _addToOpenCases(_case);
        }

        casesMap[_case.id] = _case;
        emit CaseUpdated(_case.id, _case.member, _case.lawyer, _case.resolved);
    }

    function getLawyerCases(address lawyer) external view override returns (uint256[] memory open, uint256[] memory closed) {
        return (lawyerOpenCases[lawyer], lawyerClosedCases[lawyer]);
    }

    function _addToOpenCases(PadiTypes.Case calldata _case) private {
        uint256[] storage casesArray = lawyerOpenCases[_case.lawyer];
        if (!_existsInArray(casesArray, _case.id)) {
            casesArray.push(_case.id);
        }
    }

    function _moveCaseToClosed(PadiTypes.Case calldata _case) private {
        uint256[] storage open = lawyerOpenCases[_case.lawyer];
        for (uint256 i = 0; i < open.length; i++) {
            if (open[i] == _case.id) {
                open[i] = open[open.length - 1];
                open.pop();
                break;
            }
        }
        lawyerClosedCases[_case.lawyer].push(_case.id);
    }

    function _existsInArray(uint256[] storage arr, uint256 value) private view returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }

    function isMember(address user) external view override returns (bool) {
        return isMemberMap[user];
    }

    function isLawyer(address user) external view override returns (bool) {
        return isLawyerMap[user];
    }

    function lawyers(address lawyerAddress) external view override returns (PadiTypes.Lawyer memory) {
        return lawyersMap[lawyerAddress];
    }

    function members(address memberAddress) external view override returns (PadiTypes.Member memory) {
        return membersMap[memberAddress];
    }

    function cases(uint256 caseId) external view override returns (PadiTypes.Case memory) {
        return casesMap[caseId];
    }

    // ---------------------------
    // Incident-Related Functions
    // ---------------------------
    function incidents(uint256 incidentId) external view override returns (PadiTypes.Incident memory) {
        return incidentsMap[incidentId];
    }

    function addOrUpdateIncident(PadiTypes.Incident calldata incident) external override onlyPadiProtocol {
        require(incident.id != 0, "Invalid incident id");
        incidentsMap[incident.id] = incident;
        emit IncidentReported(incident.id, incident.reporter, incident.timestamp);
    }

    function getAndIncrementIncidentId() external override onlyPadiProtocol returns (uint256) {
        return nextIncidentId++;
    }

    function addCorroboratorToIncident(uint256 incidentId, PadiTypes.Corroborator calldata corroborator) external override onlyPadiProtocol {
        PadiTypes.Incident storage inc = incidentsMap[incidentId];
        require(inc.id != 0, "Incident does not exist");
        inc.corroborators.push(corroborator);
        emit CorroborationAdded(incidentId, corroborator.member, block.timestamp);
    }
}

