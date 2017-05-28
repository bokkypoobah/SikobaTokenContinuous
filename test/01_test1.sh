#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.
# ----------------------------------------------------------------------------------------------

MODE=${1:-test}

GETHATTACHPOINT=`grep ^IPCFILE= settings.txt | sed "s/^.*=//"`
PASSWORD=`grep ^PASSWORD= settings.txt | sed "s/^.*=//"`
TOKENSOL=`grep ^TOKENSOL= settings.txt | sed "s/^.*=//"`
TOKENTEMPSOL=`grep ^TOKENTEMPSOL= settings.txt | sed "s/^.*=//"`
TOKENJS=`grep ^TOKENJS= settings.txt | sed "s/^.*=//"`
DEPLOYMENTDATA=`grep ^DEPLOYMENTDATA= settings.txt | sed "s/^.*=//"`

INCLUDEJS=`grep ^INCLUDEJS= settings.txt | sed "s/^.*=//"`
TEST1OUTPUT=`grep ^TEST1OUTPUT= settings.txt | sed "s/^.*=//"`
TEST1RESULTS=`grep ^TEST1RESULTS= settings.txt | sed "s/^.*=//"`

CURRENTTIME=`date +%s`
CURRENTTIMES=`date -r $CURRENTTIME -u`

if [ "$MODE" == "dev" ]; then
  # Start time now
  STARTTIME=`echo "$CURRENTTIME" | bc`
else
  # Start time 1 minute in the future
  STARTTIME=`echo "$CURRENTTIME+60" | bc`
fi
STARTTIME_S=`date -r $STARTTIME -u`
ENDTIME=`echo "$CURRENTTIME+60*10+1" | bc`
ENDTIME_S=`date -r $ENDTIME -u`

printf "MODE            = '$MODE'\n"
printf "GETHATTACHPOINT = '$GETHATTACHPOINT'\n"
printf "PASSWORD        = '$PASSWORD'\n"
printf "TOKENSOL        = '$TOKENSOL'\n"
printf "TOKENTEMPSOL    = '$TOKENTEMPSOL'\n"
printf "TOKENJS         = '$TOKENJS'\n"
printf "DEPLOYMENTDATA  = '$DEPLOYMENTDATA'\n"
printf "INCLUDEJS       = '$INCLUDEJS'\n"
printf "TEST1OUTPUT     = '$TEST1OUTPUT'\n"
printf "TEST1RESULTS    = '$TEST1RESULTS'\n"
printf "CURRENTTIME     = '$CURRENTTIME' '$CURRENTTIMES'\n"
printf "STARTTIME       = '$STARTTIME' '$STARTTIME_S'\n"
printf "ENDTIME         = '$ENDTIME' '$ENDTIME_S'\n"

# Make copy of SOL file and modify start and end times ---
`cp $TOKENSOL $TOKENTEMPSOL`

# --- Modify dates ---
# PRESALE_START_DATE = +1m
`perl -pi -e "s/START_DATE = 1496275200;/START_DATE = $STARTTIME; \/\/ $STARTTIME_S/" $TOKENTEMPSOL`
`perl -pi -e "s/END_DATE = 1509494399;/END_DATE = $ENDTIME; \/\/ $ENDTIME_S/" $TOKENTEMPSOL`
`perl -pi -e "s/MAX_USD_FUNDING = 400000;/MAX_USD_FUNDING = 20000;/" $TOKENTEMPSOL`
`perl -pi -e "s/ONE_DAY = 24\*60\*60;/ONE_DAY = 30;/" $TOKENTEMPSOL`

DIFFS=`diff $TOKENSOL $TOKENTEMPSOL`
echo "--- Differences ---"
echo "$DIFFS"

echo "var tokenOutput=`solc --optimize --combined-json abi,bin,interface $TOKENTEMPSOL`;" > $TOKENJS

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee $TEST1OUTPUT
loadScript("$TOKENJS");
loadScript("functions.js");

var tokenAbi = JSON.parse(tokenOutput.contracts["$TOKENTEMPSOL:SikobaContinuousSale"].abi);
var tokenBin = "0x" + tokenOutput.contracts["$TOKENTEMPSOL:SikobaContinuousSale"].bin;

console.log("DATA: tokenABI=" + JSON.stringify(tokenAbi));

unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.1 Deploy Token Contract";
console.log("RESULT: " + testMessage);
var tokenContract = web3.eth.contract(tokenAbi);
console.log(JSON.stringify(tokenContract));
var tokenTx = null;
var tokenAddress = null;
var usdPerHundredETH = 15178;
var token = tokenContract.new(usdPerHundredETH, {from: tokenOwnerAccount, data: tokenBin, gas: 4000000},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        tokenTx = contract.transactionHash;
      } else {
        tokenAddress = contract.address;
        addAccount(tokenAddress, "TOKEN");
        addTokenContractAddressAndAbi(tokenAddress, tokenAbi);
        console.log("DATA: tokenAddress=" + tokenAddress);
        printTxData("tokenAddress=" + tokenAddress, tokenTx);
      }
    }
  }
);
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tokenTx, testMessage);
printTokenContractStaticDetails();
printTokenContractDynamicDetails();
console.log("RESULT: ");
console.log(JSON.stringify(token));


var skipFundingBeforeStartTest = "$MODE" == "dev" ? true : false;
if (!skipFundingBeforeStartTest) {
  // -----------------------------------------------------------------------------
  var testMessage = "Test 1.2 Send ETH before funding period starts - expect to fail";
  console.log("RESULT: " + testMessage);
  var tx1_2 = eth.sendTransaction({from: account2, to: tokenAddress, gas: 400000, value: web3.toWei("123.456789", "ether")});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  passIfGasEqualsGasUsed(tx1_2, testMessage);
  printTokenContractDynamicDetails();
  console.log("RESULT: ");


  // -----------------------------------------------------------------------------
  var testMessage = "Test 1.3 Mint ETH before funding period starts";
  console.log("RESULT: " + testMessage);
  var tx1_3_1 = token.mint(account4, 1e20, {from: tokenOwnerAccount, gas: 400000});
  var tx1_3_2 = token.mint(account5, 1e20, {from: account5, gas: 400000});
  var tx1_3_3 = token.setMintingCompleted({from: tokenOwnerAccount, gas: 400000});
  var tx1_3_4 = token.mint(account6, 1e20, {from: tokenOwnerAccount, gas: 400000});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfGasEqualsGasUsed(tx1_3_1, testMessage + " - owner mint for account4");
  passIfGasEqualsGasUsed(tx1_3_2, testMessage + " - self mint for account5 will fail");
  failIfGasEqualsGasUsed(tx1_3_3, testMessage + " - minting completed");
  passIfGasEqualsGasUsed(tx1_3_4, testMessage + " - owner mint for account6 will fail");
  printTokenContractDynamicDetails();
  console.log("RESULT: ");
}


var startDateTime = token.START_DATE();
var startDate = new Date(startDateTime * 1000);
console.log("RESULT: Waiting until funding period is active at " + startDateTime + " " + startDate + " currentDate=" + new Date());
while ((new Date()).getTime() < startDate.getTime()) {
}
console.log("RESULT: Waited until funding period is active at " + startDateTime + " " + startDate + " currentDate=" + new Date());
console.log("RESULT: ");

