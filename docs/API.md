# EspoCRM API Documentation

## Overview

EspoCRM provides a comprehensive RESTful API for integration with external services. This document covers authentication, common endpoints, and integration patterns for the standalone deployment.

## Base URL

```
https://crm.yourdomain.com/api/v1
```

## Authentication

EspoCRM supports multiple authentication methods:

### API Key Authentication

1. Generate API key in EspoCRM:
   - Go to Administration > API Users
   - Create new API User
   - Copy the generated API Key

2. Use in requests:
```bash
curl -H "X-Api-Key: YOUR_API_KEY" \
     https://crm.yourdomain.com/api/v1/Contact
```

### Basic Authentication

```bash
curl -u username:password \
     https://crm.yourdomain.com/api/v1/Contact
```

### HMAC Authentication

For enhanced security, use HMAC authentication:

```php
$apiKey = 'YOUR_API_KEY';
$secretKey = 'YOUR_SECRET_KEY';
$method = 'GET';
$uri = '/api/v1/Contact';

$string = $method . ' ' . $uri;
$signature = base64_encode(hash_hmac('sha256', $string, $secretKey, true));

$headers = [
    'X-Api-Key: ' . $apiKey,
    'X-Hmac-Authorization: ' . $signature
];
```

## Core Entities

### Contacts

#### List Contacts
```http
GET /api/v1/Contact
```

Query parameters:
- `offset`: Start position (default: 0)
- `maxSize`: Maximum records (default: 20, max: 200)
- `select`: Fields to return
- `where`: Filter conditions
- `orderBy`: Sort field
- `order`: Sort direction (asc/desc)

Example:
```bash
curl -H "X-Api-Key: YOUR_API_KEY" \
     "https://crm.yourdomain.com/api/v1/Contact?select=firstName,lastName,email&maxSize=50"
```

#### Get Contact
```http
GET /api/v1/Contact/{id}
```

#### Create Contact
```http
POST /api/v1/Contact
Content-Type: application/json

{
  "firstName": "John",
  "lastName": "Doe",
  "emailAddress": "john.doe@example.com",
  "phoneNumber": "+1234567890",
  "accountId": "account-id",
  "description": "New contact from API"
}
```

#### Update Contact
```http
PUT /api/v1/Contact/{id}
Content-Type: application/json

{
  "lastName": "Smith",
  "description": "Updated via API"
}
```

#### Delete Contact
```http
DELETE /api/v1/Contact/{id}
```

### Leads

#### List Leads
```http
GET /api/v1/Lead
```

#### Create Lead
```http
POST /api/v1/Lead
Content-Type: application/json

{
  "firstName": "Jane",
  "lastName": "Smith",
  "emailAddress": "jane@example.com",
  "source": "Web Site",
  "status": "New",
  "industry": "Technology"
}
```

#### Convert Lead
```http
POST /api/v1/Lead/{id}/convert
Content-Type: application/json

{
  "createAccount": true,
  "accountName": "New Company",
  "createContact": true,
  "createOpportunity": true,
  "opportunityName": "New Deal"
}
```

### Accounts

#### List Accounts
```http
GET /api/v1/Account
```

#### Create Account
```http
POST /api/v1/Account
Content-Type: application/json

{
  "name": "Acme Corporation",
  "website": "https://acme.com",
  "type": "Customer",
  "industry": "Technology",
  "billingAddressStreet": "123 Main St",
  "billingAddressCity": "San Francisco",
  "billingAddressState": "CA",
  "billingAddressCountry": "USA",
  "billingAddressPostalCode": "94105"
}
```

### Opportunities

#### List Opportunities
```http
GET /api/v1/Opportunity
```

#### Create Opportunity
```http
POST /api/v1/Opportunity
Content-Type: application/json

{
  "name": "Big Deal",
  "accountId": "account-id",
  "stage": "Prospecting",
  "amount": 50000,
  "probability": 75,
  "closeDate": "2024-12-31",
  "description": "Large enterprise deal"
}
```

