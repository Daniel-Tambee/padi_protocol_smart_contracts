// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./PadiTypes.sol";

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
