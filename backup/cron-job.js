require('dotenv').config();
const { ethers } = require('ethers');
const cron = require('cron');

// Environment variables
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractABI = require('./contractABI.json'); // Import your contract ABI
console.log("Done L10.......");

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

// Users for betting
const users = [
  { address: process.env.USER1, privateKey: process.env.USER1_PK },
  { address: process.env.USER2, privateKey: process.env.USER2_PK },
  { address: process.env.USER3, privateKey: process.env.USER3_PK },
  { address: process.env.USER4, privateKey: process.env.USER4_PK },
  { address: process.env.USER5, privateKey: process.env.USER5_PK },
  { address: process.env.USER6, privateKey: process.env.USER6_PK },
  { address: process.env.USER7, privateKey: process.env.USER7_PK },
  { address: process.env.USER8, privateKey: process.env.USER8_PK },
  { address: process.env.USER9, privateKey: process.env.USER9_PK },
  { address: process.env.USER10, privateKey: process.env.USER10_PK },
];

// Random number generator for price
function getRandomPrice() {
console.log("inside getRandomPrice L30.......");
  return Math.floor(Math.random() * 10000000) + 1; // Random price between 1 and 1000
}

// Place trades (5 up and 5 down)
async function placeBets() {
  try {
    // First 5 users bet "UP"
    for (let i = 0; i < 5; i++) {
console.log("inside first for loop L39.......");

      const user = users[i];
      const userWallet = new ethers.Wallet(user.privateKey, provider);
      const userContract = contract.connect(userWallet);

      await userContract.makeTrade(
        { poolId: '0x123a', upOrDown: true },
        { value: ethers.utils.parseEther('0.1') }
      );
      console.log(`User ${user.address} placed an UP bet.`);
    }

    // Next 5 users bet "DOWN"
    for (let i = 5; i < 10; i++) {
      const user = users[i];
      const userWallet = new ethers.Wallet(user.privateKey, provider);
      const userContract = contract.connect(userWallet);

      await userContract.makeTrade(
        { poolId: '0x123a', upOrDown: false },
        { value: ethers.utils.parseEther('0.1') }
      );
      console.log(`User ${user.address} placed a DOWN bet.`);
    }
  } catch (error) {
    console.error('Error placing bets:', error);
  }
}

// Trigger the round
async function triggerRound(start = true) {
  try {
    const price = getRandomPrice();
    const timeMS = 0;
    const poolId = '0x123a';

    await contract.trigger(poolId, timeMS, price, 30);
    console.log(`${start ? 'Start' : 'End'} Trigger called with price:`, price);
  } catch (error) {
    console.error('Error triggering round:', error);
  }
}

// Main cron job
const job = new cron.CronJob('*/65 * * * * *', async () => {
  console.log('Starting new cycle...');

  // Step 1: Place bets for 50 seconds
  console.log('Placing bets...');
  await placeBets();
  await new Promise((resolve) => setTimeout(resolve, 50000));

  // Step 2: Trigger with start price
  console.log('Calling start trigger...');
  await triggerRound(true);

  // Step 3: Wait 60 seconds
  await new Promise((resolve) => setTimeout(resolve, 10000));

  // Step 4: Trigger with end price
  console.log('Calling end trigger...');
  await triggerRound(false);

  // Step 5: Wait 5 seconds before the next round
  console.log('Waiting for the next cycle...');
  await new Promise((resolve) => setTimeout(resolve, 5000));
});

// Start the cron job
job.start();
console.log('Cron job started.');
