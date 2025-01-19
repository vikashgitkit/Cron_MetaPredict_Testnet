require("dotenv").config();
const { ethers } = require("ethers");

// Load environment variables
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const adminWallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contractAddress = process.env.Aff_CONTRACT_ADDRESS;
//const contractWithSigner = contract.connect(adminWallet);

// ABI of AffiliateManager Contract
const contractABI = [
        {
            "inputs": [
                {
                    "internalType": "uint256",
                    "name": "_affiliatePercentage",
                    "type": "uint256"
                }
            ],
            "name": "affiliatePercent",
            "outputs": [
                {
                    "internalType": "bool",
                    "name": "",
                    "type": "bool"
                }
            ],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "admin_",
                    "type": "address"
                },
                {
                    "internalType": "uint256",
                    "name": "affiliatePercentage_",
                    "type": "uint256"
                }
            ],
            "stateMutability": "nonpayable",
            "type": "constructor"
        },
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "affiliate",
                    "type": "address"
                },
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "referredUser",
                    "type": "address"
                }
            ],
            "name": "AffiliateRegistered",
            "type": "event"
        },
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "affiliate",
                    "type": "address"
                },
                {
                    "indexed": false,
                    "internalType": "uint256",
                    "name": "amount",
                    "type": "uint256"
                },
                {
                    "indexed": false,
                    "internalType": "address",
                    "name": "winer",
                    "type": "address"
                }
            ],
            "name": "AffiliateRewarded",
            "type": "event"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "_newAdmin",
                    "type": "address"
                }
            ],
            "name": "changeAdmin",
            "outputs": [
                {
                    "internalType": "bool",
                    "name": "",
                    "type": "bool"
                }
            ],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "_referrer",
                    "type": "address"
                }
            ],
            "name": "registerAffiliate",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "_winner",
                    "type": "address"
                },
                {
                    "internalType": "uint256",
                    "name": "_winningAmount",
                    "type": "uint256"
                }
            ],
            "name": "rewardAffiliate",
            "outputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                },
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "admin",
            "outputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "affiliatePercentage",
            "outputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "name": "affiliateRewards",
            "outputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "name": "affiliates",
            "outputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "name": "isRegistered",
            "outputs": [
                {
                    "internalType": "bool",
                    "name": "",
                    "type": "bool"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        }
    
];

// Connect to the AffiliateManager contract
const affiliateManager = new ethers.Contract(contractAddress, contractABI, adminWallet);

// List of wallets for users
const userPrivateKeys = [
    "0x1232d5ca46cc4382cf410ae61a01f2d081d4a694b3bf426fb72dbfc75cff050a",
    "0xefdc2cb130ce6096296ef9d1a1c0009869306f057534b1971b9aa28726f5a625",
  "0x183b4d89b58b6663bf5ea0117ce5b5c25d0682b29f956250e69fbb81efd0a09a",
];

// Register users with referrer as `address(0)`
async function registerUsers() {
  try {
    for (let i = 0; i < userPrivateKeys.length; i++) {
      const userWallet = new ethers.Wallet(userPrivateKeys[i], provider);
      const userAffiliateManager = affiliateManager.connect(userWallet);

      console.log(`Registering user ${i + 1} with address: ${userWallet.address}`);
      const tx = await userAffiliateManager.registerAffiliate(ethers.constants.AddressZero);

      console.log(`Transaction submitted. Hash: ${tx.hash}`);
      await tx.wait();
      console.log(`User ${i + 1} successfully registered.`);
    }
  } catch (error) {
    console.error("Error while registering users:", error);
  }
}

registerUsers();
