# Crowdfunding Smart Contract

This smart contract enables users to create crowdfunding campaigns, contribute STX funds, withdraw successfully raised funds, and request refunds if a campaign fails.

## Features
- **Campaign Creation**: Users can initiate a fundraising campaign with a specific funding goal.
- **STX Contributions**: Supporters can contribute STX to active campaigns.
- **Fund Withdrawal**: If the funding goal is met, the campaign creator can withdraw the raised funds.
- **Refund Requests**: If the campaign fails, contributors can claim refunds.
- **Status Tracking**: View campaign details and contributions.

## Smart Contract Overview

### Constants
- `SYSTEM_ADMIN`: The system administrator.
- `CAMPAIGN_LIFETIME`: Campaign duration (14 days at 10-minute blocks).
- Error codes for validation and failures.

### Data Structures
- `FundraisingCampaigns`: Stores campaign details.
- `ContributorRecords`: Tracks individual contributions.

### Public Functions
#### `initialize-campaign (target-funds uint) -> (response uint uint)`
Creates a new crowdfunding campaign.

#### `support-campaign (campaign-ref uint, amount uint) -> (response bool uint)`
Allows users to contribute STX to an active campaign.

#### `retrieve-funds (campaign-ref uint) -> (response bool uint)`
Enables campaign initiators to withdraw funds if the goal is met.

#### `request-refund (campaign-ref uint) -> (response bool uint)`
Allows contributors to claim refunds if a campaign fails.

### Read-Only Functions
#### `fetch-campaign (campaign-ref uint) -> (optional tuple)`
Retrieves details of a specific campaign.

#### `fetch-latest-campaign-ref () -> (response uint uint)`
Returns the latest campaign reference ID.

#### `fetch-contribution (campaign-ref uint, supporter principal) -> (optional tuple)`
Retrieves a user's contribution to a campaign.

## Deployment & Usage
1. Deploy the contract on the Stacks blockchain.
2. Call `initialize-campaign` to create a new campaign.
3. Use `support-campaign` to contribute STX.
4. If the campaign succeeds, the creator calls `retrieve-funds`.
5. If the campaign fails, contributors call `request-refund`.

## Security Considerations
- **Validations**: Ensures only authorized actions occur.
- **Fund Transfers**: Uses `stx-transfer?` for secure transactions.
- **Campaign Lifecycle**: Prevents manipulation by tracking expiry blocks.

## License
This smart contract is open-source and available under the MIT License.

