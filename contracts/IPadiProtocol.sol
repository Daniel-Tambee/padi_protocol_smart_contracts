// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPadiProtocol {
    /**
     * @notice Mint an NFT ID card for a new member.
     * @param memberAddress The address of the new member.
     * @param metadataURI The metadata URI for the NFT.
     * @param paymentAmount The amount of the specific token to be paid.
     */
    function mintMembershipNFT(
        address memberAddress,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external;

    /**
     * @notice Assign a legal representative (Padi) to a member.
     * @param memberAddress The address of the member.
     * @param representativeAddress The address of the legal representative.
     */
    function assignRepresentative(
        address memberAddress,
        address representativeAddress
    ) external;

    /**
     * @notice Confirm that a lawyer (Padi) has responded to an emergency call from a member.
     * @param memberAddress The address of the member calling for help.
     * @param caseId The unique identifier for the case.
     * @param lawyerAddress The address of the lawyer (Padi) responding to the emergency.
     */
    function confirmEmergencyResponse(
        address memberAddress,
        uint256 caseId,
        address lawyerAddress
    ) external;

    /**
     * @notice Reward a lawyer (Padi) after confirming their response to an emergency.
     * @param lawyerAddress The address of the lawyer (Padi).
     * @param caseId The unique identifier for the case.
     * @param rewardAmount The amount of tokens to reward the lawyer.
     */
    function rewardLawyerForEmergency(
        address lawyerAddress,
        uint256 caseId,
        uint256 rewardAmount
    ) external;

    /**
     * @notice Sign up a lawyer as a legal representative.
     * @param lawyerAddress The address of the lawyer signing up.
     * @param profileUri The URI pointing to the lawyer's profile.
     */
    function signUpLawyer(
        address lawyerAddress,
        string calldata profileUri
    ) external;

    /**
     * @notice Track a new case for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param memberAddress The address of the member involved in the case.
     * @param descriptionMetadata A URI describing the case.
     * @param rewardAmount The reward amount associated with the case.
     */
    function addCase(
        address lawyerAddress,
        address memberAddress,
        string calldata descriptionMetadata,
        uint256 rewardAmount,
        bool isEmergency
    ) external;

    /**
     * @notice Mark a case as resolved for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     */
    function resolveCase(address lawyerAddress, uint256 caseId) external;

    /**
     * @notice Get the list of open cases for a lawyer.
     * @param lawyerAddress The address of the lawyer.
     * @return caseIds An array of unique identifiers for open cases.
     */
    function getOpenCases(
        address lawyerAddress
    ) external returns (uint256[] memory caseIds);

    /**
     * @notice Check if an address is a verified member.
     * @param memberAddress The address to check.
     * @return isVerified True if the address is a verified member.
     */
    function isMember(
        address memberAddress
    ) external view returns (bool isVerified);

    /**
     * @notice Check if an address is a registered lawyer.
     * @param lawyerAddress The address to check.
     * @return isRegistered True if the address is a registered lawyer.
     */
    function isLawyer(
        address lawyerAddress
    ) external view returns (bool isRegistered);

    /**
     * @notice Get the legal representative of a member.
     * @param memberAddress The address of the member.
     * @return representativeAddress The address of the legal representative.
     */
    function getRepresentative(
        address memberAddress
    ) external view returns (address representativeAddress);

    /**
     * @notice Set the token contract address used for payments.
     * @param tokenAddress The address of the token contract.
     */
    function setPaymentToken(address tokenAddress) external;

    // -------------------------------------------------------------------------
    // New functions and events for Incident and Corroborator interactions
    // -------------------------------------------------------------------------

    /**
     * @notice Report a new incident of abuse or misconduct.
     * @param descriptionMetadata A URI with details about the incident.
     * @param mediaURIs An array of URIs pointing to evidence (e.g., images, videos).
     * @return incidentId The unique identifier for the reported incident.
     */
    function reportIncident(
        string calldata descriptionMetadata,
        string[] calldata mediaURIs
    ) external returns (uint256 incidentId);

    /**
     * @notice Add a corroboration (supporting evidence) to an existing incident.
     * @param incidentId The unique identifier for the incident.
     * @param comment A comment providing additional context.
     * @param mediaURIs An array of URIs pointing to supplementary evidence.
     */
    function addCorroboration(
        uint256 incidentId,
        string calldata comment,
        string[] calldata mediaURIs
    ) external;

    /**
     * @notice Update the verification status of an incident.
     * @param incidentId The unique identifier for the incident.
     * @param status The new verification status (0: Unverified, 1: Verified, 2: Rejected).
     */
    function updateIncidentStatus(
        uint256 incidentId,
        uint8 status
    ) external;

    function transferTokenCaseBalance(address newContract) external;


    // -------------------------------------------------------------------------
    // Events for Incident and Corroborator interactions
    // -------------------------------------------------------------------------

    /**
     * @notice Event emitted when a membership NFT is minted.
     * @param memberAddress The address of the new member.
     * @param tokenId The ID of the minted NFT.
     */
    event MembershipNFTMinted(
        address indexed memberAddress,
        uint256 indexed tokenId
    );

    /**
     * @notice Event emitted when a legal representative is assigned to a member.
     * @param memberAddress The address of the member.
     * @param representativeAddress The address of the legal representative.
     */
    event RepresentativeAssigned(
        address indexed memberAddress,
        address indexed representativeAddress
    );

    /**
     * @notice Event emitted when a lawyer is rewarded after confirming an emergency response.
     * @param lawyerAddress The address of the lawyer receiving the reward.
     * @param rewardAmount The amount of reward given to the lawyer.
     * @param caseId The unique identifier for the case.
     */
    event LawyerRewarded(
        address indexed lawyerAddress,
        uint256 rewardAmount,
        uint256 caseId
    );

    /**
     * @notice Event emitted when a lawyer signs up as a legal representative.
     * @param lawyerAddress The address of the lawyer signing up.
     */
    event LawyerSignedUp(address indexed lawyerAddress);

    /**
     * @notice Event emitted when a new case is added for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     * @param memberAddress The address of the member involved in the case.
     */
    event CaseAdded(
        address indexed lawyerAddress,
        uint256 indexed caseId,
        address indexed memberAddress,
        bool isEmergency
    );

    /**
     * @notice Event emitted when a case is resolved for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     */
    event CaseResolved(address indexed lawyerAddress, uint256 indexed caseId);

    /**
     * @notice Event emitted when the payment token is updated.
     * @param tokenAddress The new token contract address.
     */
    event PaymentTokenUpdated(address indexed tokenAddress);

    /**
     * @notice Event emitted when an emergency response is confirmed by a lawyer.
     * @param lawyerAddress The address of the lawyer responding to the emergency.
     * @param caseId The unique identifier for the case.
     * @param memberAddress The address of the member involved.
     * @param timestamp The time when the response was confirmed.
     */
    event EmergencyResponseConfirmed(
        address indexed lawyerAddress,
        uint256 indexed caseId,
        address indexed memberAddress,
        uint256 timestamp
    );

    event Testing(address owner, uint256 oldTokenId);


    /**
     * @notice Event emitted when a new incident is reported.
     * @param incidentId The unique identifier for the incident.
     * @param reporter The address of the member reporting the incident.
     * @param timestamp The time when the incident was reported.
     */
    event IncidentReported(
        uint256 indexed incidentId,
        address indexed reporter,
        uint256 timestamp
    );

    /**
     * @notice Event emitted when a corroboration is added to an incident.
     * @param incidentId The unique identifier for the incident.
     * @param corroborator The address of the member adding the corroboration.
     * @param timestamp The time when the corroboration was added.
     */
    event CorroborationAdded(
        uint256 indexed incidentId,
        address indexed corroborator,
        uint256 timestamp
    );

    /**
     * @notice Event emitted when an incident's verification status is updated.
     * @param incidentId The unique identifier for the incident.
     * @param status The new verification status (0: Unverified, 1: Verified, 2: Rejected).
     * @param verifier The address of the entity that updated the status.
     */
    event IncidentStatusUpdated(
        uint256 indexed incidentId,
        uint8 status,
        address indexed verifier
    );
}
