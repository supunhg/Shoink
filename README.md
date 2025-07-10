# 🚀 Shoink - **_The_** URL Shortener

Shoink is a sleek, terminal-based URL shortener built in pure Bash. It provides a menu-driven interface to interact with popular URL shortening services like **TinyURL**, with plans to support **Tiny.cc**, **ulvis.net**, and more. This tool is ideal for developers, terminal lovers, and automation workflows.

> 💡 Version: `v1.2`  
> 📦 Status: Actively maintained  

---

## 🎯 Features

- ✅ Shorten long URLs using [TinyURL](https://tinyurl.com/)
- ✅ Optional custom aliases
- ✅ Interactive menu system
- ✅ Color-coded terminal UI
- 🔒 Environment-based API key management
- 🔜 Planned support for Tiny.cc, ulvis.net and more...
- 🧩 Modular design for future integrations

---

## 🛠️ Setup

### 1. Clone the Repository

```bash
git clone https://github.com/supunhg/Shoink
cd shoink
````

### 2. Create a `.env` File

Create a `.env` file in the root directory with your API keys:

```env
TINYURL_API_KEY=your_tinyurl_api_key_here
# Future:
# TINYCC_API_KEY=...
# ULVIS_API_KEY=...
```

> 🔐 Keep this file **private** and **excluded from version control** using `.gitignore`.

---

## 🚀 Usage

Make the script executable:

```bash
chmod +x shoink.sh
```

Run it:

```bash
./shoink.sh
```

Follow the interactive prompts:

```bash
(=) Choose a service:

1. TinyURL
2. Tinycc
3. ulvis.net
4. Exit
```

You’ll be able to:

* Enter a URL to shorten
* Optionally choose a custom alias
* Get a shortened URL with minimal fuss

---

## 🖼️ Sample Output

```text
(*) TinyURL Selected

(->) Enter the URL to shorten: https://github.com/supunhg
(->) Custom alias (press enter to skip): 
(=) Shortening URL: https://github.com/supunhg

(*) Shortened URL: https://tinyurl.com/jkdkjptb
```

![image](https://github.com/user-attachments/assets/7ccbb990-54d8-4c55-857b-9377ca8673ea)

---

## 🧩 Roadmap

| Feature               | Status        |
| --------------------- | ------------- |
| TinyURL Support       | ✅ Complete    |
| Tiny.cc Integration   | ⏳ Coming soon |
| ulvis.net Support     | ⏳ Coming soon |
| More services...      | ⏳ Coming soon |
| CLI arguments support | 🔜 Planned    |
| History & logging     | 🔜 Planned    |

---

## 🤖 Dependencies

* [`curl`](https://curl.se/) - for HTTP requests
* [`jq`](https://stedolan.github.io/jq/) - for JSON parsing
* Bash

Install missing tools on Debian/Ubuntu:

```bash
sudo apt install curl jq
```

---

## 📂 Project Structure

```
shoink/
├── shoink.sh       # Main executable script
├── .env            # API keys (not committed)
└── README.md       # This file
```

---

## ⚠️ Disclaimer

* This is a developer-focused tool.
* API usage is bound by the terms of respective services.
* Use responsibly and avoid abuse.

---

## 👨‍💻 Author

Crafted with minimalism and functionality in mind by Supun Hewagamage
🔗 [LinkedIn](#) • [GitHub](#) • [Portfolio](#)

---
