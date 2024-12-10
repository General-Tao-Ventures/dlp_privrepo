import { UD60x18 } from "./ValueType.sol";

function unwrap(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

function wrap(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}  