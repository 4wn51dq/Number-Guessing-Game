import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { CONTRACT_ABI, CONTRACT_ADDRESS } from "./constants";

function App() {
  const [provider, setProvider] = useState();
  const [signer, setSigner] = useState();
  const [contract, setContract] = useState();
  const [guess, setGuess] = useState(0);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const connect = async () => {
      const prov = new ethers.providers.Web3Provider(window.ethereum);
      await window.ethereum.request({ method: "eth_requestAccounts" });
      const signer = prov.getSigner();
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      setProvider(prov);
      setSigner(signer);
      setContract(contract);
    };
    connect();
  }, []);

  const enterGame = async () => {
    try {
      const fee = await contract.FEE();
      const tx = await contract.enterGame(guess, { value: fee });
      await tx.wait();
      setMessage("You entered the game!");
    } catch (err) {
      console.error(err);
      setMessage("Failed to enter.");
    }
  };

  return (
    <div style={{ padding: "2rem" }}>
      <h1>🔢 Guess the Secret Number</h1>
      <input
        type="number"
        placeholder="Guess (1-9)"
        value={guess}
        onChange={(e) => setGuess(Number(e.target.value))}
      />
      <button onClick={enterGame}>Enter Game</button>
      <p>{message}</p>
    </div>
  );
}

export default App;
