# 👕 Digital Clothing Resale Market

A decentralized marketplace for trading NFT wearables across metaverse platforms on the Stacks blockchain.

## 🌟 Features

- **🛍️ NFT Wearables Trading**: Buy and sell digital clothing items as NFTs
- **🌐 Multi-Platform Support**: Trade across different metaverse platforms 
- **✅ Platform Verification**: Only verified platforms can participate
- **💳 Escrow System**: Secure transactions with automatic fund distribution
- **📊 User Profiles**: Track reputation, sales, and purchase history
- **🔒 Trade Protection**: Configurable trade locks and expiry dates
- **📈 Analytics**: Platform statistics and trade history tracking

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Check contract compilation:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

## 💡 Usage

### 👤 User Profile Management

Create a user profile to start trading:

```clarity
(contract-call? .dig-clothing-resale create-profile "username")
```

### 🏢 Platform Initialization (Owner Only)

Initialize a verified platform:

```clarity
(contract-call? .dig-clothing-resale initialize-platform "metaverse-platform" u100)
```

### 📝 Listing Items

List your NFT wearable for sale:

```clarity
(contract-call? .dig-clothing-resale list-clothing 
  'SP1234...CONTRACT  ;; NFT contract
  u1                  ;; Token ID
  u1000000           ;; Price in microSTX
  "platform-name"    ;; Platform
  "excellent"        ;; Condition
  "M"               ;; Size
  "Nike"            ;; Brand
  "sneakers"        ;; Category
  u1000             ;; Duration in blocks
)
```

### 💰 Purchasing Items

Buy a listed item:

```clarity
(contract-call? .dig-clothing-resale purchase-clothing u1)
```

### 📊 View Listings

Get listing details:

```clarity
(contract-call? .dig-clothing-resale get-listing u1)
```

### 👥 User Stats

Check user profile:

```clarity
(contract-call? .dig-clothing-resale get-user-profile 'SP1234...USER)
```

## 🔧 Contract Functions

### Public Functions

- `initialize-platform` - Add verified platform (owner only)
- `create-profile` - Create user profile
- `list-clothing` - List NFT wearable for sale
- `purchase-clothing` - Buy listed item
- `cancel-listing` - Cancel active listing
- `update-listing-price` - Update listing price
- `set-platform-fee` - Set platform fee (owner only)
- `pause-contract` / `unpause-contract` - Emergency controls (owner only)

### Read-Only Functions

- `get-listing` - Get listing details
- `get-user-profile` - Get user profile
- `get-trade-history` - Get trade record
- `get-platform-stats` - Get platform statistics
- `is-verified-platform` - Check platform verification
- `get-contract-info` - Get contract information

## 📋 Data Structures

### Listing Structure
```clarity
{
  seller: principal,
  nft-contract: principal,
  token-id: uint,
  price: uint,
  platform: string-ascii,
  condition: string-ascii,
  size: string-ascii,
  brand: string-ascii,
  category: string-ascii,
  expiry-block: uint,
  active: bool,
  created-at: uint
}
```

### User Profile
```clarity
{
  username: string-ascii,
  reputation: uint,
  total-sales: uint,
  total-purchases: uint,
  created-at: uint
}
```

## 🛡️ Security Features

- **Owner-only functions** for critical operations
- **Input validation** for all parameters
- **Expiry mechanisms** to prevent stale listings
- **Escrow system** for secure transactions
- **Emergency pause** functionality
- **Platform verification** system

## 🔥 Error Codes

- `u100` - Owner only
- `u101` - Not found
- `u102` - Unauthorized
- `u103` - Invalid price
- `u104` - Listing expired
- `u105` - Insufficient funds
- `u106` - Already listed
- `u107` - Invalid platform
- `u108` - Trade locked
- `u109` - Invalid condition

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 📈 Future Enhancements

- 🔍 Advanced search and filtering
- 🎯 Auction functionality
- 🏆 Reward system for active traders
- 📱 Mobile app integration
- 🤖 AI-powered recommendations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Team

Built with ❤️ for the metaverse community.
