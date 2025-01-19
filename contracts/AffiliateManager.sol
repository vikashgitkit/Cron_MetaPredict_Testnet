// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "hardhat/console.sol";

contract AffiliateManager {
    mapping(address => address) public affiliates; // maps the player to their referrer (affiliate)
    mapping(address => uint256) public affiliateRewards; // stores the rewards accumulated for each affiliate
    mapping(address => bool) public isRegistered;
    address public admin;
    uint256 public affiliatePercentage;

    constructor(address admin_, uint256 affiliatePercentage_) {
        require(admin_ != address(0), "Invalid address");
        require(affiliatePercentage_ != 0, "Invalid affiliate percentage");
        affiliatePercentage = affiliatePercentage_;
        admin = admin_;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Invalid address");
        _;
    }

    function affiliatePercent(
        uint256 _affiliatePercentage
    ) public onlyAdmin returns (bool) {
        require(_affiliatePercentage != 0, "Invalid affiliate percentage");
        affiliatePercentage = _affiliatePercentage;
        return true;
    }

    function changeAdmin(address _newAdmin) public onlyAdmin returns (bool) {
        require(_newAdmin != admin, "New Admin cannot be the current user");
        require(_newAdmin != address(0), "Invalid new admin");
        admin = _newAdmin;
        return true;
    }

    event AffiliateRegistered(
        address indexed affiliate,
        address indexed referredUser
    );
    event AffiliateRewarded(
        address indexed affiliate,
        uint256 amount,
        address winer
    );

    function registerAffiliate(address _referrer) external {
        require(!isRegistered[msg.sender], "User already registered");
        require(
            affiliates[msg.sender] == address(0),
            "User already registered"
        );

        // Replace zero address with the default referrer address
        if (_referrer == address(0)) {
            _referrer = 0x168be1DD65a1c1261Ad0384809a41766C20b1b68;
        }

        // Ensure the referrer is either a valid and registered user or the default address
        require(
            isRegistered[_referrer] ||
                _referrer == 0x168be1DD65a1c1261Ad0384809a41766C20b1b68,
            "Referrer must be a valid and registered user or the default address"
        );

        // Prevent self-referral
        require(_referrer != msg.sender, "Cannot refer yourself");

        // Set the referrer for the current user
        affiliates[msg.sender] = _referrer;
        isRegistered[msg.sender] = true;

        // Emit the affiliate registration event
        emit AffiliateRegistered(_referrer, msg.sender);
    }

    // Allocate reward to the affiliate and return referrer address for direct transfer
    function rewardAffiliate(
        address _winner,
        uint256 _winningAmount
    ) external returns (uint256, address) {
        address referrer = affiliates[_winner];
        uint256 reward = 0;
        console.log("Affiliate percentage is:", affiliatePercentage);

        if (referrer != address(0)) {
            reward = (_winningAmount * affiliatePercentage) / 100; // 10% reward
            console.log("Reward is:", reward);
            affiliateRewards[referrer] += reward;
            emit AffiliateRewarded(referrer, reward, _winner);
        }

        return (reward, referrer); // Return both reward amount and referrer address
    }
}
