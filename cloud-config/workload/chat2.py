#!/usr/bin/env python3

# Manual test script 
# (No pip dependencies)

import urllib.request
import urllib.error
import json
import sys

MODEL = "Qwen/Qwen3.8-27B"
URL = "http://localhost:8000/v1/chat/completions"
API_KEY = "not-needed"

messages = [
    {"role": "system", "content": "You are a helpful, concise AI assistant."}
]

print(f"Connected to local model: {MODEL}")
print("Type 'quit' or 'exit' to end the chat.\n")

while True:
    user_input = input("\033[94mYou:\033[0m ") # Blue
    if user_input.lower() in ['quit', 'exit']:
        print("Goodbye!")
        break
    if not user_input.strip():
        continue

    messages.append({"role": "user", "content": user_input})

    # Build the request payload
    payload = {
        "model": MODEL,
        "messages": messages,
        "stream": True,
        "temperature": 0.7
    }
    data = json.dumps(payload).encode('utf-8')
    
    req = urllib.request.Request(
        URL, 
        data=data, 
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}"
        },
        method="POST"
    )

    try:
        # Open the connection and read the stream
        with urllib.request.urlopen(req) as response:
            print("\033[92mAI:\033[0m ", end="", flush=True) # Green
            
            full_reply = ""
            for line in response:
                decoded_line = line.decode('utf-8').strip()
                
                # The OpenAI streaming format uses Server-Sent Events starting with "data: "
                if decoded_line.startswith("data: "):
                    json_str = decoded_line[6:] # Strip "data: " prefix
                    
                    if json_str == "[DONE]":
                        break
                        
                    try:
                        chunk = json.loads(json_str)
                        # Extract the content delta just like chunk.choices[0].delta.content
                        delta = chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
                        if delta:
                            print(delta, end="", flush=True)
                            full_reply += delta
                    except json.JSONDecodeError:
                        continue
                        
            print("\n")
            messages.append({"role": "assistant", "content": full_reply})

    except urllib.error.URLError as e:
        print(f"\nError communicating with server: {e}")
        messages.pop() # Remove the user message since it failed