// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/ISavvyLGE.sol";
import "./libraries/Checker.sol";
import "./libraries/Math.sol";
import "./libraries/TokenUtils.sol";
import "./base/Errors.sol";

contract SavvyLGE is
    Ownable2Step,
    Initializable,
    Pausable,
    ReentrancyGuardUpgradeable,
    ISavvyLGE
{
    using SafeERC20 for IERC20;

    /// @dev This is constant value to calculate boostMultiplier
    uint256 public constant BASIS_POINTS = 10_000;

    /// @dev protocol token
    IERC20 public protocolToken;
    /// @dev token accepted for deposit
    IERC20 public depositToken;
    /// @dev number of decimals required to normalized depositToken to 18 decimals
    uint256 public conversionFactor;
    /// @dev base price for 1 unit ($depositToken) per allotment
    uint256 public pricePerAllotment;
    /// @dev address where funds deposited are sent
    address public depositTokenWallet;

    /// @dev amount of depositToken deposited
    uint256 public totalDeposited;
    /// @dev total allotments in existence
    uint256 public allotmentSupply;
    /// @dev initial protocol token balance in LGE
    uint256 public totalProtocolToken;

    /// @dev start time of LGE sale
    uint256 public lgeStartTimestamp;
    /// @dev end time of LGE sale
    uint256 public lgeEndTimestamp;
    /// @dev start time of vest
    uint256 public vestStartTimestamp;
    /// @dev NFT boost decay for each day of LGE sale
    uint256[] public nftBoostDecays;

    /// @dev list of vest modes with duration and boost multiplier
    VestMode[] public vestModes;
    /// @dev mapping of boosts for redlisted NFT collections
    mapping(address => NFTCollectionInfo) public nftCollectionInfos;
    /// @dev mapping of NFTs used for boosts
    mapping(address => mapping(uint256 => NFTAllocationInfo)) public nftAllocationInfos;

    /// @dev mapping of weighted average purchases for each user
    mapping(address => UserBuyInfo) public userBuyInfos;
    // @dev mapping of the amount of protocol tokens claimed so far by each user
    mapping(address => uint256) public claimed;

    modifier lgeNotEnded {
        Checker.checkState(block.timestamp <= lgeEndTimestamp, "LGE has ended");
        _;
    }

    modifier vestNotStarted {
        Checker.checkState (block.timestamp <= vestStartTimestamp, "vest has started");
        _;
    }

    /// @dev initialize LGE contract
    function initialize (
        address _protocolToken,
        address _depositToken,
        address _depositTokenWallet,
        uint256 _lgeStartTimestamp,
        uint256 _lgeDurationDays,
        uint256 _vestStartOffset,
        uint256[] calldata _nftBoostDecays,
        VestMode[] calldata _vestModes
    ) external initializer {
        _checkProtocolTokenValidation(address(_protocolToken));
        _setProtocolToken(_protocolToken);
        
        Checker.checkArgument(_depositToken != address(0), "invalid deposit token");
        depositToken = IERC20(_depositToken);
        pricePerAllotment = 10 ** TokenUtils.expectDecimals(_depositToken);
        conversionFactor = 10 ** (18 - TokenUtils.expectDecimals(_depositToken));

        Checker.checkArgument(_depositTokenWallet != address(0), "invalid depositTokenWallet address");
        depositTokenWallet = _depositTokenWallet;

        _setTimestamps(
            _lgeStartTimestamp, 
            _lgeDurationDays, 
            _vestStartOffset,
            _nftBoostDecays
        );
        _setVestModes(_vestModes);
        _transferOwnership(msg.sender);
    }

    /// @inheritdoc	ISavvyLGE
    function pause() external override onlyOwner {
        _pause();
    }

    /// @inheritdoc	ISavvyLGE
    function unpause() external override onlyOwner {
        Checker.checkState(totalProtocolToken > 0, "need to supply protocol tokens to LGE");
        _unpause();
    }

    /// @inheritdoc	ISavvyLGE
    function getNFTCollectionInfo(
        address nftCollectionAddress
    ) external view override returns (NFTCollectionInfo memory) {
        return nftCollectionInfos[nftCollectionAddress];
    }

    /// @inheritdoc	ISavvyLGE
    function setNFTCollectionInfo(
        address[] memory nftCollectionAddresses,
        uint256[] memory boostMultipliers,
        uint256[] memory limits
    ) external override onlyOwner {
        uint256 length = nftCollectionAddresses.length;
        Checker.checkArgument(length > 0, "invalid nftCollectionAddress array");
        Checker.checkArgument(
            length == boostMultipliers.length && length == limits.length,
            "mismatch array"
        );

        for (uint256 i = 0; i < length; i++) {
            address nftCollectionAddress = nftCollectionAddresses[i];
            uint256 boostMultiplier = boostMultipliers[i];
            uint256 limit = limits[i];

            Checker.checkArgument(
                nftCollectionAddress != address(0),
                "zero nftCollection address"
            );
            nftCollectionInfos[nftCollectionAddress] = NFTCollectionInfo(
                boostMultiplier,
                limit
            );
        }

        emit NFTCollectionInfoUpdated(
            nftCollectionAddresses,
            boostMultipliers,
            limits
        );
    }

    /// @inheritdoc	ISavvyLGE
    function getBalanceProtocolToken() external view override returns (uint256) {
        return protocolToken.balanceOf(address(this));
    }

    /// @inheritdoc	ISavvyLGE
    function withdrawProtocolToken() public override onlyOwner {
        _pause();
        _withdrawProtocolToken();
    }

    /// @inheritdoc	ISavvyLGE
    function setProtocolToken(address _protocolToken) external override onlyOwner {
        Checker.checkArgument(_protocolToken != address(protocolToken), "same protocol token address");
        _checkProtocolTokenValidation(_protocolToken);
        Checker.checkArgument(
            IERC20(_protocolToken).balanceOf(address(this)) > 0, 
            "need to supply protocol tokens to LGE"
        );
        withdrawProtocolToken();
        _setProtocolToken(_protocolToken);
    }

    /// @inheritdoc	ISavvyLGE
    function refreshProtocolTokenBalance() external override onlyOwner {
        Checker.checkArgument(address(protocolToken) != address(0), "protocol token not set");
        totalProtocolToken = protocolToken.balanceOf(address(this));
    }

    /// @inheritdoc	ISavvyLGE
    function getVestModes() external view override returns (VestMode[] memory) {
        return vestModes;
    }

    /// @inheritdoc	ISavvyLGE
    function setVestModes(VestMode[] calldata _vestModes) external override onlyOwner {
        _pause();
        _setVestModes(_vestModes);
    }

    /// @inheritdoc	ISavvyLGE
    function getNFTBoostDecays() external view override returns (uint256[] memory) {
        return nftBoostDecays;
    }

    /// @inheritdoc ISavvyLGE
    function getLGEDetails() external view override returns (LGEDetails memory) {
        return LGEDetails(
            lgeStartTimestamp,  // lgeStartTimestamp
            lgeEndTimestamp,    // lgeEndTimestamp
            vestStartTimestamp, // vestStartTimestamp
            vestModes,  // vestModes
            nftBoostDecays, // nftBoostDecays
            address(protocolToken), // protocolToken
            address(depositToken),  // depositToken
            pricePerAllotment   // basePricePerAllotment
        );
    }

    /// @inheritdoc ISavvyLGE
    function getLGEFrontendInfo(address account, address nftCollectionAddress) external view override returns (LGEFrontendInfo memory) {
        uint256 accountBalance = depositToken.balanceOf(account);
        uint256 normalizedAccountBalance = accountBalance * conversionFactor;

        return LGEFrontendInfo(
            totalDeposited, // totalDeposited
            allotmentSupply, // totalAllotments
            _getNFTBoost(nftCollectionAddress), // currentNFTBoost
            normalizedAccountBalance, // userDepositBalance
            userBuyInfos[account] // userBuyInfo
        );
    }

    /// @inheritdoc	ISavvyLGE
    function setTimestamps(
        uint256 _lgeStartTimestamp,
        uint256 _lgeDurationDays,
        uint256 _vestStartOffset,
        uint256[] calldata _nftBoostDecays
    ) external override onlyOwner vestNotStarted {
        _pause();
        _setTimestamps(
            _lgeStartTimestamp, 
            _lgeDurationDays, 
            _vestStartOffset,
            _nftBoostDecays
        );
    }

    /// @inheritdoc	ISavvyLGE
    function getAllotmentsPerDepositToken(
        address nftCollectionAddress,
        uint256 nftId,
        uint256 vestModeIndex
    ) public view override lgeNotEnded returns (
        uint256 remainingAmount,
        uint256 allotmentsPerDepositToken
    ) {
        require (vestModeIndex < vestModes.length, "Invalid vestModeIndex");

        NFTAllocationInfo memory nftAllocationInfo = nftAllocationInfos[nftCollectionAddress][nftId];
        remainingAmount = nftAllocationInfo.activated 
            ? nftAllocationInfo.remaining
            : nftCollectionInfos[nftCollectionAddress].limit;
        allotmentsPerDepositToken = _getAllotmentsPerDepositToken(nftCollectionAddress, vestModeIndex);
    }

    /// @inheritdoc ISavvyLGE
    function previewBuy(
        uint256 amount,
        address nftCollectionAddress,
        uint256 vestModeIndex
    ) external view returns (PreviewBuy memory) {
        uint256 allotmentsPerDepositToken  = _getAllotmentsPerDepositToken(nftCollectionAddress, vestModeIndex);
        uint256 allotments = amount * allotmentsPerDepositToken;
        VestMode memory vestMode = vestModes[vestModeIndex];

        uint256 nftBoost = _getNFTBoost(nftCollectionAddress);

        UserBuyInfo storage userBuyInfo = userBuyInfos[msg.sender];
        uint256 totalVestDuration = Math.findWeightedAverage(
            vestModes[vestModeIndex].duration,
            userBuyInfo.duration,
            allotments,
            userBuyInfo.allotments
        );

        return PreviewBuy(
            allotments,                          // allotments
            vestMode.duration,                   // vestLength
            vestMode.boostMultiplier,            // vestBoost
            nftBoost,                            // nftBoost
            userBuyInfo.allotments + allotments, // totalAllotments
            totalVestDuration                    // totalVestLength
        );
    }

    /// @inheritdoc	ISavvyLGE
    function buy(
        uint256 amount,
        address nftCollectionAddress,
        uint256 nftId,
        uint256 vestModeIndex
    ) public override whenNotPaused lgeNotEnded nonReentrant {
        Checker.checkState(block.timestamp >= lgeStartTimestamp, "lge has not begun");
        Checker.checkArgument(amount != 0, "amount is invalid");
        Checker.checkArgument(vestModeIndex < vestModes.length, "invalid vest mode index");
        if (nftCollectionAddress != address(0)) {
            Checker.checkArgument(nftCollectionInfos[nftCollectionAddress].limit != 0, "this NFT is not eligible for boost");
            Checker.checkArgument(IERC721(nftCollectionAddress).ownerOf(nftId) == msg.sender, "buyer is not the owner of this NFT");
        }
        amount = TokenUtils.safeTransferFrom(address(depositToken), msg.sender, depositTokenWallet, amount);
        _buy(amount, nftCollectionAddress, nftId, vestModeIndex);
    }

    /// @inheritdoc	ISavvyLGE
    function getUserBuyInfo(
        address userAddress
    ) external view override returns (UserBuyInfo memory) {
        return userBuyInfos[userAddress];
    }

    /// @inheritdoc	ISavvyLGE
    function claim() external override {
        uint256 owed = getClaimable(msg.sender);
        Checker.checkState(owed > 0, "no claimable amount");

        claimed[msg.sender] += owed;
        protocolToken.safeTransfer(msg.sender, owed);

        emit ProtocolTokensClaimed(msg.sender, owed);
    }

    /// @inheritdoc ISavvyLGE
    function setVestStartOffset(
        uint256 _vestStartOffset
    ) external onlyOwner override vestNotStarted {
        vestStartTimestamp = lgeEndTimestamp + _vestStartOffset;

        emit VestStartTimestampUpdated(vestStartTimestamp);
    }

    /// @inheritdoc	ISavvyLGE
    function getClaimable(
        address userAddress
    ) public view override returns (uint256) {
        Checker.checkState(block.timestamp > vestStartTimestamp, "vesting has not started");

        uint256 totalOwed = (totalProtocolToken * userBuyInfos[userAddress].allotments) / allotmentSupply;
        uint256 accruedPerSecond = totalOwed / userBuyInfos[userAddress].duration;
        uint256 secondsClaimed = claimed[userAddress] / accruedPerSecond;
        uint256 lastClaim = vestStartTimestamp + secondsClaimed;
        uint256 owed = (block.timestamp - lastClaim) * accruedPerSecond;
        if (claimed[userAddress] + owed > totalOwed) {
            owed = totalOwed - claimed[userAddress];
        }
        return owed;
    }

    /// @notice function that applies NFT and vest mode terms to the user's purchase
    /// @dev transferring user funds directly to depositTokenWallet
    /// @param deposited amount of depositTokens to buy allotments.
    /// @param nftCollectionAddress address of the NFT collection user is using
    /// @param nftId ID paired with the NFT contract
    /// @param vestModeIndex vest mode index
    function _buy(
        uint256 deposited,
        address nftCollectionAddress,
        uint256 nftId,
        uint256 vestModeIndex
    ) internal {
        uint256 allotmentsPerDepositToken  = _getAllotmentsPerDepositToken(nftCollectionAddress, vestModeIndex);
        uint256 decimals = TokenUtils.expectDecimals(address(depositToken));
        uint256 allotments = deposited * allotmentsPerDepositToken / 10**decimals;
        
        if (nftCollectionAddress != address(0)) {
            NFTAllocationInfo storage nftAllocationInfo = nftAllocationInfos[nftCollectionAddress][nftId];
            if (!nftAllocationInfo.activated) {
                _activate(nftCollectionAddress, nftId, deposited);
            } else {
                Checker.checkState(nftAllocationInfo.remaining >= deposited, "insufficient availability for nft");
                nftAllocationInfo.remaining -= deposited;
            }
        }

        _updateUserBuyInfo(deposited, allotments, vestModeIndex);
        allotmentSupply += allotments;
        totalDeposited += deposited;

        emit AllotmentsBought(msg.sender, deposited, allotments);
    }

    /// @notice calculates allotments per deposit token based on NFT and vest mode
    /// @param nftCollectionAddress address of the NFT terms user is using
    /// @param vestModeIndex vest mode index
    /// @return allotmentPerDepositToken Allotment per depositToken
    function _getAllotmentsPerDepositToken(
        address nftCollectionAddress,
        uint256 vestModeIndex
    ) internal view returns (uint256 allotmentPerDepositToken) {
        uint256 vestModeBooster = vestModes[vestModeIndex].boostMultiplier;
        allotmentPerDepositToken = pricePerAllotment * vestModeBooster / BASIS_POINTS;
        
        if (nftCollectionAddress != address(0)) {
            uint256 nftBoost = _getNFTBoost(nftCollectionAddress);
            if (nftBoost != 0) {
                allotmentPerDepositToken = allotmentPerDepositToken * nftBoost / BASIS_POINTS;
            }
        }
    }

    /// @notice Get the current NFT decay.
    /// @return decay The current NFT decay.
    function _getNFTDecay() internal view returns (uint256) {
        uint256 decay = 0;
        if (block.timestamp >= lgeStartTimestamp) {
            uint8 numberOfDays = _getLGESaleDayTerm();
            decay = nftBoostDecays[numberOfDays];
        }
        return decay;
    }

    /// @notice Get the current NFT boost with decay applied.
    /// @return nftBoost The current NFT boost.
    function _getNFTBoost(address nftCollectionAddress) internal view returns (uint256) {
        uint256 nftRawBoost = nftCollectionInfos[nftCollectionAddress].boostMultiplier;
        if (nftRawBoost == 0) {
            return 0;
        }
        uint256 decay = _getNFTDecay();
        uint256 nftBoost = nftRawBoost * (BASIS_POINTS - decay) / BASIS_POINTS;
        return nftBoost;
    }

    /// @notice Get number of days after lge sale started.
    /// @dev The index is started from 0.
    /// @return Number of days after lge started.
    function _getLGESaleDayTerm() internal view returns (uint8) {
        uint256 curTimestamp = block.timestamp;
        if (curTimestamp >= lgeEndTimestamp) {
            return uint8((lgeEndTimestamp - lgeStartTimestamp) / 1 days) - 1;
        }
        uint256 elapsedTime = curTimestamp - lgeStartTimestamp;
        return uint8(elapsedTime / 1 days);
    }

    // @dev pulls NFT state into allocation state and updates the amount to
    // ensure double spends aren't possible
    // nftCollectionAddress:: address of the NFT collection being used
    // nftId:: id of the NFT you're activating
    // amount:: amount being spent out of that NFT
    function _activate(
        address nftCollectionAddress,
        uint256 nftId,
        uint256 amount
    ) internal {
        Checker.checkArgument(amount <= nftCollectionInfos[nftCollectionAddress].limit, "deposit Token amount exceeeds nft allocation limit");
        NFTAllocationInfo storage nftAllocationInfo = nftAllocationInfos[nftCollectionAddress][nftId];
        nftAllocationInfo.remaining = nftCollectionInfos[nftCollectionAddress].limit - amount;
        nftAllocationInfo.activated = true;
    }

    // @dev updates the user's buy info, update amount of allotments with average duration
    // deposited:: amount of depositTokens deposited to get allotments.
    // allotments:: allotments being added to total - used to determine weight
    // vestModeIndex:: vest mode index
    function _updateUserBuyInfo(
        uint256 deposited,
        uint256 allotments, 
        uint256 vestModeIndex
    ) internal {
        UserBuyInfo storage userBuyInfo = userBuyInfos[msg.sender];
        userBuyInfo.duration = Math.findWeightedAverage(
            vestModes[vestModeIndex].duration,
            userBuyInfo.duration,
            allotments,
            userBuyInfo.allotments
        );
        userBuyInfo.deposited += deposited;
        userBuyInfo.allotments += allotments;
        userBuyInfo.totalBoost = userBuyInfo.allotments * BASIS_POINTS / userBuyInfo.deposited;
    }

    /// @dev withdraw all protocolToken from this contract to depositTokenWallet
    function _withdrawProtocolToken() internal {
        uint256 currentBalance = protocolToken.balanceOf(address(this));
        protocolToken.safeTransfer(depositTokenWallet, currentBalance);

        emit ProtocolTokenWithdrawn(address(protocolToken), currentBalance);
    }

    /// @dev update protocol token contract address
    function _setProtocolToken(address _protocolToken) internal {
        Checker.checkArgument(_protocolToken != address(0), "invalid protocol token address");
        IERC20 newProtocolToken = IERC20(_protocolToken);
        uint256 currentBalance = newProtocolToken.balanceOf(address(this));
        protocolToken = newProtocolToken;
        totalProtocolToken = currentBalance;

        emit ProtocolTokenUpdated(_protocolToken, currentBalance);
    }

    /// @dev admin function to update entire vesting modes
    function _setVestModes(VestMode[] memory _vestModes) internal {
        Checker.checkArgument(_vestModes.length > 0, "empty VestMode array");
        delete vestModes;
        for (uint256 i; i < _vestModes.length; i++) {
            Checker.checkArgument(_vestModes[i].boostMultiplier >= BASIS_POINTS, "invalid boost price");
            Checker.checkArgument(_vestModes[i].duration > 0, "invalid duration");
            vestModes.push(_vestModes[i]);
        }

        emit VestModesUpdated(_vestModes.length);
    }

    /// @dev admin function to update LGE lgeStartTimestamp and end timestamps
    function _setTimestamps(
        uint256 _lgeStartTimestamp, 
        uint256 _lgeDurationDays, 
        uint256 _vestStartOffset,
        uint256[] calldata _nftBoostDecays
    ) internal {
        Checker.checkArgument(_lgeStartTimestamp > block.timestamp, "LGE must start in the future");
        Checker.checkArgument(_lgeDurationDays == _nftBoostDecays.length, "NFT boost decay length mismatch");
        lgeStartTimestamp = _lgeStartTimestamp;
        lgeEndTimestamp = _lgeStartTimestamp + _lgeDurationDays * 1 days;
        vestStartTimestamp = lgeEndTimestamp + _vestStartOffset;

        delete nftBoostDecays;
        for (uint256 i; i < _nftBoostDecays.length; i++) {
            Checker.checkArgument(_nftBoostDecays[i] < BASIS_POINTS, "NFT boost decay cannot exceed 100%");
            nftBoostDecays.push(_nftBoostDecays[i]);
        }
        
        emit TimestampsUpdated(lgeStartTimestamp, lgeEndTimestamp, vestStartTimestamp);
    }

    /// @notice Check protocol token is validate.
    /// @param _protocolToken The address of protocol token to set.
    function _checkProtocolTokenValidation(
        address _protocolToken
    ) internal view {
        Checker.checkArgument(_protocolToken != address(0), "zero protocol token address");
        Checker.checkArgument(_protocolToken != address(depositToken), "protocol token is same as deposit token");
    }

    uint256[100] private __gap;
}