// -----------------------------------------------------------------------------
var testMessage = "Test 1.4 Change USD rate; send ETH account2 1; account3 100; account4 0.001";
console.log("RESULT: " + testMessage);
usdPerHundredETH = 15200;
var tx1_4_1 = token.setUsdPerHundredEth(usdPerHundredETH, {from: tokenOwnerAccount, gas: 100000});
var tx1_4_2 = eth.sendTransaction({from: account2, to: tokenAddress, gas: 400000, value: web3.toWei("1", "ether")});
var tx1_4_3 = eth.sendTransaction({from: account3, to: tokenAddress, gas: 400000, value: web3.toWei("100", "ether")});
var tx1_4_4 = eth.sendTransaction({from: account3, to: tokenAddress, gas: 400000, value: web3.toWei("0.001", "ether")});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_4_1, testMessage + " - change USD rate to " + usdPerHundredETH);
failIfGasEqualsGasUsed(tx1_4_2, testMessage + " - account2 1 ETH");
failIfGasEqualsGasUsed(tx1_4_3, testMessage + " - account3 100 ETH");
passIfGasEqualsGasUsed(tx1_4_4, testMessage + " - account4 0.001 ETH (under min contrib)");
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.5 Account2,3 transfer 2,000 tokens to accounts5,6";
console.log("RESULT: " + testMessage);
var tx1_5_1 = token.transfer(account5, "2000000000000000000000", {from: account2, gas: 100000});
var tx1_5_2 = token.transfer(account6, "2000000000000000000000", {from: account3, gas: 100000});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_5_1, testMessage + " - account2 2,000 tokens has insufficient tokens");
failIfGasEqualsGasUsed(tx1_5_2, testMessage + " - account3 2,000 tokens success");
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.6 Account2 approves transfer of 200 tokens to account6 and account6 transfers; account5 invalid transferFrom";
console.log("RESULT: " + testMessage);
var tx1_6_1 = token.approve(account6, "200000000000000000000", {from: account2, gas: 100000});
while (txpool.status.pending > 0) {
}
var tx1_6_2 = token.transferFrom(account2, account6, "200000000000000000000", {from: account6, gas: 100000});
var tx1_6_2 = token.transferFrom(account3, account5, "200000000000000000000", {from: account5, gas: 100000});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_6_1, testMessage + " - account2 approves");
failIfGasEqualsGasUsed(tx1_6_2, testMessage + " - account6 transferFrom");
failIfGasEqualsGasUsed(tx1_6_2, testMessage + " - account5 transferFrom account3 w/o approval");
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.7 Pause funding; account5 send funds unsuccessfully; restart funding";
console.log("RESULT: " + testMessage);
var tx1_7_1 = token.pause({from: tokenOwnerAccount, gas: 100000});
while (txpool.status.pending > 0) {
}
var tx1_7_2 = eth.sendTransaction({from: account5, to: tokenAddress, gas: 400000, value: web3.toWei("100", "ether")});
while (txpool.status.pending > 0) {
}
var tx1_7_3 = token.restart({from: tokenOwnerAccount, gas: 100000});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_7_1, testMessage + " - pause funding");
failIfGasEqualsGasUsed(tx1_7_2, testMessage + " - account5 sending funds unsuccessfully");
failIfGasEqualsGasUsed(tx1_7_3, testMessage + " - restart funding");
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.8 Account2 send 200 ETH - max funding reached; soft limit +30seconds kicks in";
console.log("RESULT: " + testMessage);
var tx1_8_1 = eth.sendTransaction({from: account2, to: tokenAddress, gas: 400000, value: web3.toWei("200", "ether")});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_8_1, testMessage);
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 1.9 Account2 send 2000 ETH - soft limit in effect and max funding reached";
console.log("RESULT: " + testMessage);
var tx1_9_1 = eth.sendTransaction({from: account2, to: tokenAddress, gas: 400000, value: web3.toWei("2000", "ether")});
while (txpool.status.pending > 0) {
}
printBalances();
failIfGasEqualsGasUsed(tx1_9_1, testMessage);
printTokenContractDynamicDetails();
console.log("RESULT: ");


// Pause - add 1 second to make sure we are past the soft end date
var endDateTime = token.softEndDate().plus(1);
var endDate = new Date(endDateTime * 1000);
console.log("RESULT: Waiting until soft funding period has ended at " + endDateTime + " " + endDate + " currentDate=" + new Date());
while ((new Date()).getTime() < endDate.getTime()) {
}
console.log("RESULT: Waited until soft funding period has ended at " + endDateTime + " " + endDate + " currentDate=" + new Date());
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 2.0 Account2 send 400 ETH - soft end date over";
console.log("RESULT: " + testMessage);
var tx2_0_1 = eth.sendTransaction({from: account2, to: tokenAddress, gas: 400000, value: web3.toWei("400", "ether")});
while (txpool.status.pending > 0) {
}
printBalances();
passIfGasEqualsGasUsed(tx2_0_1, testMessage);
printTokenContractDynamicDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var testMessage = "Test 2.1 Change Ownership";
console.log("RESULT: " + testMessage);
var tx2_1_1 = token.transferOwnership(minerAccount, {from: tokenOwnerAccount, gas: 100000});
while (txpool.status.pending > 0) {
}
var tx2_1_2 = token.acceptOwnership({from: minerAccount, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("tx2_1_1", tx2_1_1);
printTxData("tx2_1_2", tx2_1_2);
printBalances();
failIfGasEqualsGasUsed(tx2_1_1, testMessage + " - Change owner");
failIfGasEqualsGasUsed(tx2_1_2, testMessage + " - Accept ownership");
printTokenContractDynamicDetails();
console.log("RESULT: ");


EOF
grep "DATA: " $TEST1OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
