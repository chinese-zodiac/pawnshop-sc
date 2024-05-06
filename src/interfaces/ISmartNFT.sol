import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISmartNFTMintable is IERC721 {
    function execute(bytes memory data) external payable returns (bool);
    function validatePermission() external view returns (bool);
    function mint(address to) external;
}
