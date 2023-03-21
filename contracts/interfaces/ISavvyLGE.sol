// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

// @title Savvy LGE (Liquidity Generation Event)
// @author Savvy DeFi
// @dev a fair and equitable way for the community to seed liquidity for Savvy

interface ISavvyLGE {
    struct VestMode {
        // Vesting duration for each vest mode
        uint256 duration;
        // The allotment boost when participating with this vest length (e.g. 12000 = 20% boost)
        uint256 boostMultiplier;
    }

    struct UserBuyInfo {
        // Amount of depositToken deposited by the user
        uint256 deposited;
        // Allotments bought by the user
        uint256 allotments;
        // Total boost applied to user
        uint256 totalBoost;
        // The user's weighted average duration for vesting
        uint256 duration;
    }

    struct NFTCollectionInfo {
        // The allotment boost when participating with this NFT (e.g. 12000 = 20% boost)
        uint256 boostMultiplier;
        // MAX deposit that can be added for each NFT within collection
        uint256 limit;
    }

    struct NFTAllocationInfo {
        // DepositToken amount remaining for each NFT
        uint256 remaining;
        // True if the NFT has been used at all
        bool activated;
    }

    struct PreviewBuy {
        // Allotments bought during this purchase.
        uint256 allotments;
        // Vest length of this purchase.
        uint256 vestDuration;
        // Boost as a result of vest.
        uint256 vestBoost;
        // Boost as a result of NFT.
        uint256 nftBoost;
        // Account's total allotments with this purchase.
        uint256 totalAllotments;
        // Account's updated vest length with this purchase.
        uint256 totalVestDuration;
    }
    
    struct LGEDetails {
        uint256 lgeStartTimestamp;
        uint256 lgeEndTimestamp;
        uint256 vestStartTimestamp;
        VestMode[] vestModes;
        uint256[] nftBoostDecays;
        address protocolToken;
        address depositToken;
        uint256 basePricePerAllotment;
    }

    struct LGEFrontendInfo {
        uint256 totalDeposited;
        uint256 totalAllotments;
        uint256 currentNFTBoost;
        uint256 userDepositBalance;
        UserBuyInfo userBuyInfo;
    }

    // @notice Admin function to pause LGE sale.
    function pause() external;

    // @notice Admin function to unpause LGE sale.
    function unpause() external;

    
    /// @notice Get info for a given NFT collection addres.
    /// @param nftCollectionAddress The address of nft collection.
    /// @return The information of nft collection.
    function getNFTCollectionInfo(
        address nftCollectionAddress
    ) external view returns (NFTCollectionInfo memory);

    /// @notice admin function to update info for a given NFT collection address.
    /// @param nftCollectionAddress The address of NFT collection.
    /// @param boostMultiplier BoostMultiplier for NFT.
    /// @param limit The limit amount for nft collection.
    function setNFTCollectionInfo(
        address[] memory nftCollectionAddress,
        uint256[] memory boostMultiplier,
        uint256[] memory limit
    ) external;

    /// @notice Update protocol token contract address.
    /// @param protocolToken The address of protocol token.
    function setProtocolToken(address protocolToken) external;

    /// @notice Update balance of protocol token held by LGE.
    function refreshProtocolTokenBalance() external;

    /// @notice Get all vest mode info.
    /// @return Vest mode informations.
    function getVestModes() external view returns (VestMode[] memory);

    /// @notice Admin function to update all vesting modes
    /// @dev Only owner can call this function.
    /// @param vestModes The array of vest modes.
    function setVestModes(VestMode[] calldata vestModes) external;

    /// @notice Get all nft boost decays.
    /// @notice The decay is in BPS (eg. decay of 2000 or 20% means nft boost is reduced by 20%
    /// @return NFT boost decays.
    function getNFTBoostDecays() external view returns (uint256[] memory);

    /// @notice Admin function to update LGE beginning and end timestamps.
    /// @dev Only owner can call this function.
    /// @param lgeStartTimestamp The start timestamp of lge sale.
    /// @param lgeDurationDays The duration in days of lge sale.
    /// @param vestStartOffset The lag between end of lge sale and start of vesting.
    /// @param nftBoostDecays The array of nft boost decays.
    function setTimestamps(
        uint256 lgeStartTimestamp, 
        uint256 lgeDurationDays, 
        uint256 vestStartOffset,
        uint256[] calldata nftBoostDecays
    ) external;

