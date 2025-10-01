// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PadiTypes.sol";
import "./IPadiStorage.sol";

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

