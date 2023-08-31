/* eslint-disable @typescript-eslint/naming-convention */
export interface Addresses {
  UniswapV3Factory: string;
  SwapRouter: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "hardhat":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "mainnet":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "polygon":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "optimism":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "arbitrum":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "goerli":
      return {
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        SwapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      };
    case "binance":
      return {
        UniswapV3Factory: "0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7",
        SwapRouter: "0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2",
      };
    case "base":
      return {
        UniswapV3Factory: "0x33128a8fC17869897dcE68Ed026d694621f6FDfD",
        SwapRouter: "0x2626664c2603336E57B271c5C0b26F421741e481",
      };
    case "sepolia":
      return {
        UniswapV3Factory: "0x0227628f3F023bb0B980b67D528571c95c6DaC1c",
        SwapRouter: "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
