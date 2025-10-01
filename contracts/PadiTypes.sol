// SPDX-License-Identifier: MIT
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