### Activities

#### Create Call
```http
POST /api/v1/Call
Content-Type: application/json

{
  "name": "Sales Call",
  "parentType": "Contact",
  "parentId": "contact-id",
  "dateStart": "2024-01-15 10:00:00",
  "duration": 1800,
  "status": "Planned",
  "direction": "Outbound"
}
```

#### Create Meeting
```http
POST /api/v1/Meeting
Content-Type: application/json

{
  "name": "Product Demo",
  "dateStart": "2024-01-20 14:00:00",
  "dateEnd": "2024-01-20 15:00:00",
  "status": "Planned",
  "contactsIds": ["contact-id-1", "contact-id-2"],
  "usersIds": ["user-id"]
}
```

#### Create Task
```http
POST /api/v1/Task
Content-Type: application/json

{
  "name": "Follow up",
  "status": "Not Started",
  "priority": "High",
  "dateEnd": "2024-01-25",
  "parentType": "Opportunity",
  "parentId": "opportunity-id",
  "assignedUserId": "user-id"
}
```

## Advanced Queries

### Filtering

Use the `where` parameter for complex filters:

```javascript
// JavaScript example
const where = [
  {
    type: 'and',
    value: [
      {
        type: 'equals',
        field: 'status',
        value: 'Active'
      },
      {
        type: 'greaterThan',
        field: 'createdAt',
        value: '2024-01-01'
      }
    ]
  }
];

const url = `/api/v1/Contact?where=${encodeURIComponent(JSON.stringify(where))}`;
```

### Relationships

#### Get Related Records
```http
GET /api/v1/{entityType}/{id}/{link}
```

Example - Get contacts for an account:
```http
GET /api/v1/Account/{accountId}/contacts
```

#### Link Records
```http
POST /api/v1/{entityType}/{id}/{link}
Content-Type: application/json

{
  "id": "related-record-id"
}
```

#### Unlink Records
```http
DELETE /api/v1/{entityType}/{id}/{link}/{relatedId}
```

## Bulk Operations

### Bulk Create
```http
POST /api/v1/{entityType}/action/massCreate
Content-Type: application/json

{
  "list": [
    {"firstName": "John", "lastName": "Doe"},
    {"firstName": "Jane", "lastName": "Smith"}
  ]
}
```

### Bulk Update
```http
PUT /api/v1/{entityType}/action/massUpdate
Content-Type: application/json

{
  "ids": ["id1", "id2", "id3"],
  "data": {
    "status": "Active",
    "assignedUserId": "user-id"
  }
}
```

### Bulk Delete
```http
DELETE /api/v1/{entityType}/action/massDelete
Content-Type: application/json

{
  "ids": ["id1", "id2", "id3"]
}
```

## Webhooks

### Webhook Configuration

Configure webhooks in EspoCRM Admin > Webhooks:

1. Create new webhook
2. Set Event (e.g., Contact.create, Lead.update)
3. Set URL endpoint
4. Configure headers if needed

### Webhook Payload

EspoCRM sends POST requests with JSON payload:

```json
{
  "event": "Contact.create",
  "data": {
    "id": "contact-id",
    "firstName": "John",
    "lastName": "Doe",
    "emailAddress": "john@example.com",
    "createdAt": "2024-01-15 10:00:00"
  },
  "userId": "user-who-created",
  "timestamp": 1705320000
}
```

### Webhook Security

Verify webhook authenticity using signature:

```php
$payload = file_get_contents('php://input');
$signature = $_SERVER['HTTP_X_ESPOCRM_SIGNATURE'];
$secret = 'YOUR_WEBHOOK_SECRET';

$expectedSignature = hash_hmac('sha256', $payload, $secret);

if ($signature === $expectedSignature) {
    // Process webhook
}
```

## Integration Examples

### Python Integration

