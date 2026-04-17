# Shoink

Shoink is a terminal-based URL shortener built in Bash. It wraps multiple shortening services behind one menu-driven CLI and now supports both interactive use and lightweight command-line automation.

> Version: `v1.4`  
> Status: Ready to use

## Features

- Shorten links with **TinyURL**
- Manage **TinyURL** aliases, lookups, listings, and counts
- Shorten and manage links with **Tiny.cc**
- Shorten and inspect links with **ulvis.net**
- Optional custom aliases
- Interactive terminal menus
- Non-interactive CLI mode for automation
- Safe `.env` loading for TinyURL and Tiny.cc credentials
- Clear validation and error messages for missing config or bad input

## Supported Services

### TinyURL

- Create shortened URLs
- Use an optional custom alias
- Update an existing alias
- Inspect an existing TinyURL
- List available TinyURLs
- Count total or filtered TinyURLs

### Tiny.cc

- Create shortened URLs
- Use an optional custom alias
- List and search existing URLs
- Fetch account information
- Edit an existing URL destination and alias

### ulvis.net

- Create shortened URLs without an API key
- Use an optional custom alias
- Mark links as private
- Protect links with a password
- Set a max-use limit
- Set an expiration date
- Inspect an existing ulvis short link

## Requirements

- Bash
- `curl`
- `jq`

On Debian or Ubuntu:

```bash
sudo apt install curl jq
```

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/supunhg/Shoink
cd Shoink
```

### 2. Create a `.env` file

The `.env` file is only required for TinyURL and Tiny.cc. ulvis.net works without credentials.

Shoink accepts either plain `KEY=value` lines or `export KEY=value` lines.

```env
TINYURL_API_KEY=your_tinyurl_api_key_here
TINYCC_USER=your_tinycc_username_here
TINYCC_API_KEY=your_tinycc_api_key_here
```

Keep `.env` private and out of version control.

### 3. Make the script executable

```bash
chmod +x shoink.sh
```

## Usage

### Interactive mode

```bash
./shoink.sh
```

Use `/q` at any prompt to quit immediately.

Main menu:

```text
(=) Choose a service:

1. TinyURL
2. Tiny.cc
3. ulvis.net
4. Coming soon...
5. Exit
```

### CLI mode

Shorten a URL with TinyURL:

```bash
./shoink.sh --service tinyurl --url https://example.com
```

Shorten a URL with Tiny.cc using a custom alias:

```bash
./shoink.sh --service tinycc --url https://example.com --alias demo
```

Shorten a URL with ulvis.net and extra options:

```bash
./shoink.sh --service ulvis \
  --url https://example.com \
  --alias demo \
  --private \
  --password 1234 \
  --uses 5 \
  --expire 12/31/2026
```

Inspect an existing TinyURL:

```bash
./shoink.sh --service tinyurl --lookup my-alias
```

Inspect an existing ulvis link:

```bash
./shoink.sh --service ulvis --lookup my-alias
```

Show help:

```bash
./shoink.sh --help
```

## Project Structure

```text
Shoink/
├── shoink.sh
├── .env
└── README.md
```

## Roadmap

| Feature | Status |
| --- | --- |
| TinyURL support | Complete |
| Tiny.cc integration | Complete |
| ulvis.net support | Complete |
| CLI argument support | Complete |
| History and logging | Planned |
| More services | Planned |

## Notes

- TinyURL and Tiny.cc features depend on valid account credentials.
- ulvis.net support is implemented from the public developer API at `https://ulvis.net/developer.html`.
- API behavior is still subject to the service providers' own limits, availability, and policy changes.

## Author

Crafted with minimalism and functionality in mind by Supun Hewagamage.
