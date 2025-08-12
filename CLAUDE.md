# Nitter Project Information for Claude

## Project Overview
Nitter is an alternative Twitter/X front-end focused on privacy and performance. It's written in Nim and provides a JavaScript-free way to browse Twitter content.

## Key Architecture Components

### Core Technologies
- **Language**: Nim (version 1.6.10+)
- **Web Framework**: Jester
- **Database**: Redis/Valkey for caching
- **CSS**: SASS/SCSS
- **Authentication**: OAuth 1.0a with Twitter API

### Project Structure
```
/home/geddle/github/nitter/
├── src/                    # Main source code
│   ├── nitter.nim         # Main application entry point
│   ├── api.nim            # Twitter API client
│   ├── auth.nim           # Session management
│   ├── types.nim          # Type definitions
│   ├── routes/            # HTTP route handlers
│   ├── views/             # HTML templates
│   └── experimental/      # New parser implementations
├── public/                # Static assets
├── sessions.jsonl         # Twitter session tokens (required)
├── nitter.conf           # Configuration file
└── nitter.service        # Systemd service file
```

## Building and Running

### Build Commands
```bash
# Build the application (creates 'nitter' binary)
nimble build -d:danger --mm:refc

# Generate CSS from SCSS
nimble scss

# Render markdown files
nimble md

# Run tests
nimble test
```

### Running the Service
```bash
# With systemd (production)
sudo systemctl restart nitter
sudo systemctl status nitter
sudo journalctl -u nitter -f  # View logs

# Direct execution (development)
./nitter

# Service runs on port 8686 by default (configured in nitter.conf)
```

## Configuration
- **Config File**: `nitter.conf`
- **Port**: 8686
- **Redis**: localhost:6379
- **Sessions**: Required, stored in `sessions.jsonl`

## Authentication System
- Uses Twitter OAuth 1.0a tokens stored in `sessions.jsonl`
- Session pool management in `src/auth.nim`
- Rate limiting per API endpoint
- Automatic session rotation and invalidation

## API Endpoints Added

### JSON API Endpoints (NEW)
1. **User Profile**: `/api/user/{username}`
   - Returns user profile information as JSON
   
2. **User Tweets**: `/api/tweets?username={username}&cursor={cursor}`
   - Returns paginated tweets for a user
   - Cursor for pagination

### Existing Web Endpoints
- `/{username}` - User timeline
- `/{username}/status/{id}` - Individual tweet
- `/search` - Search functionality
- `/i/lists/{id}` - Twitter lists

## Twitter API Integration
- Uses Twitter's internal GraphQL endpoints
- Consumer keys hardcoded in `src/consts.nim`
- OAuth signatures generated per request
- Rate limit tracking per session/endpoint

## Important Files for Modifications

### For JSON API Development
- `src/json_api.nim` - JSON serialization functions
- `src/routes/json_api.nim` - JSON route handlers
- `src/nitter.nim` - Route registration (line 106: extend jsonApi)

### For Core Functionality
- `src/api.nim` - Twitter API client functions
- `src/auth.nim` - Session management
- `src/parser.nim` - Response parsing
- `src/types.nim` - Data type definitions

## Common Issues and Solutions

### Build Issues
- If `nimble build` shows "No binaries built", check if binary was actually created
- Config.nims syntax must use `switch()` functions, not command-line style flags
- Compilation errors with `%*` operator: ensure `json` module is exported in router_utils

### Runtime Issues
- "No sessions available": Check `sessions.jsonl` exists and has valid tokens
- Rate limiting: Sessions auto-rotate, but may need to wait if all are limited
- Connection refused: Check if service is running on correct port (8686)

## Testing Endpoints
```bash
# Test JSON API
curl http://localhost:8686/api/user/BBCBreaking
curl "http://localhost:8686/api/tweets?username=BBCBreaking&cursor="

# Test web interface
curl http://localhost:8686/BBCBreaking

# Check service health
curl http://localhost:8686/.health
```

## Development Workflow
1. Make changes to source files
2. Run `nimble build -d:danger --mm:refc` to compile
3. Restart service: `sudo systemctl restart nitter`
4. Check logs: `sudo journalctl -u nitter -f`
5. Test endpoints with curl

## Security Notes
- Never commit `sessions.jsonl` (contains authentication tokens)
- HMAC key in config should be kept secret
- Run behind reverse proxy (nginx/apache) in production
- Sessions are real Twitter accounts - handle carefully

## Dependencies
- libpcre (regex)
- libsass (CSS compilation)
- redis-server or valkey (caching)
- Nim compiler (1.6.10+)

## Debugging
- Enable debug mode in `nitter.conf`: `enableDebug = true`
- Check session pool health: `curl http://localhost:8686/.health`
- View session details: `curl http://localhost:8686/.sessions` (requires debug mode)

## Recent Changes
- Added JSON API endpoints for programmatic access
- Routes registered in order - JSON routes must come before catch-all routes
- Using `Result[Tweets]` type for timelines (nested array structure)