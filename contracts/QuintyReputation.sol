// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract QuintyReputation is ERC721URIStorage, Ownable {

    enum AchievementType {
        // Solver Milestones
        FIRST_SOLVER,      // 1 submission
        ACTIVE_SOLVER,     // 10 submissions
        LEGEND_SOLVER,     // 50 submissions

        // Winner Milestones
        FIRST_WIN,         // 1 win
        SKILLED_WINNER,    // 10 wins
        LEGEND_WINNER,     // 50 wins

        // Creator Milestones
        FIRST_CREATOR,     // 1 bounty created
        ACTIVE_CREATOR,    // 10 bounties created
        LEGEND_CREATOR      // 50 bounties created
    }

    struct UserStats {
        uint256 totalSubmissions;
        uint256 totalWins;
        uint256 totalBountiesCreated;
        uint256 firstActivity;
        uint256 lastActivity;
    }

    // State variables
    mapping(address => UserStats) public userStats;
    mapping(address => mapping(AchievementType => bool)) public hasAchievement;
    mapping(address => mapping(AchievementType => uint256)) public achievementTokenIds;

    uint256 private _tokenCounter;
    string private _baseTokenURI;

    // Achievement thresholds
    uint256[3] public solverMilestones = [1, 10, 50];
    uint256[3] public winnerMilestones = [1, 10, 50];
    uint256[3] public creatorMilestones = [1, 10, 50];

    event AchievementUnlocked(address indexed user, AchievementType achievement, uint256 tokenId);
    constructor(string memory baseTokenURI) ERC721("Quinty Reputation", "QREP") Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI;
    }

    function setBaseTokenURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    // Called by Quinty contract when user submits solution
    function recordSubmission(address _user) external onlyOwner {
        userStats[_user].totalSubmissions++;
        if (userStats[_user].firstActivity == 0) {
            userStats[_user].firstActivity = block.timestamp;
        }
        userStats[_user].lastActivity = block.timestamp;

        _checkSolverMilestones(_user);
    }

    // Called by Quinty contract when user wins bounty
    function recordWin(address _user) external onlyOwner {
        userStats[_user].totalWins++;
        userStats[_user].lastActivity = block.timestamp;

        _checkWinnerMilestones(_user);
    }

    // Called by Quinty contract when user creates bounty
    function recordBountyCreation(address _user) external onlyOwner {
        userStats[_user].totalBountiesCreated++;
        if (userStats[_user].firstActivity == 0) {
            userStats[_user].firstActivity = block.timestamp;
        }
        userStats[_user].lastActivity = block.timestamp;

        _checkCreatorMilestones(_user);
    }

    function _checkSolverMilestones(address _user) internal {
        uint256 submissions = userStats[_user].totalSubmissions;

        for (uint i = 0; i < solverMilestones.length; i++) {
            if (submissions >= solverMilestones[i]) {
                AchievementType achievement = AchievementType(i);
                if (!hasAchievement[_user][achievement]) {
                    _mintAchievement(_user, achievement);
                }
            }
        }
    }

    function _checkWinnerMilestones(address _user) internal {
        uint256 wins = userStats[_user].totalWins;

        for (uint i = 0; i < winnerMilestones.length; i++) {
            if (wins >= winnerMilestones[i]) {
                AchievementType achievement = AchievementType(uint(AchievementType.FIRST_WIN) + i);
                if (!hasAchievement[_user][achievement]) {
                    _mintAchievement(_user, achievement);
                }
            }
        }
    }
    function _checkCreatorMilestones(address _user) internal {
        uint256 bounties = userStats[_user].totalBountiesCreated;

        for (uint i = 0; i < creatorMilestones.length; i++) {
            if (bounties >= creatorMilestones[i]) {
                AchievementType achievement = AchievementType(uint(AchievementType.FIRST_CREATOR) + i);
                if (!hasAchievement[_user][achievement]) {
                    _mintAchievement(_user, achievement);
                }
            }
        }
    }

    function _mintAchievement(address _user, AchievementType _achievement) internal {
        _tokenCounter++;
        uint256 tokenId = _tokenCounter;

        hasAchievement[_user][_achievement] = true;
        achievementTokenIds[_user][_achievement] = tokenId;

        _safeMint(_user, tokenId);
        emit AchievementUnlocked(_user, _achievement, tokenId);
    }

    function getUserStats(address _user) external view returns (UserStats memory) {
        return userStats[_user];
    }


    function getUserAchievements(address _user) external view returns (AchievementType[] memory achievements, uint256[] memory tokenIds) {
        uint256 count = 0;

        for (uint i = 0; i <= uint(AchievementType.LEGEND_CREATOR); i++) {
            if (hasAchievement[_user][AchievementType(i)]) {
                count++;
            }
        }

        achievements = new AchievementType[](count);
        tokenIds = new uint256[](count);
        uint256 index = 0;

        for (uint i = 0; i <= uint(AchievementType.LEGEND_CREATOR); i++) {
            AchievementType achievement = AchievementType(i);
            if (hasAchievement[_user][achievement]) {
                achievements[index] = achievement;
                tokenIds[index] = achievementTokenIds[_user][achievement];
                index++;
            }
        }

        return (achievements, tokenIds);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        address owner = ownerOf(tokenId);
        for (uint i = 0; i <= uint(AchievementType.LEGEND_CREATOR); i++) {
            AchievementType achievement = AchievementType(i);
            if (achievementTokenIds[owner][achievement] == tokenId) {
                return _generateMetadata(achievement);
            }
        }

        return _baseTokenURI;
    }

    function _generateMetadata(AchievementType _achievement) internal pure returns (string memory) {
        string memory name = _getAchievementName(_achievement);
        string memory description = _getAchievementDescription(_achievement);
        string memory imageUri = _getCustomImageCID(_achievement);

        if (bytes(imageUri).length == 0) {
            imageUri = _generateSVGImage(_achievement);
        } else {
            imageUri = string(abi.encodePacked("ipfs://", imageUri));
        }

        string memory json = string(abi.encodePacked(
            '{"name":"', name,
            '","description":"', description,
            '","image":"', imageUri,
            '","attributes":[',
            '{"trait_type":"Category","value":"', _getAchievementCategory(_achievement), '"},',
            '{"trait_type":"Milestone","value":"', _getAchievementMilestone(_achievement), '"},',
            '{"trait_type":"Rarity","value":"', _getAchievementRarity(_achievement), '"}',
            ']}'
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    function _getCustomImageCID(AchievementType _achievement) internal pure returns (string memory) {
        if (_achievement == AchievementType.FIRST_SOLVER)
            return "bafybeidke5yz36dg2rxilvutum5vgncvqyltf6cu762etepaihsmw2iyg4";
        if (_achievement == AchievementType.FIRST_WIN)
            return "bafybeiahm5nfkbjljmhiel2sgbkjo2qglcsfzmnkxplzxtwhuc2nm2m7au";
        if (_achievement == AchievementType.FIRST_CREATOR)
            return "bafybeiagnlf5wyutxfto2ds6aflecsdgzk4eowz3qn32qlx3h6uuz3vxme";
        return "";
    }

    function _generateSVGImage(AchievementType _achievement) internal pure returns (string memory) {
        string memory emoji = _getAchievementEmoji(_achievement);
        string memory color = _getAchievementColor(_achievement);

        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">',
            '<rect width="512" height="512" fill="', color, '" rx="50"/>',
            '<text x="256" y="300" font-family="Arial" font-size="120" text-anchor="middle" fill="white">',
            emoji,
            '</text>',
            '</svg>'
        ));

        return string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(svg))
        ));
    }

    function _getAchievementName(AchievementType _achievement) internal pure returns (string memory) {
        if (_achievement == AchievementType.FIRST_SOLVER) return "First Solver Badge";
        if (_achievement == AchievementType.ACTIVE_SOLVER) return "Active Solver Badge";
        if (_achievement == AchievementType.LEGEND_SOLVER) return "Legend Solver Badge";

        if (_achievement == AchievementType.FIRST_WIN) return "First Victory Badge";
        if (_achievement == AchievementType.SKILLED_WINNER) return "Skilled Winner Badge";
        if (_achievement == AchievementType.LEGEND_WINNER) return "Legend Winner Badge";

        if (_achievement == AchievementType.FIRST_CREATOR) return "First Creator Badge";
        if (_achievement == AchievementType.ACTIVE_CREATOR) return "Active Creator Badge";
        if (_achievement == AchievementType.LEGEND_CREATOR) return "Legend Creator Badge";

        return "Unknown Achievement";
    }

    function _getAchievementDescription(AchievementType _achievement) internal pure returns (string memory) {
        if (_achievement == AchievementType.FIRST_SOLVER)
            return "Congratulations! You've submitted your first solution to a Quinty bounty.";
        if (_achievement == AchievementType.ACTIVE_SOLVER)
            return "You've submitted 10 solutions! Your dedication is impressive.";
        if (_achievement == AchievementType.LEGEND_SOLVER)
            return "50 submissions completed! You are a legendary problem solver.";

        if (_achievement == AchievementType.FIRST_WIN)
            return "Your first victory! You've successfully won a bounty.";
        if (_achievement == AchievementType.SKILLED_WINNER)
            return "10 bounty wins! Your consistent success is exceptional.";
        if (_achievement == AchievementType.LEGEND_WINNER)
            return "50 victories! You are a legend in the Quinty ecosystem.";

        if (_achievement == AchievementType.FIRST_CREATOR)
            return "Welcome, creator! You've posted your first bounty.";
        if (_achievement == AchievementType.ACTIVE_CREATOR)
            return "10 bounties created! You're actively building the ecosystem.";
        if (_achievement == AchievementType.LEGEND_CREATOR)
            return "50 bounties! You are a legendary creator.";

        return "A special achievement in the Quinty ecosystem.";
    }

    function _getAchievementCategory(AchievementType _achievement) internal pure returns (string memory) {
        if (uint(_achievement) <= uint(AchievementType.LEGEND_SOLVER)) return "Solver";
        if (uint(_achievement) <= uint(AchievementType.LEGEND_WINNER)) return "Winner";
        return "Creator";
    }

    function _getAchievementMilestone(AchievementType _achievement) internal pure returns (string memory) {
        if (_achievement == AchievementType.FIRST_SOLVER ||
            _achievement == AchievementType.FIRST_WIN ||
            _achievement == AchievementType.FIRST_CREATOR) return "1";
        if (_achievement == AchievementType.ACTIVE_SOLVER ||
            _achievement == AchievementType.SKILLED_WINNER ||
            _achievement == AchievementType.ACTIVE_CREATOR) return "10";
        if (_achievement == AchievementType.LEGEND_SOLVER ||
            _achievement == AchievementType.LEGEND_WINNER ||
            _achievement == AchievementType.LEGEND_CREATOR) return "50";
        return "Special";
    }

    function _getAchievementRarity(AchievementType _achievement) internal pure returns (string memory) {
        if (_achievement == AchievementType.FIRST_SOLVER ||
            _achievement == AchievementType.FIRST_WIN ||
            _achievement == AchievementType.FIRST_CREATOR) return "Common";
        if (_achievement == AchievementType.ACTIVE_SOLVER ||
            _achievement == AchievementType.SKILLED_WINNER ||
            _achievement == AchievementType.ACTIVE_CREATOR) return "Uncommon";
        if (_achievement == AchievementType.LEGEND_SOLVER ||
            _achievement == AchievementType.LEGEND_WINNER ||
            _achievement == AchievementType.LEGEND_CREATOR) return "Rare";
        return "Mythic";
    }

    function _getAchievementEmoji(AchievementType _achievement) internal pure returns (string memory) {
        if (uint(_achievement) <= uint(AchievementType.LEGEND_SOLVER)) return "S";
        if (uint(_achievement) <= uint(AchievementType.LEGEND_WINNER)) return "W";
        if (uint(_achievement) <= uint(AchievementType.LEGEND_CREATOR)) return "C";
        return "K";
    }

    function _getAchievementColor(AchievementType _achievement) internal pure returns (string memory) {
        if (uint(_achievement) <= uint(AchievementType.LEGEND_SOLVER)) return "#3B82F6";
        if (uint(_achievement) <= uint(AchievementType.LEGEND_WINNER)) return "#F59E0B";
        if (uint(_achievement) <= uint(AchievementType.LEGEND_CREATOR)) return "#10B981";
        return "#8B5CF6";
    }


    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(from == address(0), "Soulbound: tokens are not transferable");
        return super._update(to, tokenId, auth);
    }
}
