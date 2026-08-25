#!/usr/bin/env python3

# Manual test script
# Needs:
# apt install python3-pip
# pip install openai

from openai import OpenAI
import sys

MODEL = "Qwen/Qwen3.8-27B"

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"
)

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

    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            stream=True,
            temperature=0.7
        )

        print("\033[92mAI:\033[0m ", end="", flush=True) # Green

        full_reply = ""
        for chunk in response:
            delta = chunk.choices[0].delta.content
            if delta:
                print(delta, end="", flush=True)
                full_reply += delta

        print("\n")

        messages.append({"role": "assistant", "content": full_reply})

    except Exception as e:
        print(f"\nError communicating with server: {e}")
        messages.pop()