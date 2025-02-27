# SportsFan Token

A decentralized platform for sports team engagement powered by Stacks blockchain, enabling fans to participate in team decisions and access exclusive benefits.

## Overview

SportsFan Token (SFT) is a fungible token implementation that creates a bridge between sports teams and their fans through blockchain technology. The platform enables token holders to participate in team decisions, purchase match tickets, and engage with their favorite teams in meaningful ways.

## Features

- **Fungible Token**: Native token for the sports ecosystem
- **Match Tickets**: Purchase tickets using SportsFan tokens
- **Voting Rights**: Participate in team decisions
- **Balance Management**: Track and transfer tokens between users

## Smart Contract Functions

### Token Operations

- `mint`: Create new tokens (owner-restricted)
- `transfer`: Transfer tokens between users
- `get-balance`: Check token balance for any address

### Match Tickets

- `buy-match-ticket`: Purchase tickets using SportsFan tokens
- `get-match-tickets`: View ticket holdings for specific matches

### Governance

- `cast-vote`: Participate in team decisions
- `has-voted`: Check voting status for an address

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner-only operation |
| u101 | Insufficient balance |

## Getting Started

1. Install Clarinet
```bash
curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64-glibc.tar.gz | tar xz
```

2. Clone the repository
```bash
git clone https://github.com/Simeonkrystal012/SportsFan-Token.git
```

3. Run tests
```bash
clarinet test
```

4. Deploy contract
```bash
clarinet deploy
```

## Usage Examples

### Purchasing Match Tickets
```clarity
(contract-call? .sportsfan buy-match-ticket u1 u2)
```

### Casting Votes
```clarity
(contract-call? .sportsfan cast-vote u1)
```

## Technical Architecture

- Built on Stacks blockchain
- Clarity smart contract language
- Fungible token standard implementation
- Map-based data storage for tickets and votes

## Security

- Owner-restricted minting
- Single-vote mechanism per address
- Balance verification for operations
- Non-reentrant voting system

## Future Roadmap

1. Merchandise discount integration
2. Multiple ticket tiers
3. Enhanced voting mechanisms
4. Team-specific customizations
5. Secondary ticket market

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

MIT License

## Contact

For inquiries and support, please open an issue in the repository.
