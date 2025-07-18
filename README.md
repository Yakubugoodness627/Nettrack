# Nettrack - Malaria Net Distribution Tracker

A Clarity smart contract for tracking malaria net distributions with location verification and QR code authentication.

## Overview

Nettrack enables transparent and verifiable distribution of malaria nets through:
- Distribution center management
- Location-based verification
- QR code authentication system
- Recipient tracking to prevent double distribution
- Comprehensive distribution logging

## Key Features

- **Distribution Centers**: Register and manage multiple distribution locations
- **Location Verification**: GPS coordinate validation within acceptable range
- **QR Code System**: Generate and verify unique QR codes for each distribution
- **Recipient Management**: Track recipients and prevent duplicate distributions
- **Stock Management**: Monitor inventory levels across distribution centers
- **Audit Trail**: Complete distribution history with timestamps

## Contract Functions

### Admin Functions

#### `initialize-contract()`
Initialize the contract (owner only).

#### `add-distribution-center(name, location, latitude, longitude, initial-stock)`
Register a new distribution center.
- `name`: Distribution center name (max 100 chars)
- `location`: Physical address/description
- `latitude`/`longitude`: GPS coordinates for verification
- `initial-stock`: Starting inventory count

#### `update-center-stock(center-id, new-stock)`
Update inventory for a distribution center.

#### `deactivate-center(center-id)`
Temporarily disable a distribution center.

#### `generate-qr-code(center-id, recipient-id, qr-hash)`
Create a new QR code for distribution.

#### `register-recipient(recipient-id, name, location)`
Add a new recipient to the system.

### Distribution Functions

#### `distribute-nets(center-id, recipient-id, nets-count, qr-hash, latitude, longitude)`
Execute a net distribution with full verification:
- Validates QR code authenticity
- Confirms sufficient stock
- Verifies location proximity
- Records complete transaction

#### `verify-distribution(qr-hash)`
Verify a completed distribution using QR code.

### Emergency Functions

#### `emergency-stop()`
Pause all contract operations (owner only).

#### `resume-contract()`
Resume contract operations (owner only).

## Read-Only Functions

- `get-distribution-center(center-id)`: Get center details
- `get-recipient(recipient-id)`: Get recipient information
- `get-qr-code-info(qr-hash)`: Get QR code status
- `get-distribution-log(log-id)`: Get distribution record
- `get-total-distributions()`: Total nets distributed
- `get-total-centers()`: Number of centers
- `get-center-stats(center-id)`: Center performance metrics
- `is-qr-code-valid(qr-hash)`: Check QR code validity
- `get-recipient-history(recipient-id)`: Recipient's distribution history

## Usage Examples

### Setting Up a Distribution Center

```clarity
;; Add a new distribution center
(contract-call? .nettrack add-distribution-center 
  "Kampala Health Center" 
  "123 Main St, Kampala" 
  32450 
  -112340 
  u1000)
```

### Registering a Recipient

```clarity
;; Register a new recipient
(contract-call? .nettrack register-recipient 
  "RCP001" 
  "John Doe" 
  "Village A, District 1")
```

### Generating QR Code

```clarity
;; Generate QR code for distribution
(contract-call? .nettrack generate-qr-code 
  u1 
  "RCP001" 
  "QR123ABC456")
```

### Executing Distribution

```clarity
;; Distribute nets with verification
(contract-call? .nettrack distribute-nets 
  u1 
  "RCP001" 
  u5 
  "QR123ABC456" 
  32450 
  -112340)
```

### Verifying Distribution

```clarity
;; Verify a completed distribution
(contract-call? .nettrack verify-distribution "QR123ABC456")
```

## Location Verification

The contract includes location verification to ensure distributions occur at registered centers:
- GPS coordinates must be within 1000 units of the registered center location
- Location verification status is recorded in distribution logs
- Failed location verification still allows distribution but marks it as unverified

## Error Codes

- `u100`: Owner only operation
- `u101`: Record not found
- `u102`: Record already exists
- `u103`: Invalid location data
- `u104`: Insufficient stock
- `u105`: Already distributed
- `u106`: Invalid QR code
- `u107`: Center inactive
- `u108`: Recipient already exists

## Security Features

- Owner-only administrative functions
- QR code uniqueness validation
- Prevention of double distributions
- Location verification system
- Emergency stop functionality
- Comprehensive audit logging

## Deployment

1. Deploy using Clarinet: `clarinet deploy`
2. Initialize contract: `(contract-call? .nettrack initialize-contract)`
3. Add distribution centers and begin operations

## Testing

Run tests with: `clarinet test`

## License

This project is open source and available under the MIT License.
