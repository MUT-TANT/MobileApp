# Morpho Integration

StackSave integrates with **Morpho Protocol** to help your savings earn passive income while maintaining full liquidity.

## 🌟 What is Morpho?

[Morpho](https://morpho.org) is a leading DeFi lending optimizer built on Ethereum. It improves capital efficiency and provides better rates for lenders and borrowers by optimizing positions across established lending protocols like Aave and Compound.

### Key Advantages

- **Optimized Rates**: Morpho provides peer-to-peer matching to improve lending rates
- **Security**: Audited by leading security firms, non-custodial
- **Composability**: Built on top of proven protocols (Aave, Compound)
- **Liquidity**: Withdraw anytime, no lock-up periods
- **Transparency**: Open-source, fully on-chain

---

## 💰 How StackSave Uses Morpho

### Automatic Yield Generation

When you deposit funds into a StackSave goal, your USDC is automatically:

1. **Deposited** to your savings goal smart contract
2. **Lent** via Morpho Protocol to earn yield
3. **Optimized** for best available rates
4. **Compounded** automatically (earnings added to principal)
5. **Available** for withdrawal anytime

### The Flow

```
User Deposit (USDC)
       ↓
StackSave Smart Contract
       ↓
Morpho Protocol
       ↓
Lending Pool (Aave/Compound)
       ↓
Borrowers
       ↓
Interest Earned
       ↓
Auto-compounded back to your goal
```

---

## 📊 Yield & APY

### Current Rates

Morpho rates are **variable** and depend on market supply/demand:

- **USDC Lending APY**: Typically 2-8% annually
- **Rate Updates**: Real-time based on Morpho market
- **Historical Performance**: View on [Morpho Analytics](https://app.morpho.org)

### Rate Comparison

| Platform | Typical USDC APY | Liquidity | Risk |
|----------|------------------|-----------|------|
| **Morpho (via StackSave)** | **4-6%** | **Instant** | **Low** |
| Traditional Savings | 0.1-0.5% | Instant | Very Low |
| Aave Direct | 2-4% | Instant | Low |
| Compound Direct | 2-4% | Instant | Low |

**Why Morpho is Better**:
- Peer-to-peer matching improves rates
- Fallback to Aave/Compound ensures liquidity
- No additional risk vs. using Aave/Compound directly

---

## 🔐 Security

### Smart Contract Audits

Morpho has been audited by:
- ✅ [Trail of Bits](https://github.com/morpho-org/morpho-optimizers-audits)
- ✅ [Spearbit](https://github.com/morpho-org/morpho-optimizers-audits)
- ✅ [Chainsecurity](https://github.com/morpho-org/morpho-optimizers-audits)

### Security Features

- **Non-custodial**: You always control your funds
- **Proven Protocols**: Built on top of Aave/Compound
- **No New Risk**: Same security model as underlying protocols
- **Emergency Pause**: Protocol governance can pause if needed
- **Insurance**: Morpho positions may be covered by protocol insurance

### Risk Considerations

**Low Risk**:
- ✅ Audited smart contracts
- ✅ Battle-tested underlying protocols
- ✅ High TVL (~$billions)
- ✅ Active development team

**Potential Risks** (inherent to all DeFi):
- ⚠️ Smart contract vulnerabilities (mitigated by audits)
- ⚠️ Oracle failures (rare)
- ⚠️ Protocol governance risks
- ⚠️ Blockchain network issues

---

## 💡 How to Use

### Earning Yield is Automatic

**You don't need to do anything special!**

1. **Create a savings goal** in StackSave
2. **Deposit USDC** to your goal
3. **Yield starts earning** automatically
4. **Track earnings** in your goal details
5. **Withdraw anytime** (principal + earnings)

### Viewing Your Earnings

**In StackSave**:
- Goal Details → "Total Earnings"
- Portfolio → "Yield Summary"
- Transaction History → "Interest Earned"

**On-Chain**:
- Check your goal's smart contract address
- View on [Morpho App](https://app.morpho.org)
- Verify earnings on [Etherscan](https://etherscan.io)

---

## 📈 Example Earnings

### Scenario 1: Short-term Savings

```
Goal: Vacation Fund
Deposit: $2,000 USDC
Duration: 3 months
Morpho APY: 5%

After 3 months:
Principal: $2,000.00
Interest:  $   24.85
Total:     $2,024.85

Your vacation just got $25 cheaper! 🎉
```

### Scenario 2: Long-term Goal

```
Goal: Emergency Fund
Deposit: $10,000 USDC
Duration: 12 months
Morpho APY: 5% (compounded)

After 12 months:
Principal:  $10,000.00
Interest:   $   512.50 (with compounding)
Total:      $10,512.50

Earned $512 while building your emergency fund! 💰
```

### Scenario 3: Regular Contributions

```
Goal: New Car
Monthly Deposit: $500 USDC
Duration: 12 months
Morpho APY: 5%

After 12 months:
Total Deposited: $6,000.00
Interest Earned: $  158.75
Total:           $6,158.75

Extra $158 toward your car! 🚗
```

---

## 🔧 Technical Details

### Smart Contract Integration

**StackSave → Morpho Flow**:

```solidity
// Simplified example
contract StackSaveGoal {
    IMorpho public morpho;

    function deposit(uint256 amount) external {
        // Transfer USDC from user
        usdc.transferFrom(msg.sender, address(this), amount);

        // Approve Morpho
        usdc.approve(address(morpho), amount);

        // Deposit to Morpho to earn yield
        morpho.supply(
            poolToken,
            amount,
            address(this),
            maxIterations
        );

        // Update user's goal balance
        goals[msg.sender].balance += amount;
    }

    function withdraw(uint256 amount) external {
        // Withdraw from Morpho (principal + yield)
        uint256 withdrawn = morpho.withdraw(
            poolToken,
            amount,
            address(this),
            msg.sender,
            maxIterations
        );

        // Update balance
        goals[msg.sender].balance -= amount;
    }
}
```

### Morpho Market

StackSave uses Morpho's **USDC market** by default:

- **Asset**: USDC (USD Coin)
- **Network**: Ethereum Mainnet (or custom fork for hackathon)
- **Pool**: Morpho-Aave USDC
- **Collateralization**: Over-collateralized lending

---

## 📚 Learn More

### Morpho Resources

- **Website**: [morpho.org](https://morpho.org)
- **App**: [app.morpho.org](https://app.morpho.org)
- **Documentation**: [docs.morpho.org](https://docs.morpho.org)
- **GitHub**: [github.com/morpho-org](https://github.com/morpho-org)
- **Audits**: [Audit Reports](https://github.com/morpho-org/morpho-optimizers-audits)

### StackSave + Morpho

- **Smart Contracts**: See [StackSave GitHub](https://github.com/MUT-TANT/SmartContract)
- **Architecture**: [Technical Docs](../architecture/project-structure.md)
- **Security**: [Security Practices](../resources/faq.md#security)

---

## ❓ FAQ

### How much can I earn?

**Variable**, typically 2-8% APY on USDC. Rates depend on market supply and demand. Check [Morpho App](https://app.morpho.org) for current rates.

### Is my money safe?

Yes. Morpho is:
- ✅ Audited by top security firms
- ✅ Built on proven protocols (Aave, Compound)
- ✅ Non-custodial (you control your funds)
- ✅ High TVL with active usage

### Can I withdraw anytime?

**Yes!** There are no lock-up periods. You can withdraw your full balance (principal + earnings) at any time.

### Are there fees?

- **Morpho Fees**: None! Morpho does not charge fees
- **StackSave Fees**: None! We don't take a cut of your earnings
- **Network Gas**: You pay gas fees for deposits/withdrawals (normal Ethereum fees)

### What if Morpho rates drop?

Rates fluctuate based on market conditions. Even at lower rates (2-3%), you're still earning more than traditional savings accounts (0.1-0.5%).

### Can I opt-out of Morpho?

Currently, all StackSave deposits automatically use Morpho. This ensures all users benefit from yield optimization.

**Future**: We may add an option to disable yield earning if you prefer.

### How is yield calculated?

- **APY**: Annual Percentage Yield (includes compounding)
- **Compounding**: Interest earned also earns interest
- **Real-time**: Earnings accrue every Ethereum block (~12 seconds)
- **Display**: Updated in your goal balance

### What happens if I donate a percentage?

Donations are calculated **after** yield earnings:

```
Example:
Deposit: $1,000
Yield earned: $50
Total: $1,050

With 5% donation:
Donation: $52.50 (5% of $1,050)
Your Balance: $997.50
```

You still earned $47.50 in yield, and donated $52.50 to charity! 🙏

---

## 🚀 Next Steps

- [Create Your First Goal](../getting-started/first-goal.md)
- [Make a Deposit](../features/savings-goals.md#making-deposits)
- [Track Your Earnings](../features/portfolio.md)
- [Learn About Donations](../features/savings-goals.md#donation-allocation)

---

**Start earning passive income on your savings today!** 💰📈
