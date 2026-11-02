#!/usr/bin/env python3
"""
Benchmark script for measuring TTFT (Time-to-First-Token), overall request latency,
prefill speed, and generation tokens/sec across varying prompt lengths.
Target: vLLM Gemma 26B on AMD Strix Halo APU via LiteLLM router.
"""
import time
import json
import urllib.request
import sys

URL = "http://192.168.2.7/v1/chat/completions"
HOST = "llm.ddellspe.dev"
MODEL = "google/gemma-4-26B-A4B-it"

BASE_TEXT = (
    "The AMD Strix Halo architecture introduces a unified memory model where both the CPU "
    "and the integrated RDNA 3.5 GPU share up to 128 GB of LPDDR5X memory. This enables "
    "large language models such as Gemma 26B to run entirely in unified memory without "
    "requiring discrete high-cost data-center GPUs. Large context processing requires "
    "efficient attention mechanisms and optimized ROCm kernels. "
)

def generate_prompt(target_words):
    words = []
    base_words = BASE_TEXT.split()
    while len(words) < target_words:
        words.extend(base_words)
    return " ".join(words[:target_words]) + "\n\nSummarize the key architectural benefits described above in three bullet points."

def run_single_request(prompt, max_tokens=64):
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "max_tokens": max_tokens,
        "temperature": 0.0,
        "stream": True,
        "stream_options": {"include_usage": True}
    }
    
    headers = {
        "Host": HOST,
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(URL, data=json.dumps(payload).encode("utf-8"), headers=headers)
    
    t_start = time.perf_counter()
    t_first_token = None
    token_count = 0
    prompt_tokens = 0
    completion_tokens = 0
    
    with urllib.request.urlopen(req, timeout=180) as resp:
        for raw_line in resp:
            line = raw_line.decode("utf-8").strip()
            if not line or not line.startswith("data: "):
                continue
            data_str = line[6:].strip()
            if data_str == "[DONE]":
                break
            try:
                data = json.loads(data_str)
                if "usage" in data and data["usage"]:
                    prompt_tokens = data["usage"].get("prompt_tokens", prompt_tokens)
                    completion_tokens = data["usage"].get("completion_tokens", completion_tokens)
                choices = data.get("choices", [])
                if choices:
                    delta = choices[0].get("delta", {})
                    content = delta.get("content", "")
                    if content:
                        if t_first_token is None:
                            t_first_token = time.perf_counter()
                        token_count += 1
            except Exception:
                pass

    t_end = time.perf_counter()
    total_time = t_end - t_start
    ttft = (t_first_token - t_start) if t_first_token else total_time
    gen_time = (t_end - t_first_token) if t_first_token else 0
    actual_out = completion_tokens if completion_tokens > 0 else token_count
    gen_tps = (actual_out / gen_time) if gen_time > 0 else 0
    prefill_tps = (prompt_tokens / ttft) if (ttft > 0 and prompt_tokens > 0) else 0

    return {
        "prompt_tokens": prompt_tokens,
        "output_tokens": actual_out,
        "ttft_s": ttft,
        "total_time_s": total_time,
        "gen_time_s": gen_time,
        "gen_tps": gen_tps,
        "prefill_tps": prefill_tps
    }

def main():
    print("=" * 80)
    print(f"Benchmarking vLLM Gemma 26B ({MODEL}) on AMD Strix Halo")
    print(f"Target URL: {URL} (Host: {HOST})")
    print("=" * 80 + "\n")

    print("Running initial warm-up request...")
    warmup_res = run_single_request("Hello, world!", max_tokens=10)
    print(f"Warm-up complete: prompt={warmup_res['prompt_tokens']} tokens, TTFT={warmup_res['ttft_s']*1000:.1f}ms, Total={warmup_res['total_time_s']*1000:.1f}ms\n")

    test_sizes = [
        ("Short (~128 tok)", 75),
        ("Medium (~512 tok)", 350),
        ("Long (~1,024 tok)", 750),
        ("Very Long (~2,048 tok)", 1500),
        ("Ext Long (~4,096 tok)", 3100),
        ("Max Context (~8,192 tok)", 6200),
    ]

    print("| Target Size             | Prompt Tokens | Output Tokens | TTFT (s)  | Total Time (s) | Gen Speed (tok/s) | Prefill (tok/s) |")
    print("|-------------------------|---------------|---------------|-----------|----------------|-------------------|-----------------|")

    for label, target_words in test_sizes:
        prompt = generate_prompt(target_words)
        pass1 = run_single_request(prompt, max_tokens=64)
        time.sleep(1)
        pass2 = run_single_request(prompt, max_tokens=64)
        time.sleep(1)

        avg_prompt_tokens = pass2["prompt_tokens"]
        avg_output_tokens = (pass1["output_tokens"] + pass2["output_tokens"]) / 2
        avg_ttft = (pass1["ttft_s"] + pass2["ttft_s"]) / 2
        avg_total = (pass1["total_time_s"] + pass2["total_time_s"]) / 2
        avg_gen_tps = (pass1["gen_tps"] + pass2["gen_tps"]) / 2
        avg_prefill_tps = (pass1["prefill_tps"] + pass2["prefill_tps"]) / 2

        print(f"| {label:<23} | {avg_prompt_tokens:<13} | {avg_output_tokens:<13.0f} | {avg_ttft:<9.3f} | {avg_total:<14.3f} | {avg_gen_tps:<17.2f} | {avg_prefill_tps:<15.1f} |")
        sys.stdout.flush()

    print("\nBenchmark completed successfully.")

if __name__ == "__main__":
    main()
