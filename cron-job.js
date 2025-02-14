require('dotenv').config();
const { ethers } = require('ethers');
const cron = require('cron');
const AsyncLock = require('async-lock'); // Install this with `npm install async-lock`

// Environment variables
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractABI = require('./contractABI.json');
console.log("Starting...");

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

// Lock to prevent overlapping jobs
const lock = new AsyncLock();

// Random number generator for price
function getRandomPrice() {
  console.log("Generating random price...");
  return Math.floor(Math.random() * 10000000) + 1; // Random price between 1 and 10,000,000
}

// Place bets (all 10 users, 5 UP and 5 DOWN)
async function placeBets() {
  const promises = [];
  try {
    for (let i = 0; i < 10; i++) {
      const user = users[i];
      const userWallet = new ethers.Wallet(user.privateKey, provider);
      const userContract = contract.connect(userWallet);

      const upOrDown = i < 5; // First 5 users bet UP, next 5 bet DOWN
      promises.push(
        userContract.makeTrade(
          { poolId: '0x123a', upOrDown },
          { value: ethers.utils.parseEther('0.1') }
        )
      );
      console.log(`User ${user.address} placed a ${upOrDown ? 'UP' : 'DOWN'} bet.`);
    }
    await Promise.all(promises);
    console.log("All bets placed successfully.");
  } catch (error) {
    console.error('Error placing bets:', error);
  }
}

// Trigger the round
async function triggerRound(start = true) {
  try {
    const price = getRandomPrice();
    const poolId = '0x123a';
    const timeMS = 0;

    await contract.trigger(poolId, timeMS, price, 30);
    console.log(`${start ? 'Start' : 'End'} Trigger called with price:`, price);
  } catch (error) {
    console.error('Error triggering round:', error);
  }
}

// Main cron job logic
async function runJob() {
  console.log('Starting new cycle...');
  try {
    // Step 1: Place all bets in parallel at the start of the cycle
    console.log('Placing bets...');
    await placeBets();

    // Step 2: Trigger with start price at 51 seconds
    console.log('Waiting for start trigger at 51 seconds...');
    await new Promise((resolve) => setTimeout(resolve, 51000)); // Wait 51 seconds
    await triggerRound(true);

    // Step 3: Trigger with end price at 60 seconds
    console.log('Waiting for end trigger at 60 seconds...');
    await new Promise((resolve) => setTimeout(resolve, 9000)); // Wait 9 seconds (total 60 seconds)
    await triggerRound(false);

    console.log('Cycle completed. Waiting for the next cycle...');
  } catch (error) {
    console.error('Error in job execution:', error);
  }
}

// Cron job with locking
const job = new cron.CronJob('*/65 * * * * *', async () => {
  await lock.acquire('cronJob', runJob);
});

// Start the cron job
job.start();
console.log('Cron job started.');
