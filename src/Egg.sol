import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract Egg is ERC20, IEgg {
  address private _ants;

  constructor(address antsAddress) ERC20('EGG', 'EGG') {
    _ants = antsAddress;
  }

  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract');
    _mint(_to, _amount);
  }

  function burnFrom(address _account, uint256 _amount) external {
    //solhint-disable-next-line
    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract');
    _burn(_account, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}
