# API Key Configuration Guide

FlowRead uses the Groq Text-to-Speech API to convert PDF text into natural-sounding audio. This guide explains how to obtain and configure your API keys.

## Obtaining a Groq API Key

1. Visit [Groq Console](https://console.groq.com)
2. Sign up or log in to your account
3. Navigate to **API Keys** in the dashboard
4. Click **Create API Key**
5. Copy the key (starts with `gsk_`)

> ⚠️ **Important**: Keep your API keys secure. Never share them publicly or commit them to version control.

## Configuration Methods

FlowRead supports three methods for configuring API keys, listed in order of priority:

### Method 1: Environment Variables (Recommended for Development)

Set environment variables before launching the app:

```bash
# Single key
export GROQ_API_KEY="gsk_your_key_here"

# Multiple keys for round-robin (up to 5)
export GROQ_API_KEY_1="gsk_key_1"
export GROQ_API_KEY_2="gsk_key_2"
export GROQ_API_KEY_3="gsk_key_3"
export GROQ_API_KEY_4="gsk_key_4"
export GROQ_API_KEY_5="gsk_key_5"
```

To make these persistent, add them to your shell profile:

```bash
# For zsh (default on modern macOS)
echo 'export GROQ_API_KEY="gsk_your_key"' >> ~/.zshrc

# For bash
echo 'export GROQ_API_KEY="gsk_your_key"' >> ~/.bashrc
```

### Method 2: Configuration File

Create a JSON configuration file at one of these locations:
- `~/.flowread/api_keys.json` (preferred)
- `~/.config/flowread/api_keys.json`

```json
{
  "groq_api_keys": [
    "gsk_your_first_key_here",
    "gsk_your_second_key_here",
    "gsk_your_third_key_here"
  ]
}
```

Create the directory and file:

```bash
mkdir -p ~/.flowread
cat > ~/.flowread/api_keys.json << 'EOF'
{
  "groq_api_keys": [
    "gsk_YOUR_KEY_HERE"
  ]
}
EOF
chmod 600 ~/.flowread/api_keys.json
```

### Method 3: In-App Preferences

1. Open FlowRead
2. Press `⌘,` to open Preferences
3. Go to the **API Keys** tab
4. Enter your keys in the fields provided
5. Click **Save Keys**

Keys entered this way are stored in `~/.flowread/api_keys.json`.

## Multiple Keys & Round-Robin

FlowRead supports up to 5 API keys for:

- **Load Balancing**: Distributes requests across keys
- **Rate Limit Handling**: Automatically switches to another key if one hits rate limits
- **Failover**: Continues working even if one key becomes invalid

### How It Works

1. Keys are used in round-robin order
2. If a key fails (rate limit, invalid, etc.), it's marked as failed
3. The next available key is used
4. If all keys fail, you'll see a warning message
5. Failed keys are retried after all keys have been attempted

## Troubleshooting

### "No API keys configured"

- Check that your key is properly set via one of the methods above
- Restart FlowRead after setting environment variables
- Verify the config file syntax is valid JSON

### "All API keys exhausted"

All configured keys have hit rate limits. Wait a few minutes and try again, or add more keys.

### "Invalid or expired API key"

- Verify the key in your Groq Console
- Check for typos (keys start with `gsk_`)
- Generate a new key if needed

### "Network error"

- Check your internet connection
- Verify that `api.groq.com` is accessible
- Check for firewall or proxy issues

## Security Best Practices

1. **Never hardcode keys** in source code
2. **Use environment variables** for development
3. **Protect your config file** with appropriate permissions (`chmod 600`)
4. **Rotate keys regularly** through the Groq Console
5. **Monitor usage** in the Groq Console for unexpected activity

## Rate Limits

Groq API has rate limits based on your plan:
- Free tier: Limited requests per minute
- Paid plans: Higher limits available

Using multiple keys helps distribute load and avoid hitting limits.

---

For more information, visit:
- [Groq Documentation](https://console.groq.com/docs)
- [Groq API Reference](https://console.groq.com/docs/api-reference)
