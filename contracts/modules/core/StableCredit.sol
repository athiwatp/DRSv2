pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

/// @author Velo Team
/// @title A modified ERC20
contract StableCredit is ERC20, ERC20Detailed {

    IERC20 public collateral;
    bytes32 public collateralAssetCode;

    uint256 public peggedValue;
    bytes32 public peggedCurrency;

    address public creditOwner;
    address public drsAddress;

    modifier onlyDRSSC() {
        require(drsAddress == msg.sender, "caller is not DRSSC");
        _;
    }

    constructor (
        bytes32 _peggedCurrency,
        address _creditOwner,
        bytes32 _collateralAssetCode,
        address _collateralAddress,
        string memory _code,
        uint256 _peggedValue
    )
    public ERC20Detailed(_code, _code, 7) {
        drsAddress = msg.sender;
        creditOwner = _creditOwner;
        peggedValue = _peggedValue;
        peggedCurrency = _peggedCurrency;
        collateral = IERC20(_collateralAddress);
        collateralAssetCode = _collateralAssetCode;
    }

    function mint(address recipient, uint256 amount) external onlyDRSSC {
        _mint(recipient, amount);
    }

    function burn(address tokenOwner, uint256 amount) external onlyDRSSC {
        _burn(tokenOwner, amount);
    }

    function approveCollateral() external onlyDRSSC {
        collateral.approve(msg.sender, collateral.balanceOf(address(this)));
    }

    function redeem(address redeemer, uint burnAmount, uint256 returnAmount) external onlyDRSSC {
        collateral.transfer(redeemer, returnAmount);
        _burn(redeemer, burnAmount);
    }

    function getCollateralDetail() external view returns(uint256, address) {
        return (collateral.balanceOf(address(this)), address(collateral));
    }
}