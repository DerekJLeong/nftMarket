import { useEffect, useCallback } from "react";
import Web3 from "web3";
import Web3Modal from "web3modal";
import WalletLink from "walletlink";
import { ethers } from "ethers";
import WalletConnectProvider from "@walletconnect/web3-provider";

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || "";
const providerOptions = {
   walletconnect: {
      package: WalletConnectProvider,
      options: {
         infuraId: INFURA_PROJECT_ID,
      },
   },
   "custom-walletlink": {
      display: {
         logo: "https://play-lh.googleusercontent.com/PjoJoG27miSglVBXoXrxBSLveV6e3EeBPpNY55aiUUBM9Q1RCETKCOqdOkX2ZydqVf0",
         name: "Coinbase",
         description: "Connect to Coinbase Wallet (not Coinbase App)",
      },
      options: {
         appName: "Coinbase",
         networkUrl: `https://mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
         chainId: 1,
      },
      package: WalletLink,
      connector: async (_, options) => {
         const { appName, networkUrl, chainId } = options;
         const walletLink = new WalletLink({
            appName,
         });
         const provider = walletLink.makeWeb3Provider(networkUrl, chainId);
         await provider.enable();
         return provider;
      },
   },
};

export let web3Modal;
export let connection;
export let provider;

export const connect = async () => {
   web3Modal = new Web3Modal({
      cacheProvider: true,
      providerOptions,
   });
   // connection that is returned when
   // using web3Modal to connect. Can be MetaMask or WalletConnect.
   try {
      connection = await web3Modal.connect();
      // We plug the initial `provider` into ethers.js and get back
      // a Web3Provider. This will add on methods from ethers.js and
      // event listeners such as `.on()` will be different.
      provider = new ethers.providers.Web3Provider(connection);
      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      const network = await provider.getNetwork();
      const { chainId } = network;
      console.log("CONNECTED", chainId, signer, address, provider);

      return { address, chainId };
   } catch (error) {
      return console.error("Could not get a wallet connection", error);
   }
};

export const disconnect = async () => {
   if (!web3Modal) {
      web3Modal = new Web3Modal({
         cacheProvider: true,
         providerOptions,
      });
   }
   await web3Modal.clearCachedProvider();
   if (provider?.disconnect && typeof provider.disconnect === "function") {
      await provider.disconnect();
   }
};