    /// @notice Set timestamp for start of vest.
    /// @dev Only owner can call this function.
    /// @param vestStartOffset The time offset between end of LGE sale end and start of vest.
    function setVestStartOffset(uint256 vestStartOffset) external;

    /// @notice Calculate boost on allotments based on nft and vest mode.
    /// @param nftCollectionAddress The address of nft collection.
    /// @param nftId The id of nft collection.
    /// @param vestModeIndex The index of vest modes.
    /// @return remainingAmount Available deposit amount in the NFT.
    /// @return allotmentsPerDepositToken The allotment per deposit token.
    function getAllotmentsPerDepositToken(
        address nftCollectionAddress,
        uint256 nftId,
        uint256 vestModeIndex
    ) external view returns (
        uint256 remainingAmount,
        uint256 allotmentsPerDepositToken
    );

    /// @notice Gets LGE details that are unlikely to change.
    /// @dev Enables faster frontend experiences.
    /// @return lgeDetails such as start time, end time, deposit token, vest modes, decay schedule.
    function getLGEDetails() external view returns (LGEDetails memory);

    /// @notice Gets LGE progress.
    /// @dev Enables faster frontend experiences.
    /// @param account the account connected to the frontend.
    /// @param nftCollectionAddress Address of NFT to get current NFT boost.
    /// @return lgeFrontnedInfo such as total deposited, total allotments, current NFT boost.
    function getLGEFrontendInfo(
        address account,
        address nftCollectionAddress
    ) external view returns (LGEFrontendInfo memory);

    /// @notice Routing function to protect internals and simplify front end integration.
    /// @param amount The amount of depositToken to buy allotments.
    /// @param nftCollectionAddress The address of the NFT a user would like to apply for boost - 0 to use default terms
    /// @param nftId The ID of NFT within the collection
    /// @param vestModeIndex The index of vest mode selected
    function buy(
        uint256 amount,
        address nftCollectionAddress,
        uint256 nftId,
        uint256 vestModeIndex
    ) external;

    /// @notice Preview your purchase.
    /// @param amount The amount of depositToken to buy allotments.
    /// @param nftCollectionAddress The address of the NFT a user would like to apply for boost - 0 to use default terms.
    /// @param vestModeIndex The index of vest mode selected.
    /// @return preview The preview of this purchase.
    function previewBuy(
        uint256 amount,
        address nftCollectionAddress,
        uint256 vestModeIndex
    ) external view returns (PreviewBuy memory);

    // @dev Function to get user buy info data
    function getUserBuyInfo(
        address userAddress
    ) external view returns (UserBuyInfo memory);

    /// @notice Claim all pending protocol token.
    function claim() external;

    /// @notice Get pending amount of protocol token of a user.
    function getClaimable(
        address userAddress
    ) external view returns (uint256);

    /// @notice Get balance of protocol token token balance
    /// @return Balance of protocol token.
    function getBalanceProtocolToken() external view returns (uint256);

    /// @notice Withdraws protocol token balance to depositTokenWallet.
    /// @dev Only owner can call this function.
    /// @dev If call this function, contract will be paused.
    function withdrawProtocolToken() external;

    event NFTCollectionInfoUpdated(
        address[] nftCollectionAddress,
        uint256[] price,
        uint256[] limit
    );
    event ProtocolTokenWithdrawn(
        address indexed protocolToken,
        uint256 totalProtocolToken
    );
    event ProtocolTokenUpdated(
        address indexed protocolToken,
        uint256 totalProtocolToken
    );
    event TimestampsUpdated(
        uint256 lgeStartTimestamp,
        uint256 lgeEndTimestamp,
        uint256 vestStartTimestamp
    );
    event VestStartTimestampUpdated(uint256 vestStartTimestamp);
    event VestModesUpdated(uint256 numVestModes);
    event AllotmentsBought(
        address indexed userAddress,
        uint256 deposited,
        uint256 allotments
    );
    event ProtocolTokensClaimed(address indexed userAddress, uint256 amount);
}
