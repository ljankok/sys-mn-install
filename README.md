# sys-mn-install

## Syscoin Guided Interactive Install

This is the Syscoin Interactive Guided Masternode Install script.  I made this script primarily for my own personal use.

This Masternode install script is based on the Bulwark masternode install script created by the [Bulwark team](https://github.com/bulwark-crypto/Bulwark-MN-Install)

The install procedure is mostly based on this medium [post](https://medium.com/@BlockchainFoundry/syscoin-3-0-masternode-setup-instructions-572576c7163f) which some enhancements included.

To fix the locale settings on your VPS, you may want to run the following before running the Masternode Install Script:

```bash <( curl https://raw.githubusercontent.com/ljankok/sys-mn-install/master/fix-locale.sh )```

To install your masternode, issue the following command on your VPS:

```bash <( curl https://raw.githubusercontent.com/ljankok/sys-mn-install/master/sys-mn-build.sh )```

Have Fun!