```python
import requests
import json

class EspoCRMClient:
    def __init__(self, url, api_key):
        self.url = url.rstrip('/')
        self.headers = {
            'X-Api-Key': api_key,
            'Content-Type': 'application/json'
        }
    
    def get_contacts(self, limit=20):
        response = requests.get(
            f"{self.url}/api/v1/Contact",
            headers=self.headers,
            params={'maxSize': limit}
        )
        return response.json()
    
    def create_lead(self, data):
        response = requests.post(
            f"{self.url}/api/v1/Lead",
            headers=self.headers,
            json=data
        )
        return response.json()
    
    def update_opportunity(self, opp_id, data):
        response = requests.put(
            f"{self.url}/api/v1/Opportunity/{opp_id}",
            headers=self.headers,
            json=data
        )
        return response.json()

# Usage
client = EspoCRMClient('https://crm.yourdomain.com', 'YOUR_API_KEY')

# Get contacts
contacts = client.get_contacts(limit=50)

# Create lead
lead = client.create_lead({
    'firstName': 'New',
    'lastName': 'Lead',
    'emailAddress': 'lead@example.com'
})
```

### Node.js Integration

```javascript
const axios = require('axios');

class EspoCRMClient {
    constructor(url, apiKey) {
        this.url = url.replace(/\/$/, '');
        this.headers = {
            'X-Api-Key': apiKey,
            'Content-Type': 'application/json'
        };
    }
    
    async getAccounts(filters = {}) {
        const response = await axios.get(
            `${this.url}/api/v1/Account`,
            {
                headers: this.headers,
                params: filters
            }
        );
        return response.data;
    }
    
    async createContact(data) {
        const response = await axios.post(
            `${this.url}/api/v1/Contact`,
            data,
            { headers: this.headers }
        );
        return response.data;
    }
    
    async linkContactToAccount(contactId, accountId) {
        const response = await axios.post(
            `${this.url}/api/v1/Contact/${contactId}/account`,
            { id: accountId },
            { headers: this.headers }
        );
        return response.data;
    }
}

// Usage
const client = new EspoCRMClient('https://crm.yourdomain.com', 'YOUR_API_KEY');

(async () => {
    // Get accounts
    const accounts = await client.getAccounts({ maxSize: 10 });
    
    // Create contact
    const contact = await client.createContact({
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john@example.com'
    });
    
    // Link to account
    if (accounts.list.length > 0) {
        await client.linkContactToAccount(contact.id, accounts.list[0].id);
    }
})();
```

## Rate Limiting

The API implements rate limiting to prevent abuse:

- Default: 1000 requests per hour per API key
- Bulk operations: 100 requests per hour
- Search operations: 500 requests per hour

Rate limit headers in response:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1705324800
```

## Error Handling

API errors return appropriate HTTP status codes:

- `200 OK`: Success
- `201 Created`: Resource created
- `204 No Content`: Success with no response body
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication failed
- `403 Forbidden`: Access denied
- `404 Not Found`: Resource not found
- `409 Conflict`: Duplicate or conflict
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

Error response format:
```json
{
  "error": {
    "status": 400,
    "message": "Bad Request",
    "description": "Field 'emailAddress' is not valid"
  }
}
```

## Best Practices

1. **Use Pagination**: Always paginate large result sets
2. **Select Fields**: Only request fields you need using `select` parameter
3. **Cache Results**: Cache frequently accessed data
4. **Handle Errors**: Implement proper error handling and retries
5. **Respect Rate Limits**: Monitor rate limit headers
6. **Use Webhooks**: For real-time updates instead of polling
7. **Batch Operations**: Use bulk endpoints for multiple operations
8. **Secure Keys**: Never expose API keys in client-side code

## Additional Resources

- [EspoCRM REST API Documentation](https://docs.espocrm.com/development/api/)
- [EspoCRM Development Guide](https://docs.espocrm.com/development/)
- [API Client Libraries](https://docs.espocrm.com/development/api-client/)

---

For integration support, please refer to the main [README](../README.md) or open an issue in the repository.